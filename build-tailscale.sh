#!/bin/sh
#
# Cross-build the Tailscale daemon for the Redmi AX3000 ARMv7 router and wrap
# it as an OpenWrt-compatible ipk.
#
set -eu

VERSION=${TAILSCALE_VERSION:-1.104.1}
RELEASE=${TAILSCALE_RELEASE:-3}
SOURCE_SHA256=${TAILSCALE_SHA256:-bf868b2b1a46b9485d55bcda12c2d7573279ce4474bc6d607f42f1495db36ed8}
ARCH=arm_cortex-a7_neon-vfpv4

HERE=$(cd "$(dirname "$0")" && pwd)
OUT=$HERE/dist
BUILD=$OUT/.build-tailscale
SOURCE_ARCHIVE=$BUILD/tailscale-v$VERSION.tar.gz
SOURCE_DIR=$BUILD/tailscale-v$VERSION
STAGE=$BUILD/stage
IPK=$OUT/tailscale_${VERSION}-${RELEASE}_${ARCH}.ipk

sha256_file() {
	if command -v sha256sum >/dev/null 2>&1; then
		sha256sum "$1" | cut -d' ' -f1
	else
		shasum -a 256 "$1" | cut -d' ' -f1
	fi
}

md5_file() {
	if command -v md5sum >/dev/null 2>&1; then
		md5sum "$1" | cut -d' ' -f1
	else
		md5 -q "$1"
	fi
}

rm -rf "$BUILD"
mkdir -p "$BUILD" "$OUT" "$STAGE/data/usr/sbin" "$STAGE/control"

if [ ! -f "$SOURCE_ARCHIVE" ]; then
	curl -fL --max-time 300 \
		-o "$SOURCE_ARCHIVE" \
		"https://codeload.github.com/tailscale/tailscale/tar.gz/refs/tags/v$VERSION"
fi

actual=$(sha256_file "$SOURCE_ARCHIVE")
[ "$actual" = "$SOURCE_SHA256" ] || {
	echo "Tailscale source checksum mismatch" >&2
	exit 1
}

mkdir -p "$SOURCE_DIR"
tar -xzf "$SOURCE_ARCHIVE" -C "$SOURCE_DIR" --strip-components=1

echo "Building Tailscale $VERSION for linux/arm (GOARM=7)"
(
	cd "$SOURCE_DIR"
	CGO_ENABLED=0 GOOS=linux GOARCH=arm GOARM=7 GOTOOLCHAIN=auto \
		go build -trimpath -buildvcs=false \
		-tags=ts_include_cli,ts_omit_aws,ts_omit_bird,ts_omit_tap,ts_omit_kube,ts_omit_completion \
		-ldflags "-s -w -X 'tailscale.com/version.longStamp=${VERSION}-${RELEASE} (OpenWrt)' -X 'tailscale.com/version.shortStamp=${VERSION}'" \
		-o "$STAGE/data/usr/sbin/tailscaled" ./cmd/tailscaled
)

ln -s tailscaled "$STAGE/data/usr/sbin/tailscale"
install -d "$STAGE/data/etc/init.d" "$STAGE/data/etc/config"
install -m 755 "$HERE/tailscale/files/tailscale.init" "$STAGE/data/etc/init.d/tailscale"
install -m 644 "$HERE/tailscale/files/tailscale.conf" "$STAGE/data/etc/config/tailscale"

config_sum=$(md5_file "$STAGE/data/etc/config/tailscale")
size_kb=$(( ($(wc -c < "$STAGE/data/usr/sbin/tailscaled") + 1023) / 1024 ))

cat > "$STAGE/control/control" <<EOF
Package: tailscale
Version: ${VERSION}-${RELEASE}
Depends: ca-bundle, iptables-nft, ip6tables-nft, iptables-mod-conntrack-extra, kmod-ipt-conntrack, kmod-ipt-conntrack-extra, kmod-ipt-nat, kmod-ipt-nat6, kmod-tun
Provides: tailscaled
Architecture: ${ARCH}
Installed-Size: ${size_kb}
Section: net
Priority: optional
Maintainer: yuzl1
License: BSD-3-Clause
Description: Tailscale static ARMv7 daemon
 Tailscale daemon built from upstream ${VERSION} with OpenWrt-safe build tags.
Conffiles:
 /etc/config/tailscale ${config_sum}
EOF

cat > "$STAGE/control/postinst" <<'EOF'
#!/bin/sh
[ -n "$IPKG_INSTROOT" ] && exit 0
mkdir -p /etc/tailscale
chmod 700 /etc/tailscale
/etc/init.d/tailscale enable
/etc/init.d/tailscale restart 2>/dev/null || /etc/init.d/tailscale start
exit 0
EOF

cat > "$STAGE/control/prerm" <<'EOF'
#!/bin/sh
[ -n "$IPKG_INSTROOT" ] && exit 0
/etc/init.d/tailscale stop 2>/dev/null || true
exit 0
EOF

chmod 755 "$STAGE/control/postinst" "$STAGE/control/prerm"

python3 - "$STAGE" "$IPK" <<'PYEOF'
import io
import os
import sys
import tarfile

stage, ipk = sys.argv[1], sys.argv[2]


def mktar(src, dest):
    with tarfile.open(dest, "w:gz", format=tarfile.GNU_FORMAT) as tf:
        for root, dirs, files in os.walk(src):
            dirs.sort()
            for name in dirs:
                path = os.path.join(root, name)
                info = tf.gettarinfo(path, arcname="./" + os.path.relpath(path, src))
                info.uid = info.gid = 0
                info.uname = info.gname = "root"
                info.mode = 0o755
                tf.addfile(info)
            for name in sorted(files):
                path = os.path.join(root, name)
                info = tf.gettarinfo(path, arcname="./" + os.path.relpath(path, src))
                info.uid = info.gid = 0
                info.uname = info.gname = "root"
                if info.issym():
                    tf.addfile(info)
                    continue
                if info.mode & 0o111:
                    info.mode = 0o755
                else:
                    info.mode = 0o644
                with open(path, "rb") as fh:
                    tf.addfile(info, fh)


def add_symlink(tf, path, target):
    info = tarfile.TarInfo(path)
    info.type = tarfile.SYMTYPE
    info.linkname = target
    info.mode = 0o777
    info.uid = info.gid = 0
    info.uname = info.gname = "root"
    tf.addfile(info)


mktar(os.path.join(stage, "control"), os.path.join(stage, "control.tar.gz"))
mktar(os.path.join(stage, "data"), os.path.join(stage, "data.tar.gz"))

with tarfile.open(ipk, "w:gz", format=tarfile.GNU_FORMAT) as tf:
    for name, filename in (
        ("debian-binary", None),
        ("data.tar.gz", os.path.join(stage, "data.tar.gz")),
        ("control.tar.gz", os.path.join(stage, "control.tar.gz")),
    ):
        payload = b"2.0\n" if filename is None else open(filename, "rb").read()
        info = tarfile.TarInfo("./" + name)
        info.size = len(payload)
        info.mode = 0o644
        info.uid = info.gid = 0
        info.uname = info.gname = "root"
        tf.addfile(info, io.BytesIO(payload))
PYEOF

rm -rf "$STAGE" "$SOURCE_DIR" "$SOURCE_ARCHIVE"
echo "built: $IPK"
