# 密钥说明

23.05 和 25.12 使用完全独立的签名体系，不能混用：

- `776cc6b50a033ebf.pub`：23.05 opkg 源（.ipk）的 usign 公钥，私钥在
  GitHub Actions secret `USIGN_SECRET`。
- `yuzl1-apk-25.12.pem`：25.12 apk 源（.apk）的 ECDSA P-256 公钥，
  位于 `openwrt-25.12` 分支，私钥在 secret `APK_SIGN_KEY_25_12`。

路由器上只安装对应版本自己的公钥，不要交叉使用。
