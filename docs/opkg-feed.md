# 把本仓库配置成 opkg 软件源（全程可在 LuCI 网页完成）

本仓库每次构建都会把 `Packages.gz` 和 ipk 发布到 `gh-pages` 分支，因此可以
直接当作一个 opkg 源使用：

```
https://yuzl1.github.io/luci-app-tailscale-23.05
```

## 1. 添加软件源

1. 打开 LuCI：**系统 → 软件包**
2. 点右上角 **配置**（Configuration），会弹出 `OPKG Configuration` 窗口
3. 在文本框 `/etc/opkg/customfeeds.conf` 末尾追加一行：

```
src/gz tailscale23 https://yuzl1.github.io/luci-app-tailscale-23.05
```

4. 先不要关窗口，继续下一步

## 2. 允许未签名的源

OpenWrt 默认要求每个源都带 `Packages.sig` 签名文件，自建源没有签名，所以
`opkg update` 会报：

```
Failed to download .../Packages.sig, wget returned 8
```

在同一个 `OPKG Configuration` 窗口里，把 `/etc/opkg.conf` 中的这一行

```
option check_signature
```

改成（前面加 `#` 注释掉）：

```
# option check_signature
```

然后点 **保存（Save）**。

> 注意：这个开关是全局的，关掉之后对所有源都不再校验签名。只在你信任这个
> 源、并且这些源本身可信的情况下才这样做。想要保留签名校验，可以给本 feed
> 加 usign 签名（需要把签名私钥放进仓库 secret，再在 CI 里生成
> `Packages.sig`），需要的话可以再配。

## 3. 刷新并安装

1. 回到 **系统 → 软件包**，点 **刷新列表**（Update lists）
2. 搜索 `luci-app-tailscale-community`
3. 点 **安装** —— opkg 会自动把依赖一起装上：
   `tailscale`、`ip-full`、`luci-base`、`rpcd-mod-ucode`、
   `ucode-mod-fs/uci/ubus`

## 4. 验证

* 菜单出现 **服务 → Tailscale**
* 命令行验证：

```sh
opkg update
opkg list | grep luci-app-tailscale
opkg list-installed | grep -E 'tailscale|ip-full'
```

## 命令行的等价操作

不想点网页时，同样的事情可以用下面几条命令完成：

```sh
echo 'src/gz tailscale23 https://yuzl1.github.io/luci-app-tailscale-23.05' \
	>> /etc/opkg/customfeeds.conf
sed -i 's/^option check_signature/# option check_signature/' /etc/opkg.conf
opkg update
opkg install luci-app-tailscale-community
```

## 以后升级

仓库打新的 `v*` tag 后，CI 会自动更新 `gh-pages` 上的索引并生成 Release。
路由器上只要 **刷新列表 → 在软件包里点升级** 即可，不需要再手动传 ipk。

## 安装完之后的首次配置

1. **服务 → Tailscale**，确认 **Enable Tailscale Service** 已勾选并保存
   （不勾选会把 tailscaled 停掉，页面会显示 NOT RUNNING）
2. 切到 **Account Settings**，点 **Login**，用给出的链接登录 Tailscale 账号
3. 需要子网路由时：勾选 **Advertise Routes** 选内网网段 → **Auto Configure
   Firewall** → 到 Tailscale 后台给这台设备批准（Approve）子网路由
