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

Then open `http://<router>/cgi-bin/luci/admin/vpn/tailscale`.

## Building the package without the SDK

```sh
./build-ipk.sh
```

The result is written to `dist/`.

## Credits

Upstream application: <https://github.com/openwrt/luci/tree/master/applications/luci-app-tailscale-community>
(by Tokisaki-Galaxy). This repository only adapts the packaging for the 23.05
release and older ucode/LuCI versions.
