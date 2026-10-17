# luci-app-tailscale-community for OpenWrt / ImmortalWrt 23.05

Backport of the OpenWrt `luci-app-tailscale-community` LuCI application so it
can be installed from opkg on 23.05 based firmware, including arm 32-bit
targets such as the Redmi AX3000 (RA81).

The application is pure LuCI JavaScript plus a ucode rpcd plugin, so it does
not depend on the kernel or CPU architecture.

## What it provides

* `LuCI -> VPN -> Tailscale` page: status, login/logout, settings, subnet
  routes
* ubus object `tailscale`
  (`get_status`, `get_settings`, `get_subroutes`, `do_login`, `do_logout`,
  `setup_firewall`)
* uci configuration in `/etc/config/tailscale`

## Requirements

* OpenWrt / ImmortalWrt 23.05
* `tailscale` (official package), `ip-full`, `luci-base`
* `rpcd-mod-ucode` plus `ucode`, `ucode-mod-fs`, `ucode-mod-uci`,
  `ucode-mod-ubus` (present in the default 23.05 feeds)

## Install

Either add this repository as a feed and build it with the SDK, or use the
prebuilt architecture independent package:

```sh
opkg install tailscale ip-full
opkg install luci-app-tailscale-community_1.0.0-1_all.ipk
```

Then open `http://<router>/cgi-bin/luci/admin/services/tailscale`.

### Install straight from the opkg feed

Every build publishes `Packages.gz` and the ipk to the `gh-pages` branch, so
the repository can be used as a normal package feed. See
[docs/opkg-feed.md](docs/opkg-feed.md) for the step by step instructions
(the whole setup can be done from the LuCI web interface).

Short version:

```sh
echo 'src/gz tailscale23 https://yuzl1.github.io/luci-app-tailscale-23.05' \
	>> /etc/opkg/customfeeds.conf
sed -i 's/^option check_signature/# option check_signature/' /etc/opkg.conf
opkg update
opkg install luci-app-tailscale-community
```

The package depends on `tailscale`, `ip-full`, `luci-base`, `rpcd-mod-ucode`
and the ucode modules, so opkg pulls those in automatically. Afterwards the
app shows up in *LuCI -> Services -> Tailscale*.

## Feed signing - install the public key

The `Packages` index is signed with usign, so the default OpenWrt behaviour
(`option check_signature` enabled) can stay on. The public key is **not**
secret and is shipped in this repository:
[`keys/776cc6b50a033ebf.pub`](keys/776cc6b50a033ebf.pub).

The key id is `776cc6b50a033ebf`, which is also the file name it must use
inside `/etc/opkg/keys/`.

### From your computer

```sh
scp -O keys/776cc6b50a033ebf.pub \
	root@192.168.1.1:/etc/opkg/keys/776cc6b50a033ebf
```

### Directly on the router

```sh
mkdir -p /etc/opkg/keys
cat > /etc/opkg/keys/776cc6b50a033ebf <<'EOF'
untrusted comment: yuzl1 luci-app-tailscale-23.05 feed
RWR3bMa1CgM+v2US9cs2lxNpCg9n+FDyBwZvTU/cm+CvZ3mfutaY9Rt+
EOF
```

### Verify

```sh
usign -F -p /etc/opkg/keys/776cc6b50a033ebf
# prints: 776cc6b50a033ebf
```

Once the key is in place, keep `option check_signature` enabled in
`/etc/opkg.conf` and `opkg update` will verify `Packages.sig`.

The matching **private** key is only used by the CI (repository secret
`USIGN_SECRET`). Keep a backup of it somewhere safe: it is needed to sign
future builds, and it must never be committed or shipped.

## Building the package without the SDK

```sh
./build-ipk.sh
```

The result is written to `dist/`.

## Credits

Upstream application: <https://github.com/openwrt/luci/tree/master/applications/luci-app-tailscale-community>
(by Tokisaki-Galaxy). This repository only adapts the packaging for the 23.05
release and older ucode/LuCI versions.
