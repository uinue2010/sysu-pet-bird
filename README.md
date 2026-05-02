# sysu-pet-bird

中大鸟桌面宠物。仓库里自带 `Assets/ZhongDaBird` 表情素材，下载后不需要再手动导入素材。

## 给朋友使用

最省事的方式是下载 GitHub 自动构建好的包：

1. 打开仓库页面的 **Actions**。
2. 点最新一次 **Build desktop apps**。
3. 在页面底部 **Artifacts** 下载：
   - Windows：`sysu-pet-bird-windows`
   - macOS：`sysu-pet-bird-mac`
4. 解压后运行里面的应用。

如果只是下载源码，点绿色 **Code** 按钮，再点 **Download ZIP**。这个 ZIP 也包含全部表情素材。

## 跨平台版本

Electron 版本支持 Windows 和 macOS：

```bash
npm install
npm start
```

打包：

```bash
npm run dist:win
npm run dist:mac
```

功能：

- 透明悬浮桌宠窗口
- 托盘菜单和右键菜单
- 手动切换表情
- 暂停/恢复自动切换
- 调整大小、透明度、置顶
- 内置 19 个中大鸟素材
- 自动规则：
  - 11:30-12:30 和 17:00-18:00 优先切换到“饿了”
  - 21:30 之后优先切换到“晚安”
  - 其他时间约每 2 分钟随机切换一个表情
  - 随机时会避开“饿了/晚安”，并尽量避免连续抽到当前同一个表情

## macOS 原生版本

仓库也保留了 Swift/AppKit 原生 macOS 版本：

```bash
swift run ZhongDaBirdPet
```

生成 `.app`：

```bash
bash Scripts/build_app.sh
open ".build/中大鸟桌宠.app"
```

原生版本默认优先扫描本机素材目录：

```text
~/Documents/中大鸟
```

打包成 `.app` 时，项目里的 `Assets/ZhongDaBird` 也会一起放进应用包。这样即使本机没有 `~/Documents/中大鸟`，应用也能使用内置素材。

## 素材说明

当前内置 19 个图片文件。多个 `.jpeg` 的真实格式是 GIF，包括“沉迷科研 / 晚安 / 听音乐 / 开心 / 学习ing / 比心 / 撒花 / 加油 / 疑惑 / 饿了 / 锦鲤附体”等。macOS 原生版本会用 ImageIO 识别真实格式；Electron 版本由 Chromium 按文件内容解码。
