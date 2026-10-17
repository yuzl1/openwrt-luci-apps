#
# LuCI support for Tailscale, backported to OpenWrt 23.05 / ImmortalWrt 23.05.
#
# The application itself is architecture independent (JS view + ucode RPC),
# so the resulting package is built with LUCI_PKGARCH:=all and can be used on
# any 23.05 target as long as tailscale and rpcd-mod-ucode are present.
#

include $(TOPDIR)/rules.mk

LUCI_TITLE:=LuCI support for Tailscale
LUCI_URL:=https://github.com/openwrt/luci/tree/master/applications/luci-app-tailscale-community
LUCI_DESCRIPTION:=Web management interface for Tailscale: status, login/logout, settings and subnet routes.
PKG_DESCRIPTION:=$(LUCI_DESCRIPTION)
PKG_MAINTAINER:=yuzl1
PKG_VERSION:=1.0.1
PKG_RELEASE:=1

LUCI_DEPENDS:=+tailscale +ip-full +luci-base +rpcd-mod-ucode +ucode +ucode-mod-fs +ucode-mod-uci +ucode-mod-ubus
LUCI_PKGARCH:=all

include $(TOPDIR)/feeds/luci/luci.mk
