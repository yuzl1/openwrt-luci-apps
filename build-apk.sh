#!/bin/sh
#
# Build this feed as apk packages for OpenWrt / ImmortalWrt 25.12 (apk-tools 3).
#
# Requires the apk host tool from apk-tools 3.x:
#   APK_BIN=/path/to/apk ./build-apk.sh
#
# Result: dist-apk/*.apk
#
set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
OUT=$HERE/dist-apk
APK_BIN=${APK_BIN:-apk}
SIGN_KEY=${APK_SIGN_KEY_FILE:-}

command -v "$APK_BIN" >/dev/null 2>&1 || {
	echo "apk host tool not found; set APK_BIN=/path/to/apk" >&2
	exit 1
}

rm -rf "$OUT"
mkdir -p "$OUT"

sha256_file() {
	if command -v sha256sum >/dev/null 2>&1; then
		sha256sum "$1" | cut -d' ' -f1
	else
		shasum -a 256 "$1" | cut -d' ' -f1
	fi
}

prepare_meta() {
	rootfs=$1
	pkg=$2
	shift 2

	mkdir -p "$rootfs/lib/apk/packages"

	if [ "$#" -gt 0 ]; then
		: > "$rootfs/lib/apk/packages/$pkg.conffiles"
		: > "$rootfs/lib/apk/packages/$pkg.conffiles_static"
		for f in "$@"; do
			echo "$f" >> "$rootfs/lib/apk/packages/$pkg.conffiles"
			echo "$f $(sha256_file "$rootfs$f")" \
				>> "$rootfs/lib/apk/packages/$pkg.conffiles_static"
		done
	fi

	list=$(mktemp)
	(cd "$rootfs" && find . \( -type f -o -type l \) | sed 's|^\./|/|' | sort) > "$list"
	mv "$list" "$rootfs/lib/apk/packages/$pkg.list"
}

mkpkg() {
	pkg=$1
	ver=$2
	arch=$3
	desc=$4
	deps=$5
	rootfs=$6
	scripts=$7

	set -- "$APK_BIN" mkpkg \
		--info "name:$pkg" \
		--info "version:$ver" \
		--info "description:$desc" \
		--info "arch:$arch" \
		--info "license:MIT" \
		--info "origin:$pkg" \
		--info "url:https://github.com/yuzl1/openwrt-luci-apps" \
		--info "maintainer:yuzl1" \
		--info "depends:$deps" \
		--files "$rootfs" \
		--output "$OUT/${pkg}-${ver}.apk"

	if [ -n "$SIGN_KEY" ] && [ -f "$SIGN_KEY" ]; then
		set -- "$@" --sign-key "$SIGN_KEY"
	fi

	[ -f "$scripts/post-install" ] \
		&& set -- "$@" --script "post-install:$scripts/post-install"
	[ -f "$scripts/pre-deinstall" ] \
		&& set -- "$@" --script "pre-deinstall:$scripts/pre-deinstall"

	"$@"
}

#
# luci-app-tailscale-community (noarch)
#
stage=$OUT/.build-luci-app-tailscale-community
rm -rf "$stage"
mkdir -p "$stage/rootfs/www" "$stage/scripts"
cp -R "$HERE/htdocs/." "$stage/rootfs/www/"
cp -R "$HERE/root/." "$stage/rootfs/"
find "$stage/rootfs" -type f \( -path '*/init.d/*' -o -path '*/usr/bin/*' \
	-o -path '*/rpcd/ucode/*' \) -exec chmod 755 {} + 2>/dev/null || true

cat > "$stage/scripts/post-install" <<'EOF'
#!/bin/sh
[ -n "$IPKG_INSTROOT" ] && exit 0
if [ -x /etc/init.d/tailscale-settings ]; then
	/etc/init.d/tailscale-settings enable 2>/dev/null
	/etc/init.d/tailscale-settings restart 2>/dev/null || /etc/init.d/tailscale-settings start 2>/dev/null
fi
rm -f /tmp/luci-indexcache*
exit 0
EOF

cat > "$stage/scripts/pre-deinstall" <<'EOF'
#!/bin/sh
[ -n "$IPKG_INSTROOT" ] && exit 0
if [ -x /etc/init.d/tailscale-settings ]; then
	/etc/init.d/tailscale-settings stop 2>/dev/null || true
	/etc/init.d/tailscale-settings disable 2>/dev/null || true
fi
exit 0
EOF
chmod 755 "$stage/scripts/"*

prepare_meta "$stage/rootfs" luci-app-tailscale-community
mkpkg luci-app-tailscale-community 1.0.2-r1 noarch \
	"LuCI support for Tailscale" \
	"tailscale ip-full luci-base rpcd-mod-ucode ucode ucode-mod-fs ucode-mod-uci ucode-mod-ubus" \
	"$stage/rootfs" "$stage/scripts"

#
# luci-app-ddns-lite (noarch)
#
stage=$OUT/.build-luci-app-ddns-lite
rm -rf "$stage"
mkdir -p "$stage/rootfs/www" "$stage/scripts"
cp -R "$HERE/luci-app-ddns-lite/htdocs/." "$stage/rootfs/www/"
cp -R "$HERE/luci-app-ddns-lite/root/." "$stage/rootfs/"
find "$stage/rootfs" -type f \( -path '*/init.d/*' -o -path '*/usr/bin/*' \
	-o -path '*/rpcd/ucode/*' \) -exec chmod 755 {} + 2>/dev/null || true

