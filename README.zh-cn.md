# luci-app-tailscale-community（OpenWrt / ImmortalWrt 23.05 移植版）

[English](README.md) | 简体中文

本仓库是一个面向 OpenWrt / ImmortalWrt 23.05 的个人 opkg 软件源，目前包含：

| 包 | 说明 |
| --- | --- |
| `luci-app-tailscale-community` | 官方 `tailscale` 包的 LuCI 界面 |
| `luci-app-ddns-lite` | ddns-go 风格的 DDNS 页面，底层用 `ddns-scripts`（纯 shell，不额外跑 Go 进程，内存占用极小） |

两个包都是 `Architecture: all`，构建后连同签名索引一起发布到 `gh-pages`
分支，可以直接作为 opkg 源使用。

把 OpenWrt 主线的 `luci-app-tailscale-community` 应用回移到 23.05 系列固件，
可以用 opkg 安装，包含 arm 32 位目标（例如红米 AX3000 / RA81）。

应用本身只是 LuCI JavaScript 加一个 ucode 的 rpcd 插件，不依赖内核，也不依赖
CPU 架构，所以打成 `Architecture: all` 的通用包。

## 提供什么

* **服务 → Tailscale** 页面：状态、登录/登出、设置、子网路由
* ubus 对象 `tailscale`
  （`get_status`、`get_settings`、`get_subroutes`、`do_login`、`do_logout`、
  `setup_firewall`）
* `/etc/config/tailscale` 里的 uci 配置

页面地址：

```
http://<路由器IP>/cgi-bin/luci/admin/services/tailscale
```

## 依赖

* OpenWrt / ImmortalWrt 23.05
* `tailscale`（官方软件包）、`ip-full`、`luci-base`
* `rpcd-mod-ucode`，以及 `ucode`、`ucode-mod-fs`、`ucode-mod-uci`、
  `ucode-mod-ubus`（23.05 默认源里都有）

这些依赖已经写进 ipk 的 `Depends`，`opkg install` 时会自动补装。

## 安装

### 方式一：直接装 ipk

从 Releases 页面下载 `luci-app-tailscale-community_*_all.ipk`，然后：

```sh
opkg update
opkg install /tmp/luci-app-tailscale-community_1.0.1-1_all.ipk
```

缺 `tailscale`、`ip-full` 等依赖时会自动从源里装。

### 方式二：添加成 opkg 软件源（推荐，之后可在网页里管理）

每次构建都会把 `Packages.gz` 和 ipk 发布到 `gh-pages` 分支，所以本仓库可以直接
当作 opkg 源。详细步骤见 [docs/opkg-feed.md](docs/opkg-feed.md)，也可以在
LuCI 网页里完成：

1. **系统 → 软件包 → 配置（Configuration）**
2. 在 `/etc/opkg/customfeeds.conf` 末尾加一行：

```
src/gz tailscale23 https://yuzl1.github.io/openwrt-luci-apps
```

3. 如果源还没有签名（见下一节），把 `/etc/opkg.conf` 里的
   `option check_signature` 注释掉，然后保存
4. 回到软件包页面点 **刷新列表**，搜索 `luci-app-tailscale-community` 安装

命令行等价写法：

```sh
echo 'src/gz tailscale23 https://yuzl1.github.io/openwrt-luci-apps' \
	>> /etc/opkg/customfeeds.conf
opkg update
opkg install luci-app-tailscale-community
```

装好后在 **服务 → Tailscale** 就能看到页面。

## 修改 Tailscale 监听端口

**常规设置** 标签里新增了 **Listen Port** 一项（UDP，默认 `41641`）。
保存后写入 `tailscale.settings.port`，如果和当前运行的端口不同会自动重启服务。

命令行等价写法：

```sh
uci set tailscale.settings.port='41642'
uci commit tailscale
/etc/init.d/tailscale restart
```

验证：`netstat -lnup | grep tailscaled`

## 源签名与公钥安装

