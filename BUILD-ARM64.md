# Slate arm64 迁移说明

上游项目停在 2013 年（部署目标 10.6、SenTestingKit、自带的 Sparkle.framework 没有
arm64 slice），作者已不再更新。本次只做**架构迁移**，不引入任何功能改动；脚本引擎
（`WebView` + `WebScriptObject`）的源码一行未动，行为用差分测试逐项对齐原版 Intel
二进制。

## 产物

| 产物 | 说明 |
| --- | --- |
| `build/release-arm64/Slate.app` | arm64（Apple Silicon） |
| `build/release-universal/Slate.app` | x86_64 + arm64 通用（分发用） |
| `build/debug-arm64/Slate.app` | 带 `SlateLogger` 日志的调试版 |

## 构建

```bash
./script/build.sh --arch arm64          # Apple Silicon
./script/build.sh --arch universal      # 通用二进制
./script/build.sh --arch arm64 --debug  # 调试版（输出 SlateLogger 日志）
```

工具链优先使用 `xcode-select` 指向的那套（实测 Xcode 27.1 / macOS SDK 27.0），
`xcrun` 不可用时自动回退到 Command Line Tools。也可以用 `SLATE_CLANG` /
`SLATE_SDK` 显式指定。

构建不依赖 `ibtool`：`MainMenu.xib` 没有改动，直接复用原版发布包里由 ibtool 编译
好的 `MainMenu.nib`。

## 相对上游的改动

全部改动都在这几个地方，`Slate/` 下只动了一个文件的两行：

### 1. 移除 Sparkle（`build-support/SUUpdaterStub.m` 垫片）

自带 Sparkle 只有 `ppc/i386/x86_64`，arm64 无法链接。上游已停止更新，"检查更新"
没有意义，因此 arm64 版不再打包 Sparkle。

但 `MainMenu.nib` 里有一个 `SUUpdater` 自定义对象和 `checkForUpdates:` 动作，直接
删掉框架会导致 nib 解档失败（启动即崩）。`build-support/SUUpdaterStub.m` 提供了一个
同名的空实现：nib 正常解档，`Check for Updates` 菜单项变成空操作（写一条日志）。

### 2. 重新实现 `relaunch` 辅助程序（`build-support/relaunch.m`）

`SlateAppDelegate -relaunch`（菜单 "Relaunch and Load Config"）通过
`bundleForClass:[SUUpdater class]` 在 bundle 里找 Sparkle 自带的 `relaunch` 工具。
那个工具是 x86_64-only，无法在 arm64 上运行，所以这里重新实现了一个契约完全相同的
小工具：`relaunch <app 路径> <pid>`，等待 pid 退出后重新打开 app。构建时会把它放进
`Contents/Resources/` 并单独签名（公证要求）。

### 3. `Slate/ShellUtils.m`：不跑 runloop 的等待（唯一源码改动）

原代码用 `-[NSTask waitUntilExit]` 等待子进程。该方法会自旋主线程 runloop；而
`ShellUtils` 可以从 `WebScriptObject` 求值内部被调用（`slate.sh(...)`，或 JS 里执行
`shell` 操作）。在 arm64 上，这个嵌套 runloop 会让 WebKit 销毁当前正在执行 JS 的
上下文，于是调用失败：

```
ReferenceError: Trying to access object from destroyed plug-in.
```

两处 `waitUntilExit` 都改成轮询 `-[NSTask isRunning]`（`usleep(5000)`），阻塞语义和
返回值保持不变，只是不再服务 runloop。原版 Intel 二进制不受影响，行为一致。

### 4. 编译标志 `-D__OBJC_BOOL_IS_BOOL=0`

arm64 上 clang 预定义 `__OBJC_BOOL_IS_BOOL=1`，`BOOL` 是 C99 `bool`，方法类型编码
为 `'B'`；WebKit 的桥接会把 `'B'` 返回值转成 JS `boolean`。而原版 x86_64 上
`BOOL` 是 `signed char`（编码 `'c'`），桥接转成 JS `number`。差异示例：

```js
slate.source("/nonexistent")   // 原版: 0    arm64(未修正): false
```

`objc.h` 明确支持覆盖该宏，ABI 完全一致（1 字节、w0 返回）。加上这个标志后，
所有返回 `BOOL` 的脚本 API（`source`、`isRectOffScreen`、`main` 等）编组结果与原版
逐字节一致。

### 5. 部署目标 10.6 → 11.0

arm64 的最低系统版本就是 11.0；`Info.plist` 的 `LSMinimumSystemVersion` 同步为 11.0。

## 验证

差分测试会分别启动"参考二进制"和"候选二进制"，喂同一份 `script/parity/probe.js`
作为 `~/.slate.js`，抓取 `slate.log` 输出的 `T|label|value` 行并逐行对比：

```bash
./script/verify-parity.sh build/Release/Slate.app build/release-arm64/Slate.app
```

参考二进制就是仓库里原版 Intel 包（在 Apple Silicon 上经 Rosetta 运行）。探针覆盖：

- JS 语义：浮点/位运算/正则/JSON/`underscore`/闭包/异常/`typeof` 等
- ObjC ↔ JS 编组：`BOOL` 返回值、字典、数组、ObjC 回调（`eachScreen`）
- shell 桥接：`slate.sh` 的等待/不等待、stdout+stderr 合并、空输出、返回类型

当前结果：

```
probe results: reference=66 candidate=66
PASS: script engine output is identical (66 probes)
```

另外手工验证过：

- nib 正常解档（`SUUpdater` 垫片生效），应用可常驻菜单栏
- 真实 `~/.slate.js` 完整加载：`JS INIT FINISHED` → `Config loaded.`
- `Relaunch and Load Config`：旧进程退出后新进程被拉起

