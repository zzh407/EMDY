# EMDY

<div align="center">

**Emby 短视频客户端** — 像刷短视频一样看自己的影音库

[![HarmonyOS](https://img.shields.io/badge/HarmonyOS-API%2012-blue.svg)](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides-V5/application-dev-guide-V5)
[![Android](https://img.shields.io/badge/Android-API%2034-green.svg)](https://developer.android.com/about/versions/14)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](#)

[下载最新版本](https://github.com/zzh407/EMDY/releases/latest) · [问题反馈](https://github.com/zzh407/EMDY/issues) · [功能建议](https://github.com/zzh407/EMDY/issues/new?labels=enhancement)

</div>

---

## 简介

EMDY 是一个运行在 HarmonyOS 和 Android 平台上的 Emby 短视频客户端，用竖屏滑动的方式浏览和播放 Emby 媒体库中的视频，带来类似主流短视频平台的流畅体验。

**当前版本**：v1.4.1

## 功能特性

### 核心功能

#### 播放与浏览
- 🔐 **Emby 账号登录** — 支持服务器地址、用户名、密码登录，可选记住登录信息
- 📱 **竖屏短视频流** — 上下滑动切换视频，自动预加载后续内容，流畅丝滑
- 🔄 **自动连播** — 视频播放结束自动跳转下一条；随机模式播完自动重新洗牌
- ⚡ **长按倍速** — 按住画面快进观看（1.25x ~ 3x 可选），松开恢复原速
- ⏩ **左右拖动进度** — 全屏宽度对应视频时长，拖动时实时预览，松手精确跳转
- 🎬 **沉浸式播放** — 默认全屏隐藏系统栏，可一键切换；隐藏控件后保留右下角眼睛图标
- 🔇 **冷启动静音** — 每次打开默认静音，切后台再回来保持当前选择
- 📊 **视频信息** — 底部展示作者头像、作者名、标题、时长、简介

#### 收藏管理
- ❤️ **一键收藏** — 播放页右侧心形按钮，点击后爱心变红并弹出提示
- 💾 **本地持久化** — 收藏保存在本机，断网也能回看已收藏内容
- 📚 **喜欢媒体库** — 媒体库列表首位固定「喜欢」虚拟库，集中浏览全部收藏
- 🔖 **收藏角标** — 媒体网格中已收藏视频显示红色心形角标

#### 视频管理
- 🗑️ **单条删除** — 播放页右侧垃圾桶按钮，二次确认后永久删除，带滑动动画
- 📦 **批量删除** — 网格页长按进入多选模式，支持全选、批量删除，串行执行
- 👤 **作者筛选** — 点击作者头像或 `@作者名`，自动筛选该作者的全部视频
- 🏷️ **标签筛选** — 点击 Genres 或 Tags 标签，筛选当前媒体库中带该标签的视频

#### 媒体库与界面
- 📋 **媒体库切换** — 登录后拉取服务器媒体库列表，「喜欢」固定在第一位
- 🔄 **扫描媒体库** — 设置中通知 Emby 服务器重新扫描，后台执行
- 🖼️ **全部视频网格** — 竖版 9:16 大图预览，每行 2 个，显示播放中标记与收藏角标
- 🎭 **隐藏合集** — 可选过滤合集、播放列表等聚合条目，只看单个视频
- ⚙️ **播放设置** — 随机播放、隐藏合集、记住登录、长按加速档位
- 🎨 **折叠屏适配** — 宽度 ≥ 600vp 自动进入宽屏模式（信息流限宽、网格每行 4 个）

### 安全与性能

- 🔒 **二次确认** — 所有删除操作均需确认，弹窗展示将删除的视频标题
- 🛡️ **防误删** — 删除期间锁定滑动操作，按视频 ID 精确匹配，不会误删其他视频
- 🚀 **性能优化** — 协程管理、Pager 单向同步、非活跃页停止轮询、收藏写入序列化

## 技术栈

### HarmonyOS 端

| 技术 | 用途 |
|------|------|
| **ArkTS / ArkUI** | 声明式 UI 开发 |
| **HarmonyOS API 12** | 系统接口 |
| **@kit.NetworkKit** | Emby HTTP API（登录、媒体库、视频流、删除） |
| **@kit.ArkData** | preferences 保存登录、收藏与设置 |
| **@kit.ArkUI Video** | 视频播放，PanGesture/LongPressGesture 实现进度拖动与倍速 |
| **Hvigor** | 构建工具 |

### Android 端

| 技术 | 用途 |
|------|------|
| **Kotlin** | 开发语言 |
| **Jetpack Compose (Material3)** | 声明式 UI |
| **Media3 ExoPlayer** | 视频播放（直连 / HLS 自适应） |
| **OkHttp** | Emby API 网络请求 |
| **kotlinx.serialization** | JSON 序列化 |
| **DataStore** | 持久化登录、收藏与设置 |
| **Coil** | 图片加载 |
| **Gradle 8.7** | 构建工具 |

## 项目结构

```
emdy/
├── entry/                          # HarmonyOS 端
│   └── src/main/ets/
│       ├── entryability/           # 应用入口
│       ├── model/
│       │   └── EmbyModels.ets      # 数据模型
│       ├── pages/
│       │   ├── Index.ets           # 主页面（登录 + 信息流 + 全部交互）
│       │   └── ShortVideoCard.ets  # 播放器卡片组件
│       └── service/
│           ├── AppSettings.ets     # 本地偏好设置
│           ├── EmbyClient.ets      # Emby API 封装
│           ├── FavoriteStore.ets   # 收藏持久化
│           └── SessionStore.ets    # 会话持久化
├── android/                        # Android 端
│   └── app/src/main/java/com/zzhs/emdy/
│       ├── data/
│       │   ├── EmbyClient.kt       # Emby API 封装
│       │   ├── EmbyModels.kt       # 数据模型
│       │   ├── FavoriteStore.kt    # 收藏持久化
│       │   └── SessionStore.kt     # 会话持久化
│       └── ui/
│           ├── EmdyState.kt        # 全局状态与业务逻辑
│           ├── FeedScreen.kt       # 信息流页面
│           ├── VideoCard.kt        # 播放器卡片
│           ├── MediaListScreen.kt  # 媒体网格页面
│           └── Dialogs.kt          # 对话框组件
└── icon-design/
    └── gen_icon.py                 # 应用图标生成脚本
```

## 快速开始

### HarmonyOS

**前置要求**
- DevEco Studio 5.0.3.403+
- HarmonyOS SDK API 12

**构建步骤**

```bash
# 安装依赖
ohpm install

# 构建 HAP
hvigorw assembleHap --mode module -p product=default

# 生成的 HAP 位于
# entry/build/default/outputs/default/entry-default-signed.hap
```

或直接在 DevEco Studio 中打开工程，连接真机或模拟器后点击运行。

### Android

**前置要求**
- JDK 17
- Android SDK API 34
- Gradle 8.7（已包含 wrapper）

**构建步骤**

```bash
cd android

# 构建 APK
./gradlew assembleDebug

# 生成的 APK 位于
# android/app/build/outputs/apk/debug/app-debug.apk
```

或在 Android Studio 中打开 `android/` 目录，连接设备后点击运行。

## 使用指南

### 首次使用

1. 打开应用，输入 Emby 服务器地址（例如 `http://192.168.1.10:8096`）
2. 输入用户名和密码，点击登录
3. 登录成功后进入竖屏信息流

### 交互操作

| 操作 | 效果 |
|------|------|
| 上下滑动 | 切换视频（自动预加载） |
| 单击画面 | 暂停 / 继续播放 |
| 左右滑动 | 拖动进度，实时预览，松手跳转 |
| 长按画面 | 倍速快进（档位见设置） |
| 点击头像 / `@作者名` | 筛选该作者的全部视频 |
| 点击心形 | 收藏 / 取消收藏 |
| 点击垃圾桶 | 删除当前视频（需确认，不可恢复） |

### 其他功能

- **顶部操作**：切换媒体库、打开「全部视频」网格（长按网格项可批量删除）
- **右侧按钮**：播放模式（顺序/随机）、全屏、静音、隐藏控件
- **设置面板**：随机播放、隐藏合集、记住登录、倍速档位、扫描媒体库、更换服务器

## 更新日志

### v1.4.1 (2026-10-16)

**Bug Fixes**
- 🐛 修复 HarmonyOS 定时器泄漏：`aboutToDisappear` 清理 `hintTimer`/`deleteAnimTimer`
- 🐛 修复 HarmonyOS Swiper 复用播放器状态残留：`@Watch('onItemChanged')` 无条件重置播放器
- 🐛 修复 Android `loadVideos` 竞态：reset 时无条件取消旧请求，避免旧响应覆盖新筛选
- 🐛 修复 Android `finally` 块污染：仅当此 job 仍是当前 job 时才解除 `isLoading`
- 🐛 修复 Android Pager 双向同步回弹：改为单向同步（仅 pager→state）
- 🐛 优化 Android VideoCard 进度轮询：非活跃页不轮询，节省资源
- 🐛 修复 Android 收藏并发写入：统一 `saveFavoritesAsync()` 序列化保存
- 🐛 修复 Android 提示残留：`showHint` 使用 `tryFinally` 确保取消时清空

**Code Quality**
- ✨ `EmbyLibrary.ALL` 常量消除 3 处硬编码
- ✨ `syncCurrentIndex` 空列表保护
- ✨ `loadLibraries` 失败时提示用户而非静默
- ✨ MediaListScreen 触底加载优化

### v1.4.0 (2026-10-15)

- Initial release with full features

## 权限说明

### HarmonyOS
- `ohos.permission.INTERNET` — 访问 Emby 服务器

### Android
- `android.permission.INTERNET` — 访问 Emby 服务器

## 注意事项

- 本项目仅用于访问自建的 Emby 媒体库，不会向第三方上传数据
- 登录信息与喜欢收藏均保存在本机偏好设置中，可在设置中清除
- 删除视频需要 Emby 账号具备删除媒体权限，权限不足时会明确提示
- 扫描媒体库需要服务端执行实际扫描，耗时取决于库的大小
- 视频能否直接播放取决于服务端文件编码，不支持时会自动提示切换兼容模式

## 开发计划

- [ ] 播放历史记录
- [ ] 字幕支持
- [ ] 音轨切换
- [ ] 更多倍速选项（0.5x, 0.75x）
- [ ] 播放统计与报表
- [ ] 多服务器支持
- [ ] PWA 版本

## 贡献指南

欢迎提交 Issue 和 Pull Request！

1. Fork 本仓库
2. 创建特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 创建 Pull Request

## 许可证

本项目采用 MIT 许可证 - 详见 [LICENSE](LICENSE) 文件

## 致谢

- [Emby](https://emby.media/) - 媒体服务器
- [HarmonyOS](https://developer.huawei.com/consumer/cn/harmonyos/) - 华为鸿蒙系统
- [Jetpack Compose](https://developer.android.com/jetpack/compose) - Android 现代 UI 工具包
- [Media3 ExoPlayer](https://developer.android.com/media/media3) - Android 媒体播放器

---

<div align="center">

**如果这个项目对你有帮助，请给一个 ⭐️ Star！**

Made with ❤️ by zzh407

</div>