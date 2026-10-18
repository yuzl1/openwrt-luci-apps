#
# DDNS Lite - standalone DNSPod updater.
#
include $(TOPDIR)/rules.mk

LUCI_TITLE:=LuCI DDNS Lite (standalone DNSPod)
LUCI_DESCRIPTION:=Standalone DNSPod updater with legacy token and Tencent Cloud TC3 authentication.
PKG_DESCRIPTION:=$(LUCI_DESCRIPTION)
PKG_MAINTAINER:=yuzl1
PKG_VERSION:=1.0.3
PKG_RELEASE:=1

LUCI_DEPENDS:=+curl +jsonfilter +luci-base +rpcd-mod-ucode \
	+ucode +ucode-mod-fs +ucode-mod-uci +ucode-mod-ubus
LUCI_PKGARCH:=all

include $(TOPDIR)/feeds/luci/luci.mk