## 签名与公证（对外分发）

```bash
./script/build.sh --arch universal \
  --sign "Developer ID Application: <你的名字> (<TEAMID>)"

ditto -c -k --keepParent build/release-universal/Slate.app /tmp/Slate.zip
xcrun notarytool submit /tmp/Slate.zip --keychain-profile <profile> --wait
xcrun stapler staple build/release-universal/Slate.app
```

`--sign` 会启用 hardened runtime + 安全时间戳，并**先签 `Contents/Resources/relaunch`
再签整个 bundle**（顺序反了外层封印会失效，`notarytool` 会拒绝）。

## 已知差异与注意事项

- **自动更新已移除**：`Check for Updates…` 菜单项保留但为空操作；`Info.plist` 里的
  `SUFeedURL` 没有代码再读取。
- **不再包含 `Sparkle.framework`**（`build/Release/Slate.app` 是原版，仍然包含）。
- **需要重新授予辅助功能权限**：新构建的签名/路径是一个新的 TCC 身份。首次启动后到
  "系统设置 → 隐私与安全性 → 辅助功能" 里勾选新的 Slate；否则会看到
  `Could not fetch focused window` 之类的日志，窗口操作不生效。
- **未修改 `Slate.xcodeproj`**：`xcodebuild` 不作为构建路径（10.6 部署目标、
  SenTestingKit、Sparkle 无 arm64，而且 2013 年的工程格式在现代 Xcode 下需要大量
  修补）。Xcode 在这里只用于提供 SDK/clang 和 `notarytool`。
- 上游的单元测试目标使用已被移除的 SenTestingKit，未纳入本次迁移；脚本引擎的回归
  由 `script/verify-parity.sh` 覆盖。

## GitHub Actions

`.github/workflows/build.yml`（参考 `nuclearg/coeditor` 的桌面流水线）：

- **push `master` / PR / 手工触发**：在 `macos-latest`（arm64）上矩阵构建
  `arm64` 与 `universal`，上传为 Actions artifact（保留 14 天）
- **push tag `v*`**：先建（或复用）Draft Release，再由两个矩阵 job 上传
  `Slate-<version>-<arch>.zip` 和 `.sha256`
- **arm64 job**：安装 Rosetta 后，用原版 Intel 二进制做
  `script/verify-parity.sh` 对比（66 项）；runner 无 GUI session 时以 SKIP
  告警，不误报失败
- **签名/公证**：配置了与 coeditor 同名的 secrets 时，对 universal 包做
  Developer ID 签名 + 公证 + staple；未配置则自动降级为 ad-hoc

```bash
git tag v1.0.25 && git push origin v1.0.25   # 触发 Draft Release
```

需要的 secrets（与 `nuclearg/coeditor` 同名，可在那边 `gh secret list` 核对）：

```
APPLE_CERTIFICATE
APPLE_CERTIFICATE_PASSWORD
KEYCHAIN_PASSWORD
APPLE_SIGNING_IDENTITY
APPLE_API_KEY
APPLE_API_KEY_P8_BASE64
APPLE_API_ISSUER
APPLE_TEAM_ID
```

## 分发：为什么不在 Mac App Store

Slate 依赖辅助功能 API（`AXUIElement`）移动/缩放/聚焦**其他应用**的窗口。Mac App Store
强制 App Sandbox，而沙盒中没有任何 entitlement 允许操作其他进程的窗口，因此这类工具
（Magnet、Rectangle、BetterSnapTool…）都只能在 App Store 之外分发。另外 GPLv3 与
App Store 的 DRM/条款冲突（VLC 曾因此下架）。

正式包的标准路径是 **Developer ID 签名 + 公证 + staple**：

```bash
git tag v1.0.25 && git push origin v1.0.25
```

CI 会：构建 universal → Developer ID 签名（hardened runtime）→ notarytool 公证 →
staple → `spctl` 校验 → 创建 Draft Release 并上传 `Slate-<version>-universal.zip`
和 `.sha256`。arm64 单独构建保留为 Actions artifact，不进 Release（它是 ad-hoc 签名）。

仓库 secrets（与 coeditor 同名）：

```
APPLE_CERTIFICATE            # Certificates.p12 的 base64
APPLE_CERTIFICATE_PASSWORD   # p12 密码
KEYCHAIN_PASSWORD            # CI 临时 keychain 密码（随机）
APPLE_SIGNING_IDENTITY       # "Developer ID Application: ji li (98C4AQNKS9)"
APPLE_API_KEY                # App Store Connect Key ID
APPLE_API_KEY_P8_BASE64      # AuthKey_<KeyID>.p8 的 base64
APPLE_API_ISSUER             # App Store Connect Issuer ID (UUID)
APPLE_TEAM_ID
```

用户首次启动后，需要在「系统设置 → 隐私与安全性 → 辅助功能」中勾选 Slate，否则
窗口操作不会生效（每次替换二进制后签名身份变化时可能需要重新授权）。

## Homebrew Cask

仓库里带了 `Casks/slate-amd64.rb`（token 按 arm64 迁移命名；包本身是 universal，
Intel 机器也能装）：

```bash
brew tap nuclearg/slate https://github.com/nuclearg/slate
brew install --cask slate-amd64
```

升级时改 `Casks/slate-amd64.rb` 里的 `version` 与 `sha256`（取自 Release 的
`.sha256` 文件）即可。若以后单独建 `nuclearg/homebrew-slate` 仓库，就可以省掉
显式 URL，直接 `brew tap nuclearg/slate`。
