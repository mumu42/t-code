# LinguaFlow

面向 **B1→B2 中国职场技术人**（前端 / Flutter / React 开发者）的英语学习 App。
以 **SRS 复习引擎为中枢**，把词汇 / 听力 / 阅读 / 口语 / 写作 / 复习 6 大板块的记忆痕迹统一调度。

> **技术栈**：Flutter + SQLite（sqflite）· 离线优先 · 无后端 · Dart（严格类型）
> **状态**：🚧 V1 MVP 开发中（基础框架已搭建，核心引擎已实现并附单测）

---

## 一、仓库结构

```
t-code/
├── README.md                  ← 本文件
├── doc/                       ← 设计文档（单一事实来源）
│   ├── LinguaFlow.md          ← 需求总纲（定位/画像/板块/MVP/选型/商业）
│   ├── modules-connect.md     ← 六大板块数据串联规范
│   ├── prompt.md              ← 各板块 AI Prompt 模板（V2）
│   ├── dynamic-prompt-assembler.md ← Prompt 变量总表 & 兜底策略
│   ├── f1.md                  ← 定级模块（Placement）规范
│   ├── f2.md                  ← 跨平台 TTS / 录音方案
│   ├── f3.md                  ← 激励与留存层（XP + 12 级 + streak）
│   ├── f4.md                  ← 复习队列业务规则（简化 FSRS）
│   ├── f5.md                  ← 各板块独立保存代码规范
│   └── grammar.js             ← 统一语法标签 taxonomy（已移植到 Dart）
└── app/                       ← Flutter 工程
```

**`doc/` 放设计文档，`app/` 放 Flutter 代码**。文档是单一事实来源（source of truth），
所有代码实现必须能追溯回文档条款；文档与实现冲突时，先改文档再改代码。

## 二、快速开始

```bash
cd app
flutter pub get
flutter run          # 连接 Android / iOS 设备或模拟器
```

```bash
flutter analyze      # 静态检查（当前 0 issues）
flutter test         # 单元测试（SRS 算法 16 组合全覆盖 + Prompt 组装）
```

## 三、各平台启动与打包

所有命令都在 `app/` 目录下执行。先用 `flutter devices` 查看当前可用设备。

### Android

| 场景 | 命令 |
|------|------|
| 调试启动 | `flutter run -d android`（连接真机需开 USB 调试，或先 `flutter emulators --launch <id>` 起模拟器） |
| 调试 APK | `flutter build apk --debug` |
| 发布 APK（单架构，体积小） | `flutter build apk --release --split-per-abi` |
| 发布 APK（全架构，通用） | `flutter build apk --release` |

- **前置**：Android Studio（SDK + 平台工具）或独立 cmdline-tools；`flutter doctor --android-licenses` 接受许可
- **产物**：`build/app/outputs/flutter-apk/app-release.apk`，可直接分发安装
- 上架 Google Play 需 `flutter build appbundle --release`（AAB 格式，产物在 `build/app/outputs/bundle/release/`）

### iOS

| 场景 | 命令 |
|------|------|
| 调试启动 | `flutter run -d ios`（真机需在 Xcode 中签名，或 `open ios/Runner.xcworkspace` 手动配置） |
| 发布构建 | `flutter build ipa` |

- **前置**：**必须在 macOS 主机上**，安装 Xcode + CocoaPods（`sudo gem install cocoapods`），`flutter doctor` 全绿
- **产物**：`build/ios/ipa/*.ipa`；直接安装真机需 Apple 开发者账号签名，分发走 TestFlight / App Store Connect

### Linux 桌面

| 场景 | 命令 |
|------|------|
| 调试启动 | `flutter run -d linux` |
| 发布构建 | `flutter build linux --release` |

- **前置**：`flutter build linux` 需要的编译链（Ubuntu/Debian）：`sudo apt install cmake ninja-build clang libgtk-3-dev pkg-config`；先跑 `flutter doctor` 确认
- **产物**：`build/linux/x64/release/bundle/` —— 是**一个目录**（含 `linguaflow` 可执行文件 + 动态库 + 数据），分发时整个目录打包（tar.gz），不能只拷单个可执行文件
- 已在本仓库环境验证可编译运行；数据库走 `sqflite_common_ffi`，TTS 在 Linux 无引擎、静默降级