opkg 默认要求每个源带 `Packages.sig`。本仓库的索引用 usign 签名，公钥不是秘密，
随仓库一起提供：[`keys/776cc6b50a033ebf.pub`](keys/776cc6b50a033ebf.pub)。

key id 是 `776cc6b50a033ebf`，它同时也是公钥在 `/etc/opkg/keys/` 下必须使用的
文件名。

### 从电脑上传

```sh
scp -O keys/776cc6b50a033ebf.pub \
	root@192.168.1.1:/etc/opkg/keys/776cc6b50a033ebf
```

### 直接在路由器上写入

```sh
mkdir -p /etc/opkg/keys
cat > /etc/opkg/keys/776cc6b50a033ebf <<'EOF'
untrusted comment: yuzl1 openwrt-luci-apps feed
RWR3bMa1CgM+v2US9cs2lxNpCg9n+FDyBwZvTU/cm+CvZ3mfutaY9Rt+
EOF
```

### 验证

```sh
usign -F -p /etc/opkg/keys/776cc6b50a033ebf
# 输出：776cc6b50a033ebf
```

公钥装好之后，`/etc/opkg.conf` 里的 `option check_signature` 可以保持开启，
`opkg update` 会校验 `Packages.sig`。

## 私钥备份

与公钥配对的**私钥**只由 CI 使用，保存在仓库 Secret `USIGN_SECRET` 里。
GitHub 的 Secret 只写不可读，所以一定要另外备份一份，否则以后无法继续用同一把
公钥签名。

建议存进密码管理器（1Password / Bitwarden / KeePassXC）的加密备注里，内容为下面
两行，并同时记下 key id、用途和创建日期：

```
untrusted comment: yuzl1 openwrt-luci-apps feed
RWRCSwAAAADJM8yigmcWB9yADgAaMmkizErB2QBfnEh3bMa1CgM+v3A9K7stukgc3cXmMfT/0dWcyfhqx2zIbvwuUvC8WXhjZRL1yzaXE2kKD2f4UPIHBm9NT9yb4K9neZ+61pj1G34=
```

私钥只用于给这个源签名，**不要提交到仓库，也不要外传**；泄露后别人可以伪造这个
源里的包。

备份是否完整可以这样验证（路由器上有 `usign`）：

```sh
umask 077
cat > /tmp/feed.sec <<'EOF'
（把备份的两行贴进来）
EOF
usign -F -s /tmp/feed.sec        # 应输出 776cc6b50a033ebf
rm -f /tmp/feed.sec
```

## 轮换签名密钥

私钥丢失（无法再签新索引）或怀疑泄露时需要换一对新密钥。下面顺序可以保证切换
过程中设备仍能正常更新。

### 1. 生成新密钥对

路由器上就有 `usign`（`opkg install usign`），也可以用任何装了该工具的设备：

```sh
usign -G -s /tmp/feed.sec -p /tmp/feed.pub \
	-c "yuzl1 openwrt-luci-apps feed"
usign -F -p /tmp/feed.pub          # 新的 key id，也就是文件名
```

### 2. 发布新公钥并更新 Secret

1. 把新公钥以 `keys/<新keyid>.pub` 的名字提交到仓库
2. 在 *Settings → Secrets and variables → Actions → `USIGN_SECRET` → Update*
   里粘贴新的私钥（两行）

这时**先不要删除**旧的 `keys/<旧keyid>.pub`。

### 3. 先给每台设备装上新公钥

在新签名发布之前，把新公钥装到每台路由器上（旧公钥先留着），这样新旧签名都能
通过校验：

```sh
scp -O keys/<新keyid>.pub root@192.168.1.1:/etc/opkg/keys/<新keyid>
usign -F -p /etc/opkg/keys/<新keyid>     # 输出 <新keyid>
```

### 4. 发布新的已签名索引

提交新公钥（或手动运行一次 workflow），CI 会用新私钥签发 `Packages.sig`：

