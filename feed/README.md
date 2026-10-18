# yuzl1 OpenWrt LuCI apps feed

个人自用的 OpenWrt / ImmortalWrt 23.05 opkg 软件源，`gh-pages` 分支由 CI 自动生成：
每次构建都会写入 `Packages`、`Packages.gz`、`Packages.sig` 和各插件的 `.ipk`。

* **源地址**：<https://yuzl1.github.io/openwrt-luci-apps>
* **源码仓库**：<https://github.com/yuzl1/openwrt-luci-apps>

## 添加软件源

```sh
echo 'src/gz yuzl1apps https://yuzl1.github.io/openwrt-luci-apps' \
	>> /etc/opkg/customfeeds.conf
opkg update
```

（`yuzl1apps` 只是源的名字，可以换成任意你喜欢的。）

## 签名公钥

索引使用 usign 签名，公钥 key id 为 `776cc6b50a033ebf`：

```sh
wget -O /etc/opkg/keys/776cc6b50a033ebf \
	https://raw.githubusercontent.com/yuzl1/openwrt-luci-apps/main/keys/776cc6b50a033ebf.pub
usign -F -p /etc/opkg/keys/776cc6b50a033ebf     # 输出 776cc6b50a033ebf
```

公钥装好之后，`/etc/opkg.conf` 里的 `option check_signature` 可以保持开启。

## 包列表

| 包 | 说明 |
| --- | --- |
| `luci-app-tailscale-community` | 官方 `tailscale` 包的 LuCI 界面（状态、登录、子网路由、监听端口） |
| `tailscale` | 红米 AX3000 ARMv7 的当前上游 Tailscale 静态守护进程 |
| `luci-app-ddns-lite` | 独立 DNSPod DDNS 客户端，支持旧版 Token 与腾讯云 TC3 签名，不依赖 ddns-scripts |

## 常用命令

```sh
opkg update
opkg list | grep -E 'luci-app-(tailscale|ddns)'
opkg install luci-app-tailscale-community
opkg install luci-app-ddns-lite
opkg install openssl-util            # 只有腾讯云 TC3 模式才需要
```

安装后在 LuCI 里：

* **服务 → Tailscale**
* **服务 → DDNS Lite**

## 说明

* 本分支由 GitHub Actions 自动覆盖，请不要在这里手工提交。
* 所有包都是 `Architecture: all`，适用于 23.05 系列的各个架构。
* 详细配置说明见源码仓库的 [README](https://github.com/yuzl1/openwrt-luci-apps/blob/main/README.zh-cn.md)。