### Windows 桌面

| 场景 | 命令 |
|------|------|
| 调试启动 | `flutter run -d windows` |
| 发布构建 | `flutter build windows --release` |

- **前置**：**必须在 Windows 主机上**（Flutter 桌面不支持交叉编译），安装 Visual Studio 2022（勾选「使用 C++ 的桌面开发」工作负载）+ Flutter SDK
- **产物**：`build\windows\x64\runner\Release\` —— 同样是目录级分发（exe + DLL + data 文件夹），可用 Inno Setup / MSIX 打成安装包
- 平台文件已生成（`windows/`），代码零修改；Linux 主机无法编译 Windows 产物

### Web

| 场景 | 命令 |
|------|------|
| 调试启动 | `flutter run -d chrome` |
| 发布构建 | `flutter build web` |

- **产物**：`build/web/`，任意静态服务器可部署
- ⚠️ **功能降级**：浏览器无原生 SQLite，本地数据库/复习引擎不可用（首页显示降级提示），V2 计划接 `sqflite_common_ffi_web`

### 平台支持总览

| 平台 | 数据库 | TTS | 状态 |
|------|--------|-----|------|
| Android | ✅ sqflite 原生 | ✅ flutter_tts | 就绪 |
| iOS | ✅ sqflite 原生 | ✅ flutter_tts | 就绪（需 Mac 构建） |
| Linux | ✅ sqflite_common_ffi | ❌ 无引擎，静默降级 | 已验证 |
| Windows | ✅ sqflite_common_ffi | ❌ 无引擎，静默降级 | 平台就绪，需 Windows 主机构建 |
| Web | ❌ 降级提示 | ✅ 浏览器 speechSynthesis | 功能降级 |
| macOS | ✅ FFI 路径已就绪 | ⚠️ 待验证 | 平台文件待生成（Mac 上 `flutter create --platforms=macos .`） |

## 四、Flutter 工程结构（`app/lib/`）

```
lib/
├── main.dart                       入口：初始化 SQLite → runApp
├── app.dart                        MaterialApp + 主题 + 路由
├── constants/                      常量层（全部来自文档，禁止魔改数值）
│   ├── app_constants.dart          kLocalUserId / CEFR 顺序 / Session 上限
│   ├── grammar_tags.dart           统一语法标签（grammar.js 的 Dart 移植）
│   ├── levels.dart                 12 级能力等级定义（f3 §五）
│   ├── xp_rules.dart               XP 来源枚举 + 等级阈值 + 每日上限（f3 §二）
│   └── prompt_defaults.dart        16 个 Prompt 变量兜底值
├── data/
│   ├── schema.dart                 统一建表 DDL（v1，汇总 f1/f3/f4/f5）
│   └── storage_service.dart        SQLite 唯一入口（事务/查询/写入）
├── models/
│   └── srs_card.dart               Rating / CardState / SRSCard
├── services/                       服务层（单例，业务与 UI 的唯一桥梁）
│   ├── srs_service.dart            简化 FSRS：calculateNextReview 等（f4）
│   ├── xp_service.dart             awardXP / 等级计算（f3 §四）
│   ├── streak_service.dart         streak + 冻结卡（f3 §六）
│   ├── daily_quest_service.dart    每日任务（f3 §七）
│   ├── session_save_pipeline.dart  统一保存管线 executeSavePipeline（f5）
│   ├── prompt_assembler.dart       Prompt 组装 + 残留占位符检查
│   └── tts/tts_service.dart        统一 TTS 入口（f2 的 Flutter 适配）
└── screens/
    └── home_screen.dart            首页 Dashboard（板块入口/XPBar/任务/角标）
```

后续板块代码放 `lib/boards/<board>/`（vocab / listening / reading / speaking /
writing / review），每板块一个 `saveXxxSession()` 入口 + Prompt 模板文件。

## 五、核心数据闭环

```
首次启动 → 定级(离线10题, f1) → current_level + 初始薄弱点
    ↓
各板块组装 Prompt（16 变量, 兜底值兜底）→ AI 生成 i+1 难度内容
    ↓
练习 → saveSession()（单事务落盘, f5）
    ↓ 级联：XP → SRS 入队 → streak → 每日任务
