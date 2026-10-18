#!/bin/sh
#
# Build every package of this feed without the OpenWrt SDK.
#
#   ./build-ipk.sh
#
# Packages are described at the bottom of this file. The result is written to
# dist/ together with the opkg indexes (see build-index.py in CI).
#
set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
OUT=$HERE/dist

rm -rf "$OUT"
mkdir -p "$OUT"

pack() {
	dir=$1
	pkg=$2
	ver=$3
	depends=$4
	desc1=$5
	desc2=$6
	conffiles=$7

	stage=$OUT/.build-$pkg
	rm -rf "$stage"
	mkdir -p "$stage/data/www" "$stage/control"

	[ -d "$dir/htdocs" ] && cp -R "$dir/htdocs/." "$stage/data/www/"
	[ -d "$dir/root" ] && cp -R "$dir/root/." "$stage/data/"

	find "$stage/data" -type f \( -name '*.uc' -o -name '*.sh' \
		-o -path '*/init.d/*' -o -path '*/rpcd/ucode/*' \) \
		-exec chmod 755 {} + 2>/dev/null || true

	{
		echo "Package: $pkg"
		echo "Version: $ver"
		echo "Depends: $depends"
		echo "Architecture: all"
		echo "Section: luci"
		echo "Priority: optional"
		echo "Maintainer: yuzl1"
		echo "Description: $desc1"
		echo " $desc2"
		if [ -n "$conffiles" ]; then
			echo "Conffiles:"
			for f in $conffiles; do
				if command -v md5 >/dev/null 2>&1; then
					sum=$(md5 -q "$stage/data$f")
				else
					sum=$(md5sum "$stage/data$f" | cut -d' ' -f1)
				fi
				echo " $f $sum"
			done
		fi
	} > "$stage/control/control"

	cat > "$stage/control/postinst" <<'EOF'
#!/bin/sh
[ -n "$IPKG_INSTROOT" ] && exit 0
if [ -x /etc/init.d/tailscale-settings ]; then
	/etc/init.d/tailscale-settings enable 2>/dev/null
	/etc/init.d/tailscale-settings restart 2>/dev/null || /etc/init.d/tailscale-settings start 2>/dev/null
fi

# rpcd loads ucode plugins at startup, so it only needs a restart when one of
# them actually changed. Restarting it drops every LuCI login session, so a
# checksum is kept and the restart is skipped otherwise.
changed=0
for f in /usr/share/rpcd/ucode/*; do
	[ -f "$f" ] || continue
	sum=$(md5sum "$f" 2>/dev/null | cut -d' ' -f1)
	marker="/usr/share/luci/.rpcd-$(basename "$f").md5"
	[ "$sum" = "$(cat "$marker" 2>/dev/null)" ] || { echo "$sum" > "$marker"; changed=1; }
done
[ "$changed" = "1" ] && /etc/init.d/rpcd restart 2>/dev/null

rm -f /tmp/luci-indexcache*
exit 0
EOF

	cat > "$stage/control/prerm" <<'EOF'
#!/bin/sh
[ -n "$IPKG_INSTROOT" ] && exit 0
if [ -x /etc/init.d/tailscale-settings ]; then
	/etc/init.d/tailscale-settings stop 2>/dev/null || true
	/etc/init.d/tailscale-settings disable 2>/dev/null || true
fi
exit 0
EOF

	chmod 755 "$stage/control/postinst" "$stage/control/prerm"

	python3 - "$stage" "$OUT/${pkg}_${ver}_all.ipk" <<'PYEOF'
import io, os, sys, tarfile

stage, ipk = sys.argv[1], sys.argv[2]
exec_bits = {"postinst", "prerm"}

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
                executable = (name in exec_bits) or ti.mode & 0o111
                ti.mode = 0o755 if executable else 0o644
                with open(p, "rb") as fh:
                    tf.addfile(ti, fh)

mktar(os.path.join(stage, "control"), os.path.join(stage, "control.tar.gz"))
mktar(os.path.join(stage, "data"), os.path.join(stage, "data.tar.gz"))

with tarfile.open(ipk, "w:gz", format=tarfile.GNU_FORMAT) as tf:
    for name, payload in (
        ("debian-binary", b"2.0\n"),
        ("data.tar.gz", open(os.path.join(stage, "data.tar.gz"), "rb").read()),
        ("control.tar.gz", open(os.path.join(stage, "control.tar.gz"), "rb").read()),
    ):
        ti = tarfile.TarInfo("./" + name)
        ti.size = len(payload)
        ti.mode = 0o644
        ti.uid = ti.gid = 0
        ti.uname = ti.gname = "root"
        tf.addfile(ti, io.BytesIO(payload))
PYEOF

	rm -rf "$stage"
	echo "built: $OUT/${pkg}_${ver}_all.ipk"
}

#
# Package list
#

pack "$HERE" \
	luci-app-tailscale-community 1.0.2-1 \
	"tailscale, ip-full, luci-base, rpcd-mod-ucode, ucode, ucode-mod-fs, ucode-mod-uci, ucode-mod-ubus" \
	"LuCI support for Tailscale" \
	"Web management interface for Tailscale: status, login/logout, settings and subnet routes." \
	""

pack "$HERE/luci-app-ddns-lite" \
	luci-app-ddns-lite 1.4.0-1 \
	"ddns-scripts, ddns-scripts-services, curl, luci-base, rpcd-mod-ucode, ucode, ucode-mod-fs, ucode-mod-uci, ucode-mod-ubus" \
	"LuCI DDNS Lite" \
	"Simple ddns-go style UI that generates ddns-scripts entries." \
	"/etc/config/ddns-lite"

ls -l "$OUT"/*.ipk
