# NCM Profile Fix

专为 **网易云音乐 Android 8.10.50** 设计的 **LSPosed Modern API 102** 兼容补丁。

## 问题与验证

旧版网易云请求自己的个人主页时，服务端额外下发 `PERSONAL_MY_COMMENT` 模块。模块里的歌曲/歌手/专辑部分 `alias` 属性现在可能是 JSON 字符串或 `null`，而客户端旧版 `Comment.fromJson()` 使用 `JSONObject.getJSONArray("alias")`，导致 `JSONException` 和“加载失败，请稍后再试”。

已经使用本机 MITM 的两轮 A/B 测试验证：
- 删除完整 `PERSONAL_MY_COMMENT` 模块：主页恢复正常。
- 保留评论模块，只规范化 `alias` 字段类型：主页同样恢复正常。

**注意：** A/B 测试确认的是网络响应修补思路。该独立 LSPosed APK 尚未经过真机验证。

## 修复范围

- 只注入 `com.netease.cloudmusic`。
- 使用 Modern libxposed API 102：`META-INF/xposed/java_init.list`，不是旧式 `IXposedHookLoadPackage`。
- 在网易云进程中 Hook `JSONObject.getJSONArray(String)`，**仅当字段名为 `alias` 且当前调用栈含 `com.netease.cloudmusic.meta.Comment.fromJson`** 时生效。
- 字符串转换为数组（空字符串转 `[]`，非空字符串转 `[value]`）；JSON null 转 `[]`。
- 原本已经是数组的值、其他字段、其他解析调用全部保持原状。
- 不要求网络权限，不读取 Cookie，不上传个人资料。

## 下载安装

打开仓库的 **Actions → Android APK**，选择最新成功的 Run，在底部 **Artifacts** 下载：
- `ncm-profile-fix-debug-ephemeral-signature`：可以直接做首次测试，但不同 Actions Runner 产生的调试签名不一定一样。
- `ncm-profile-fix-release-signed`：设置好持久化签名 Secrets 后生成，适合以后持续覆盖升级。

安装 APK → LSPosed 管理器中启用模块 → 只勾选网易云音乐作用域 → 强行停止网易云 → 重新打开个人主页。记录日志：

```sh
adb logcat -s NCMProfileFix:I '*:S'
```

若不能加载，请关闭模块并导出网易云的 logcat，优先检查有无 `Hook installation failed` 及 `JSONException`。不必清除网易云数据。

## 持久化签名

**不要**将 `.p12`、密码或完整用户 HAR 提交到公开仓库。GitHub Actions 的 Secrets 需要四项：

| Secret | 作用 |
|---|---|
| `KEYSTORE_BASE64` | PKCS#12 签名文件的 Base64 |
| `KEYSTORE_PASSWORD` | 密钥库密码 |
| `KEY_ALIAS` | 签名别名 |
| `KEY_PASSWORD` | 私钥密码 |

在可信本地 Linux / macOS / WSL / Git Bash 环境准备 `keytool`、`openssl`、`base64`、`gh`，然后执行一次：

```sh
gh auth login
bash scripts/setup-signing.sh
```

脚本生成一次有效期约 100 年的 RSA 签名密钥，将敏感值存到 GitHub Secrets，同时在本地留下**必须另行备份**的 `.p12` 文件和密码文件。之后每次 Actions 编译复用同一证书。GitHub Secrets 设置好后手动重跑 workflow 或推送代码即可生成正式签名 APK。

调试 APK 和正式签名 APK **不能直接互相覆盖安装**；首次长期使用建议直接安装正式签名版本。

## 开发编译

需要 JDK 17、Android SDK Platform 36、Gradle 8.13：

```sh
gradle :app:assembleDebug
```

GitHub Actions 会自动安装构建环境，仓库无需提交 Gradle Wrapper 或 Android SDK。

## 状态

- 代码：实验性；首次构建与真机 Hook 尚待验证。
- API：`io.github.libxposed:api:102.0.0`（`compileOnly`）。
- 仅明确针对网易云音乐 8.10.50，其他版本可能有不同解析逻辑。