cat > "$stage/scripts/post-install" <<'EOF'
#!/bin/sh
[ -n "$IPKG_INSTROOT" ] && exit 0
if [ -x /etc/init.d/ddns-lite ]; then
	/etc/init.d/ddns-lite enable 2>/dev/null
	/etc/init.d/ddns-lite restart 2>/dev/null || /etc/init.d/ddns-lite start 2>/dev/null
fi
rm -f /tmp/luci-indexcache*
exit 0
EOF

cat > "$stage/scripts/pre-deinstall" <<'EOF'
#!/bin/sh
[ -n "$IPKG_INSTROOT" ] && exit 0
if [ -x /etc/init.d/ddns-lite ]; then
	/etc/init.d/ddns-lite stop 2>/dev/null || true
	/etc/init.d/ddns-lite disable 2>/dev/null || true
fi
exit 0
EOF
chmod 755 "$stage/scripts/"*

prepare_meta "$stage/rootfs" luci-app-ddns-lite /etc/config/ddns-lite
mkpkg luci-app-ddns-lite 1.0.3-r1 noarch \
	"LuCI DDNS Lite" \
	"curl jsonfilter luci-base rpcd-mod-ucode ucode ucode-mod-fs ucode-mod-uci ucode-mod-ubus" \
	"$stage/rootfs" "$stage/scripts"

#
# tailscale (arm_cortex-a7_neon-vfpv4)
#
VERSION=${TAILSCALE_VERSION:-1.104.1}
RELEASE=${TAILSCALE_RELEASE:-3}
SOURCE_SHA256=${TAILSCALE_SHA256:-bf868b2b1a46b9485d55bcda12c2d7573279ce4474bc6d607f42f1495db36ed8}
ARCH=arm_cortex-a7_neon-vfpv4

stage=$OUT/.build-tailscale
source_archive=$stage/tailscale-v$VERSION.tar.gz
source_dir=$stage/tailscale-v$VERSION
rm -rf "$stage"
mkdir -p "$source_dir" "$stage/rootfs/usr/sbin" "$stage/rootfs/etc/init.d" \
	"$stage/rootfs/etc/config" "$stage/scripts"

[ -f "$source_archive" ] || curl -fL --max-time 300 -o "$source_archive" \
	"https://codeload.github.com/tailscale/tailscale/tar.gz/refs/tags/v$VERSION"

[ "$(sha256_file "$source_archive")" = "$SOURCE_SHA256" ] || {
	echo "Tailscale source checksum mismatch" >&2
	exit 1
}

tar -xzf "$source_archive" -C "$source_dir" --strip-components=1

echo "Building Tailscale $VERSION for linux/arm (GOARM=7)"
(
	cd "$source_dir"
	CGO_ENABLED=0 GOOS=linux GOARCH=arm GOARM=7 GOTOOLCHAIN=auto \
		go build -trimpath -buildvcs=false \
		-tags=ts_include_cli,ts_omit_aws,ts_omit_bird,ts_omit_tap,ts_omit_kube,ts_omit_completion \
		-ldflags "-s -w -X 'tailscale.com/version.longStamp=${VERSION}-${RELEASE} (OpenWrt)' -X 'tailscale.com/version.shortStamp=${VERSION}'" \
		-o "$stage/rootfs/usr/sbin/tailscaled" ./cmd/tailscaled
)

ln -s tailscaled "$stage/rootfs/usr/sbin/tailscale"
install -m 755 "$HERE/tailscale/files/tailscale.init" "$stage/rootfs/etc/init.d/tailscale"
install -m 644 "$HERE/tailscale/files/tailscale.conf" "$stage/rootfs/etc/config/tailscale"

cat > "$stage/scripts/post-install" <<'EOF'
#!/bin/sh
[ -n "$IPKG_INSTROOT" ] && exit 0
mkdir -p /etc/tailscale
chmod 700 /etc/tailscale
/etc/init.d/tailscale enable
/etc/init.d/tailscale restart 2>/dev/null || /etc/init.d/tailscale start
exit 0
EOF

cat > "$stage/scripts/pre-deinstall" <<'EOF'
#!/bin/sh
[ -n "$IPKG_INSTROOT" ] && exit 0
/etc/init.d/tailscale stop 2>/dev/null || true
/etc/init.d/tailscale disable 2>/dev/null || true
exit 0
EOF
chmod 755 "$stage/scripts/"*

prepare_meta "$stage/rootfs" tailscale /etc/config/tailscale
mkpkg tailscale "${VERSION}-r${RELEASE}" "$ARCH" \
	"Tailscale static ARMv7 daemon" \
	"ca-bundle kmod-tun" \
	"$stage/rootfs" "$stage/scripts"

rm -rf "$OUT"/.build-*

[ -f "$HERE/keys/yuzl1-apk.pem" ] && cp "$HERE/keys/yuzl1-apk.pem" "$OUT/"

ls -l "$OUT"/*.apk