错误自动晋升 SRS（enrollCard, f4）
    ↓
复习页（简化 FSRS 调度 + 混排, f4）
    ↓
review 结果 → user_grammar_profile 聚合薄弱点
    ↓ 回灌：薄弱点反向影响下轮各板块内容生成（modules-connect §3）
同时 → XP / 12 级 / streak / 每日任务 激励反馈（f3）
```

三条贯穿性主规约：

1. **CEFR 难度锚点只读**：`current_level` 只有定级与重测能写，任何读取处 `'B1'` 兜底
2. **语法标签统一**：所有板块引用 `grammar_tags` 表中的 tag_id，禁止自由文本
3. **闭环不回写**：复习只读取原板块内容，通过 `user_grammar_profile` 间接影响下次生成

## 六、关键设计决策

| 决策 | 说明 |
|------|------|
| **Flutter（替代原 RN 方案）** | 原文档按 React Native + expo-sqlite 编写；本仓库实现为 Flutter。技术映射见下表 |
| **SRS 采用 srs_cards 模型（f4）** | 复习调度以 f4.md 的 `srs_cards` + `srs_reviews` 为准，**替代** modules-connect.md 早期草案中的 `review_queue` + `review_logs`（后者仅为概念稿，不建表）。modules-connect 的「错误晋升规则 / 薄弱点回灌 / 混排比例」业务规则仍然有效，落在 Service 层实现 |
| **级联在事务外执行** | f5 的管线图把 XP/SRS/streak/quests 画在事务内，但 sqflite 不允许嵌套事务；实现为 session 落盘一个事务，级联各自独立写入（与 f4 §4.1 对 XP 的处理一致） |
| **TTS 收敛为 flutter_tts** | f2 的五端 Adapter 矩阵在 Flutter 下收敛为一个 `flutter_tts` 依赖（iOS/Android/Web 三端原生覆盖）；桌面端 V2 再评估 |
| **激励层不做成就系统** | 按 f3：XP + 12 级能力等级，无徽章 / 排行榜 / 虚拟货币 |
| **AI 调度仅做文案** | prompt.md 第六节「AI 当 SRS 调度器」视为废弃，调度一律本地算法（离线原则）；其 insight 文案生成思路可保留 |

**技术映射表（文档 → Flutter 实现）**：

| 原文档（RN 生态） | Flutter 实现 |
|------|------|
| expo-sqlite | sqflite |
| expo-speech | flutter_tts |
| expo-av（录音） | record（待接入，V1 口语板块时） |
| expo-notifications | flutter_local_notifications（待接入） |
| React 组件 / state | Flutter Widget + Riverpod（已引入，ProviderScope 就绪） |
| StorageService.transaction | StorageService.transaction（sqflite `db.transaction`） |

## 七、开发路线（V1 MVP，对应 LinguaFlow.md §四）

- [x] Flutter 工程骨架 + 统一 Schema + StorageService
- [x] SRS 简化 FSRS 引擎（含 16 组合单测）
- [x] XP / Streak / 每日任务服务
- [x] 统一保存管线 executeSavePipeline
- [x] 首页 Dashboard（板块入口 + XPBar + 任务 + 复习角标）
- [ ] 定级模块（f1：自适应 10 题 + 90 题种子库）
- [ ] 词汇板块（闪卡 + FSRS 排程 + TTS 发音）
- [ ] 写作板块（输入 → AI 纠错 → diff）
- [ ] 复习页（4 档 rating + 间隔预览，UI 层）
- [ ] 设置页（词书管理 / 每日目标 / 数据导出）
- [ ] AI 代理后端（Node.js，纠错 + 内容生成）

## 八、贡献规约（给 AI 编程助手 & 人类）

1. 实现前先读对应文档；完成后在 PR/commit 中注明对应文档章节
2. 所有写库走 `StorageService`，所有保存走 `executeSavePipeline`，所有 TTS 走 `TTSService`
3. 常量数值（XP / 阈值 / 步长）只在 `constants/` 定义，业务代码禁止硬编码
4. 每个 Service 公开方法写清对应的文档章节（现有代码即范例）
5. 核心算法（SRS / 定级状态机）必须有单测覆盖全组合后再合入
