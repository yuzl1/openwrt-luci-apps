# luci-app-tailscale-community for OpenWrt / ImmortalWrt 23.05

English | [简体中文](README.zh-cn.md)

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
opkg install luci-app-tailscale-community_1.0.1-1_all.ipk
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

## Rotating the feed signing key

Rotate the key if the private key is lost (a lost key cannot sign new
indexes any more) or if it may have leaked. The steps below keep existing
devices working while the switch happens.

### 1. Generate a new key pair

`usign` is available on the router (`opkg install usign`), any machine with
the tool works:

```sh
usign -G -s /tmp/feed.sec -p /tmp/feed.pub \
	-c "yuzl1 luci-app-tailscale-23.05 feed"
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
