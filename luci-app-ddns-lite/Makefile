#
# DDNS Lite - ddns-go style UI on top of ddns-scripts.
#
include $(TOPDIR)/rules.mk

LUCI_TITLE:=LuCI DDNS Lite (ddns-scripts backend)
LUCI_DESCRIPTION:=Simple DDNS configuration (DNS provider, ID/token, domains) that generates ddns-scripts entries.
PKG_DESCRIPTION:=$(LUCI_DESCRIPTION)
PKG_MAINTAINER:=yuzl1
PKG_VERSION:=1.7.0
PKG_RELEASE:=1

LUCI_DEPENDS:=+ddns-scripts +ddns-scripts-services \
	+curl +luci-base +rpcd-mod-ucode +ucode +ucode-mod-fs +ucode-mod-uci +ucode-mod-ubus
LUCI_PKGARCH:=all

include $(TOPDIR)/feeds/luci/luci.mk