```sh
git add keys/<新keyid>.pub && git commit -m "keys: rotate feed signing key"
git push
```

### 5. 验证通过后再清理旧公钥

设备上执行：

```sh
opkg update
```

通过后即可删除旧公钥和仓库里的旧文件：

```sh
rm -f /etc/opkg/keys/<旧keyid>      # 每台设备都要做
git rm keys/<旧keyid>.pub
```

注意：只信任旧公钥的设备会拒绝新签名，所以一定要**先装新公钥，再发布新签名**。

## DDNS Lite

`luci-app-ddns-lite` 用 ddns-go 的使用思路（选服务商、填 ID/Token、列域名），
但底层复用 `ddns-scripts`，不额外跑 Go 进程，内存占用很小。

* **服务 → DDNS Lite**：选服务商、填账号/ID 与 Token、设置检查间隔
* IPv4 和 IPv6 分开配置，每种都支持四种获取方式：
  逻辑接口（`network`）、网卡设备（`interface`）、URL 获取（`web`）、命令获取（`script`）
* IPv4 内置查询地址：`myip.ipip.net`、`ddns.oray.com/checkip`、
  `ip.3322.net`、`4.ipw.cn`、`v4.yinghualuo.cn/bejson`
* IPv6 内置查询地址：`speed.neu6.edu.cn/getIP.php`、`v6.ident.me`、
  `6.ipw.cn`、`v6.yinghualuo.cn/bejson`
* 点 **保存并应用** 会自动生成对应的 `/etc/config/ddns` 条目（带
  `managed_by ddns-lite` 标记）并重启 `ddns` 服务
* 通过原版 ddns-scripts 界面手工创建的条目不会被改动

服务商脚本**不再默认安装**，用哪个装哪个：

```sh
opkg install ddns-scripts-dnspod        # DNSPod / 腾讯云
opkg install ddns-scripts-cloudflare    # Cloudflare
opkg install ddns-scripts_aliyun        # 阿里云
```

页面里的服务商列表只显示已安装的服务（读取 `/usr/share/ddns/default/*.json`），
没装的自然不会出现，也不会被顺带装上。

## 不需要 SDK 的本地打包

```sh
./build-ipk.sh
```

产物在 `dist/`。仓库同时提供标准 OpenWrt `Makefile`，也可以用 SDK 构建。

## 首次使用

1. **服务 → Tailscale**，确认 **Enable Tailscale Service** 勾选并点“保存并应用”
   （不勾选会把 tailscaled 停掉，页面会显示 NOT RUNNING）
2. 切到 **Account Settings**，点 **Login**，用给出的链接登录 Tailscale 账号
3. 需要子网路由时：勾选 **Advertise Routes** 选内网网段 →
   点 **Auto Configure Firewall** → 到 Tailscale 管理后台给这台设备批准子网路由

## 常见问题

**页面显示 NOT RUNNING**

检查 `uci get tailscale.settings.service_enabled` 是否为 `1`，并在页面上勾选
“Enable Tailscale Service”后保存；也可以直接执行
`/etc/init.d/tailscale start`。

**opkg update 报 `Packages.sig ... wget returned 8`**

这个源还没生成签名。要么等 CI 产出 `Packages.sig` 并装好公钥，要么临时把
`option check_signature` 注释掉。

**网页里还出现旧的“状态 / 配置 / Maintenance / Logs”标签**

那是旧脚本版应用的浏览器缓存。用无痕窗口打开，或清除该站点缓存后强制刷新。

**页面能打开但按钮点了没反应**

本包已经为 23.05 补了 `ui.addTimeLimitedNotification` 兼容层；如果仍有问题，
请查看浏览器控制台的报错。

## 致谢

上游应用：<https://github.com/openwrt/luci/tree/master/applications/luci-app-tailscale-community>
（作者 Tokisaki-Galaxy）。本仓库只负责把它适配到 23.05 的打包方式和较旧的
ucode / LuCI 版本。
