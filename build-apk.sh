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
cp -R "$HERE/fork/luci-app-tailscale-community/htdocs/." "$stage/rootfs/www/"
cp -R "$HERE/fork/luci-app-tailscale-community/root/." "$stage/rootfs/"
find "$stage/rootfs" -type f \( -path '*/init.d/*' -o -path '*/usr/bin/*' \
	-o -path '*/rpcd/ucode/*' \) -exec chmod 755 {} + 2>/dev/null || true

cat > "$stage/scripts/post-install" <<'EOF'
#!/bin/sh
[ -n "$IPKG_INSTROOT" ] && exit 0
rm -f /tmp/luci-indexcache*
exit 0
EOF
chmod 755 "$stage/scripts/"*

prepare_meta "$stage/rootfs" luci-app-tailscale-community
mkpkg luci-app-tailscale-community 26.236.50544~cb5d434-r2 noarch \
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

rm -rf "$OUT"/.build-*

[ -f "$HERE/keys/yuzl1-apk-25.12.pem" ] && cp "$HERE/keys/yuzl1-apk-25.12.pem" "$OUT/"

ls -l "$OUT"/*.apk
