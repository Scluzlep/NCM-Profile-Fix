# NCM Profile Fix

网易云音乐 Android **8.10.50** · **LSPosed Modern API 102**

修复旧版网易云音乐进入自己的个人主页时提示 **“加载失败，请稍后再试”** 的问题，同时保留个人评论模块。

## 原因与验证

网易云服务端为本人主页下发 `PERSONAL_MY_COMMENT` 模块，其中部分歌曲、歌手或专辑信息的 `alias` 属性现在可能为 JSON 字符串或 `null`。旧版客户端在 `Comment.fromJson()` 中把它作为 `JSONArray` 读取，触发 `JSONException`，使个人主页加载失败。

问题定位与验证过程：

1. 访问他人主页正常（没有返回该评论模块），访问本人主页失败。
2. Android `logcat` 记录到 `Comment.fromJson()` / `getJSONArray("alias")` 类型转换异常。
3. 本机 MITM 测试：删除评论模块，主页可正常加载。
4. 本机 MITM 测试：保留评论模块，仅纠正 `alias` 类型，主页仍可正常加载。

## 修复方式

- 仅作用于网易云音乐进程：`com.netease.cloudmusic`。
- 使用 `io.github.libxposed:api:102.0.0`（Modern API），不使用旧版 `IXposedHookLoadPackage`。
- Hook `JSONObject.getJSONArray(String)`，仅当参数是 `alias` 且调用栈包含 `com.netease.cloudmusic.meta.Comment.fromJson` 时修正类型。
- 空字符串与 `null` 转为 `[]`，其他非空字符串转为包含该字符串的数组；原本正确的数组及其他字段保持不变。
- 不需要网络权限，不读取账号 Cookie，也不收集或上传个人信息。

## 下载安装

前往 **[Releases](https://github.com/Scluzlep/NCM-Profile-Fix/releases)**，下载最新版本的 **`NCM-Profile-Fix-v*.apk`**。

安装 APK → 在支持 Modern API 102 的 LSPosed 管理器中启用模块 → 作用域选择 **网易云音乐** → 强制停止网易云音乐并重新打开 → 进入自己的个人主页。

如果要排查运行状态，可使用：

```sh
adb logcat -s NCMProfileFix:I '*:S'
```

若模块未生效，先检查作用域、LSPosed API 102 支持情况及日志。无需清除网易云账号数据。

## 兼容性

| 项目 | 状态 |
|---|---|
| 网易云音乐 Android 8.10.50 | 已真机验证 |
| LSPosed Modern API 102 | 已真机验证 |
| 其他版本网易云音乐 | 尚未逐个测试 |

## 自行编译

需要 JDK 17、Android SDK Platform 36、Gradle 8.13：

```sh
gradle :app:assembleDebug
```

推送至 `main` 会在 GitHub Actions 构建测试 APK；推送版本标签 `vX.Y.Z` 时，在签名配置完成且构建通过后自动发布 GitHub Release。
