# 密钥说明

23.05 和 25.12 使用完全独立的签名体系，不能混用：

| 文件 | 用途 | 算法 | 私钥位置 |
|---|---|---|---|
| `776cc6b50a033ebf.pub` | 23.05 opkg 源（.ipk） | usign | GitHub Actions secret `USIGN_SECRET` |
| `yuzl1-apk-25.12.pem` | 25.12 apk 源（.apk） | ECDSA P-256 | GitHub Actions secret `APK_SIGN_KEY_25_12` |

- 23.05 的 `Packages` / `Packages.gz` 由 `main` 分支流水线用 `USIGN_SECRET` 签名。
- 25.12 的每个 `.apk` 和 `APKINDEX.tar.gz` 由 `openwrt-25.12` 分支流水线用
  `APK_SIGN_KEY_25_12` 签名。
- 路由器上只安装对应版本自己的公钥，不要把 23.05 的 key 和 25.12 的 key 交叉使用。
