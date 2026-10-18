# yuzl1 OpenWrt LuCI apps feed

English | [简体中文](README.zh-cn.md)

This repository is a small personal opkg feed for OpenWrt / ImmortalWrt 23.05.
It publishes the following packages:

| Package | Description |
| --- | --- |
| `luci-app-tailscale-community` | LuCI UI for the official `tailscale` package |
| `tailscale` | current upstream Tailscale daemon cross-built for the Redmi AX3000 ARMv7 target |
| `luci-app-ddns-lite` | standalone DNSPod DDNS updater with legacy Token and Tencent Cloud TC3 authentication |

The LuCI packages are architecture independent (`Architecture: all`); the
`tailscale` core is built for the Redmi AX3000 ARMv7 target. All packages are
published to the `gh-pages` branch as a normal opkg feed, together with a
signed `Packages` index.

The ARMv7 `tailscale` package depends on `iptables-nft`, `ip6tables-nft`, and
the conntrack/NAT kernel modules: upstream Tailscale does not build its native
nftables backend on 32-bit ARM, so it uses the iptables compatibility path
backed by nftables.

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
opkg install luci-app-tailscale-community_1.0.2-1_all.ipk
```

Then open `http://<router>/cgi-bin/luci/admin/services/tailscale`.

### Install straight from the opkg feed

Every build publishes `Packages.gz` and the ipk to the `gh-pages` branch, so
the repository can be used as a normal package feed. See
[docs/opkg-feed.md](docs/opkg-feed.md) for the step by step instructions
(the whole setup can be done from the LuCI web interface).

Short version:

```sh
echo 'src/gz tailscale23 https://yuzl1.github.io/openwrt-luci-apps' \
	>> /etc/opkg/customfeeds.conf
sed -i 's/^option check_signature/# option check_signature/' /etc/opkg.conf
opkg update
opkg install luci-app-tailscale-community
```

The package depends on `tailscale`, `ip-full`, `luci-base`, `rpcd-mod-ucode`
and the ucode modules, so opkg pulls those in automatically. Afterwards the
app shows up in *LuCI -> Services -> Tailscale*.

## Changing the Tailscale listen port

The *General Settings* tab has a **Listen Port** field (UDP, default
`41641`). Saving it writes `tailscale.settings.port` and restarts the
service when the value differs from the running one.

The same from the command line:

```sh
uci set tailscale.settings.port='41642'
uci commit tailscale
/etc/init.d/tailscale restart
```

Verify with `netstat -lnup | grep tailscaled`.

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
untrusted comment: yuzl1 openwrt-luci-apps feed
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

## DDNS Lite

`luci-app-ddns-lite` is now a standalone DNSPod client. It no longer generates
or depends on `ddns-scripts`, and its version sequence restarted at `1.0.0`.

* *Services -> DDNS Lite*: choose legacy DNSPod Token or Tencent Cloud
  SecretId/SecretKey authentication and set the check interval
* IPv4 and IPv6 are configured separately, each with one of four IP sources:
  logical interface (`network`), network device (`interface`), URL check
  (`web`) or a command (`script`)
* built-in IPv4 check URLs: `myip.ipip.net`, `ddns.oray.com/checkip`,
  `ip.3322.net`, `4.ipw.cn`, `v4.yinghualuo.cn/bejson`
* built-in IPv6 check URLs: `speed.neu6.edu.cn/getIP.php`, `v6.ident.me`,
  `6.ipw.cn`, `v6.yinghualuo.cn/bejson`
* the root zone is detected from the DNSPod account, so both
  `*.ipv4.example.com` and `ipv4.example.com` work without manually writing
  `host@zone`; an explicit `host@zone.tld` is also accepted
* an optional **Root domain** field lets you enter `example.com` directly and
  skip zone auto-detection entirely
* the updater calls `Record.List`, `Record.Create`, and `Record.Modify`
  directly and records failures in `logread -e ddns-lite`
* every run logs each configured domain together with its active address,
  including when the DNSPod value was already correct
* legacy DNSPod response code `10` is treated as an empty record list, allowing
  the first AAAA record to be created automatically
* `1.0.1` removes a locale-sensitive `tr [:upper:] [:lower:]` dependency that
  could corrupt lowercase domain names on BusyBox 1.36
* legacy Token mode needs only `curl` and `jsonfilter`; Tencent Cloud TC3 mode
  additionally requires `openssl-util` (`opkg install openssl-util`)
* upgrading from `1.7.x` removes only old `/etc/config/ddns` entries marked
  `managed_by ddns-lite`; manually created ddns-scripts entries are untouched

Because the independent implementation deliberately restarted at `1.0.0`,
opkg considers it older than `1.7.x`. After refreshing the feed, force this
one downgrade so the configuration is kept:

```sh
opkg update
opkg install --force-downgrade luci-app-ddns-lite
```

> `rpcd` is reloaded instead of restarted after an RPC-plugin update, so the
> current LuCI login session should remain valid.

## Rotating the feed signing key

Rotate the key if the private key is lost (a lost key cannot sign new
indexes any more) or if it may have leaked. The steps below keep existing
devices working while the switch happens.

### 1. Generate a new key pair

`usign` is available on the router (`opkg install usign`), any machine with
the tool works:

```sh
usign -G -s /tmp/feed.sec -p /tmp/feed.pub \
	-c "yuzl1 openwrt-luci-apps feed"
usign -F -p /tmp/feed.pub          # new key id, also the file name
```

### 2. Publish the new public key and secret

1. Add the new public key to the repository as `keys/<new-key-id>.pub`
   (the file name **is** the key id printed by `usign -F -p`).
2. Update the CI secret: *Settings -> Secrets and variables -> Actions ->
   `USIGN_SECRET` -> Update* and paste the new private key (both lines).

Do **not** delete the old `keys/<old-key-id>.pub` yet.

### 3. Add the new public key to every device first

Before the new signature is published, install the new public key on each
router while the old one is still present, so `opkg update` keeps working
in both cases:

```sh
scp -O keys/<new-key-id>.pub \
	root@192.168.1.1:/etc/opkg/keys/<new-key-id>
usign -F -p /etc/opkg/keys/<new-key-id>     # prints <new-key-id>
```

### 4. Publish a new signed index

Commit the new key file (or run the workflow manually). The CI signs
`Packages` with the new secret and publishes `Packages.sig`.

```sh
git add keys/<new-key-id>.pub && git commit -m "keys: rotate feed signing key"
git push
```

### 5. Verify, then drop the old key

On a device:

```sh
opkg update
```

If that passes, remove the old public key and the old `keys/*.pub` file:

```sh
rm -f /etc/opkg/keys/<old-key-id>      # on each device
git rm keys/<old-key-id>.pub          # in the repository
```

Make sure `option check_signature` is enabled in `/etc/opkg.conf` once the
signed index is published - devices that only trust the old key will reject
the new `Packages.sig`, which is why the new key is installed first.

## Building the package without the SDK

```sh
./build-ipk.sh
```

The result is written to `dist/`.

## Credits

Upstream application: <https://github.com/openwrt/luci/tree/master/applications/luci-app-tailscale-community>
(by Tokisaki-Galaxy). This repository only adapts the packaging for the 23.05
release and older ucode/LuCI versions.
