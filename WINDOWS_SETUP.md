# Windows 安装与验收说明

目标：在 Windows 上安装当前仓库版本的中大鸟桌宠，保留内置素材和已有功能。Windows 使用 Electron 实现；macOS 原生版使用 Swift/AppKit，系统菜单、屏幕缩放和窗口表现需要在 Windows 上实际核对。

## 给 Windows 本地 Agent 的任务

克隆本仓库，阅读本文件及 README.md，按以下步骤安装依赖、生成 Windows 应用并启动验证。记录实际使用的 Git commit、应用路径和验证结果。沿用仓库现有实现，不重新设计，不替换素材。安装成功不能代替运行验证；遇到 Windows 特有问题时明确报告，并针对该问题修复。

## 方式一：下载已打包的应用

1. 打开 https://github.com/uinue2010/sysu-pet-bird/actions 。
2. 选择对应当前提交、成功完成的 `Build desktop apps`。
3. 下载 `sysu-pet-bird-windows` artifact（可能需要登录 GitHub）。
4. 解压，选择 portable `.exe` 直接运行，或者使用安装程序安装。打包应用自带运行时和素材，不需要另外安装 Node.js。

如果 artifact 已过期、不可下载或构建失败，使用方式二。

## 方式二：从源码安装和打包

需要 Git 和 Node.js 20（与仓库构建流程一致）。在 Windows 本机 PowerShell 中操作；桌面应用应运行在 Windows 桌面会话中。

```powershell
git clone https://github.com/uinue2010/sysu-pet-bird.git
cd sysu-pet-bird
git rev-parse HEAD
node --version
npm --version
npm ci
npm start
```

如果已经克隆，先检查是否存在本地修改，再更新到目标提交；不要覆盖本地修改。依赖使用已提交的 `package-lock.json` 和 `npm ci`，不主动升级 Electron 或重新生成锁文件。

启动验证后退出应用，再生成 Windows 安装程序和 portable 应用：

```powershell
npm run dist:win
Get-ChildItem dist -Filter *.exe
```

生成的 `.exe` 在 `dist` 目录。运行打包后的应用，再确认素材显示和菜单操作正常。保留用户选择的运行入口，避免源码版和打包版同时运行造成两只鸟。开机自启目前不是项目内置功能，如有需要应另行配置。

## 当前功能和验收

- 透明桌宠显示，图片和 GIF 动画可见，可拖动位置。
- 托盘菜单和右键菜单可用，能手动选择表情。
- 大小：72、96、120、149；透明度：40%、70%、100%；可切换置顶。
- 可暂停和恢复自动切换。
- 按 Windows 本机时间：21:30 至次日 07:30（含 07:30 所在分钟）显示“晚安”；11:30–12:30、17:00–18:00（含结束时间所在分钟）显示“饿了”。
- 其他时段约每 2 分钟从表情池随机切换，避开“饿了”和“晚安”；一轮内尽量不重复，避免连续同一表情。规则每 15 秒检查一次。
- 内置 `Assets/ZhongDaBird` 的 19 个素材文件；部分是同名不同格式，菜单去重后不一定有 19 项。部分 `.jpeg` 的实际内容是 GIF，应核对动画，不要按扩展名重新转换。

时间规则可以检查源码，无需为了验收修改电脑系统时间。至少实际检查启动、拖动、动画、菜单、大小、透明度、置顶和暂停/恢复；打包后再检查启动和素材加载。无法验证的项目应明确标记。

## 与 Mac 当前使用方式的边界

主要素材、尺寸选项和时间规则保持对应。macOS 菜单栏入口在 Windows 上对应托盘入口。Mac 原生版可以扫描 `~/Documents/中大鸟`；Windows 版使用仓库内置素材，不扫描该 Mac 路径。窗口位置、当前表情、大小等运行中的临时状态不会随 GitHub 克隆迁移，首次启动后可通过菜单调整。不同显示器缩放可能影响肉眼看到的大小，最终效果以 Windows 实机验收为准。
