#!/bin/sh
#
# Build the architecture independent .ipk without the OpenWrt SDK.
#
#   ./build-ipk.sh
#
# Produces dist/luci-app-tailscale-community_<version>_all.ipk
#
set -eu

PKG=luci-app-tailscale-community
VER=1.0.1-1
HERE=$(cd "$(dirname "$0")" && pwd)
OUT=$HERE/dist

rm -rf "$OUT"
mkdir -p "$OUT/data" "$OUT/control"

# htdocs/* is installed into /www, root/* into /
mkdir -p "$OUT/data/www"
cp -R "$HERE/htdocs/." "$OUT/data/www/"
cp -R "$HERE/root/." "$OUT/data/"

chmod 755 "$OUT/data/etc/init.d/tailscale-settings"
chmod 755 "$OUT/data/usr/share/rpcd/ucode/tailscale.uc"

cat > "$OUT/control/control" <<EOF
Package: $PKG
Version: $VER
Depends: tailscale, ip-full, luci-base, rpcd-mod-ucode, ucode, ucode-mod-fs, ucode-mod-uci, ucode-mod-ubus
Architecture: all
Section: luci
Priority: optional
Maintainer: yuzl1
Description: LuCI support for Tailscale
 Web management interface for Tailscale: status, login/logout,
 settings and subnet routes.
EOF

cat > "$OUT/control/postinst" <<'EOF'
#!/bin/sh
[ -n "$IPKG_INSTROOT" ] && exit 0
chown -R root:root /www/luci-static/resources/view/tailscale.js \
	/etc/init.d/tailscale-settings \
	/usr/share/luci/menu.d/luci-app-tailscale-community.json \
	/usr/share/rpcd/acl.d/luci-app-tailscale-community.json \
	/usr/share/rpcd/ucode/tailscale.uc 2>/dev/null
/etc/init.d/tailscale-settings enable
/etc/init.d/tailscale-settings restart 2>/dev/null || /etc/init.d/tailscale-settings start
/etc/init.d/rpcd restart
rm -f /tmp/luci-indexcache*
exit 0
EOF

cat > "$OUT/control/prerm" <<'EOF'
#!/bin/sh
[ -n "$IPKG_INSTROOT" ] && exit 0
/etc/init.d/tailscale-settings stop 2>/dev/null || true
/etc/init.d/tailscale-settings disable 2>/dev/null || true
exit 0
EOF

chmod 755 "$OUT/control/postinst" "$OUT/control/prerm"

# Pack with python so the archive is byte-for-byte the format opkg expects
# (ustar members owned by root, no macOS xattrs, standard ar container).
python3 - "$OUT" "${PKG}_${VER}_all.ipk" <<'PYEOF'
import os, sys, tarfile

out, ipkname = sys.argv[1], sys.argv[2]
exec_bits = {"postinst", "prerm", "tailscale-settings", "tailscale.uc"}

def mktar(src, dest):
    with tarfile.open(dest, "w:gz", format=tarfile.GNU_FORMAT) as tf:
        for root, dirs, files in os.walk(src):
            dirs.sort()
            for name in dirs:
                p = os.path.join(root, name)
                ti = tf.gettarinfo(p, arcname="./" + os.path.relpath(p, src))
                ti.uid = ti.gid = 0
                ti.uname = ti.gname = "root"
                ti.mode = 0o755
                tf.addfile(ti)
            for name in sorted(files):
                p = os.path.join(root, name)
                ti = tf.gettarinfo(p, arcname="./" + os.path.relpath(p, src))
                ti.uid = ti.gid = 0
                ti.uname = ti.gname = "root"
                ti.mode = 0o755 if name in exec_bits else 0o644
                with open(p, "rb") as fh:
                    tf.addfile(ti, fh)

mktar(os.path.join(out, "control"), os.path.join(out, "control.tar.gz"))
mktar(os.path.join(out, "data"), os.path.join(out, "data.tar.gz"))

# OpenWrt 23.05 opkg expects the ipk to be a gzipped tar holding
# debian-binary, data.tar.gz and control.tar.gz (not an ar archive).
with tarfile.open(os.path.join(out, ipkname), "w:gz", format=tarfile.GNU_FORMAT) as tf:
    for name, data in (
        ("debian-binary", b"2.0\n"),
        ("data.tar.gz", open(os.path.join(out, "data.tar.gz"), "rb").read()),
        ("control.tar.gz", open(os.path.join(out, "control.tar.gz"), "rb").read()),
    ):
        ti = tarfile.TarInfo("./" + name)
        ti.size = len(data)
        ti.mode = 0o644
        ti.uid = ti.gid = 0
        ti.uname = ti.gname = "root"
        import io
        tf.addfile(ti, io.BytesIO(data))
PYEOF

rm -f "$OUT/control.tar.gz" "$OUT/data.tar.gz"
echo "built: $OUT/${PKG}_${VER}_all.ipk"
ls -l "$OUT/${PKG}_${VER}_all.ipk"
