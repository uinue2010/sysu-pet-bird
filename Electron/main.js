const { app, BrowserWindow, Menu, Tray, ipcMain, nativeImage } = require('electron');
const fs = require('fs');
const path = require('path');
const { pathToFileURL } = require('url');

const WINDOW_SIDE = 96;
const RULE_CHECK_INTERVAL_MS = 15 * 1000;
const RANDOM_INTERVAL_MS = 2 * 60 * 1000;
const ASSET_EXTENSIONS = new Set(['.gif', '.png', '.jpg', '.jpeg', '.webp', '']);
const SPECIAL_RANDOM_NAMES = ['饿了', '晚安'];

let mainWindow;
let tray;
let assets = [];
let autoSwitchEnabled = true;
let lastFixedRule = null;
let lastRandomSwitchAt = 0;
let randomQueue = [];

function assetDirectory() {
  if (app.isPackaged) {
    return path.join(process.resourcesPath, 'Assets', 'ZhongDaBird');
  }
  return path.join(__dirname, '..', 'Assets', 'ZhongDaBird');
}

function normalizedDisplayName(name) {
  return name.replace(/_png序列/g, '').trim();
}

function assetRank(asset) {
  if (asset.extension === '.gif') return 0;
  if (asset.extension === '.png') return 1;
  if (asset.extension === '.webp') return 2;
  return 3;
}

function scanAssets() {
  const directory = assetDirectory();
  if (!fs.existsSync(directory)) return [];

  const chosen = new Map();
  for (const fileName of fs.readdirSync(directory)) {
    const filePath = path.join(directory, fileName);
    if (!fs.statSync(filePath).isFile()) continue;

    const extension = path.extname(fileName).toLowerCase();
    if (!ASSET_EXTENSIONS.has(extension)) continue;

    const rawName = path.basename(fileName, extension);
    const displayName = normalizedDisplayName(rawName);
    const asset = {
      displayName,
      rawName,
      extension,
      filePath,
      url: pathToFileURL(filePath).toString()
    };

    const current = chosen.get(displayName);
    if (!current || assetRank(asset) < assetRank(current)) {
      chosen.set(displayName, asset);
    }
  }

  return [...chosen.values()].sort((a, b) => a.displayName.localeCompare(b.displayName, 'zh-Hans-CN'));
}

function createWindow() {
  mainWindow = new BrowserWindow({
    width: WINDOW_SIDE,
    height: WINDOW_SIDE,
    frame: false,
    transparent: true,
    resizable: false,
    alwaysOnTop: true,
    hasShadow: false,
    skipTaskbar: true,
    webPreferences: {
      preload: path.join(__dirname, 'preload.js')
    }
  });

  mainWindow.setMenuBarVisibility(false);
  mainWindow.loadFile(path.join(__dirname, 'renderer.html'));
  mainWindow.webContents.once('did-finish-load', () => {
    rescanAssets();
    applyAutomaticRule(true);
  });
}

function createTray() {
  const iconAsset = assets.find((asset) => asset.extension === '.png') || assets[0];
  const icon = iconAsset ? nativeImage.createFromPath(iconAsset.filePath).resize({ width: 18, height: 18 }) : nativeImage.createEmpty();
  tray = new Tray(icon);
  tray.setToolTip('中大鸟桌宠');
  tray.setContextMenu(buildMenu());
}

function buildMenu() {
  const expressionItems = assets.map((asset) => ({
    label: asset.displayName,
    click: () => showAsset(asset)
  }));

  return Menu.buildFromTemplate([
    { label: `当前：${currentAssetName()}`, enabled: false },
    { label: '切换表情', submenu: expressionItems.length ? expressionItems : [{ label: '未找到素材', enabled: false }] },
    { type: 'separator' },
    {
      label: autoSwitchEnabled ? '暂停自动切换' : '恢复自动切换',
      click: () => {
        autoSwitchEnabled = !autoSwitchEnabled;
        refreshMenus();
      }
    },
    {
      label: '重新扫描素材',
      click: () => {
        rescanAssets();
        applyAutomaticRule(true);
      }
    },
    {
      label: mainWindow?.isAlwaysOnTop() ? '取消置顶' : '置顶显示',
      click: () => {
        mainWindow.setAlwaysOnTop(!mainWindow.isAlwaysOnTop());
        refreshMenus();
      }
    },
    {
      label: '大小',
      submenu: [
        { label: '小', click: () => resizePet(72) },
        { label: '标准', click: () => resizePet(96) },
        { label: '大', click: () => resizePet(120) },
        { label: '特大', click: () => resizePet(149) }
      ]
    },
    {
      label: '透明度',
      submenu: [
        { label: '40%', click: () => mainWindow.setOpacity(0.4) },
        { label: '70%', click: () => mainWindow.setOpacity(0.7) },
        { label: '100%', click: () => mainWindow.setOpacity(1.0) }
      ]
    },
    { type: 'separator' },
    { label: '退出', click: () => app.quit() }
  ]);
}

function refreshMenus() {
  const menu = buildMenu();
  tray?.setContextMenu(menu);
  mainWindow?.webContents.send('menu-updated');
}

function rescanAssets() {
  assets = scanAssets();
  randomQueue = [];
  if (!tray) createTray();
  refreshMenus();
}

function currentAssetName() {
  return mainWindow?.currentAsset?.displayName || '未加载';
}

function showAsset(asset) {
  if (!asset || !mainWindow) return;
  mainWindow.currentAsset = asset;
  randomQueue = randomQueue.filter((queuedAsset) => queuedAsset.filePath !== asset.filePath);
  mainWindow.webContents.send('show-asset', asset);
  refreshMenus();
}

function resizePet(side) {
  const bounds = mainWindow.getBounds();
  mainWindow.setBounds({ x: bounds.x, y: bounds.y, width: side, height: side });
}

function minutesAfterMidnight(date) {
  return date.getHours() * 60 + date.getMinutes();
}

function pickByNames(names) {
  for (const name of names) {
    const exact = assets.find((asset) => asset.displayName === name);
    if (exact) return exact;
    const fuzzy = assets.find((asset) => asset.displayName.includes(name));
    if (fuzzy) return fuzzy;
  }
  return null;
}

function randomAsset() {
  const currentPath = mainWindow?.currentAsset?.filePath;
  const candidates = assets.filter((asset) => !SPECIAL_RANDOM_NAMES.some((name) => asset.displayName.includes(name)));
  const pool = candidates.length ? candidates : assets;
  const poolPaths = new Set(pool.map((asset) => asset.filePath));
  randomQueue = randomQueue.filter((asset) => poolPaths.has(asset.filePath));

  if (randomQueue.length === 0) {
    randomQueue = shuffle(pool);
  }

  if (randomQueue[0]?.filePath === currentPath && randomQueue.length > 1) {
    randomQueue.push(randomQueue.shift());
  }

  return randomQueue.shift();
}

function shuffle(items) {
  const shuffled = [...items];
  for (let index = shuffled.length - 1; index > 0; index -= 1) {
    const swapIndex = Math.floor(Math.random() * (index + 1));
    [shuffled[index], shuffled[swapIndex]] = [shuffled[swapIndex], shuffled[index]];
  }
  return shuffled;
}

function showFixedMood(ruleKey, names, forceRefresh) {
  if (!forceRefresh && lastFixedRule === ruleKey) return;
  lastFixedRule = ruleKey;
  showAsset(pickByNames(names) || randomAsset());
}

function applyAutomaticRule(forceRefresh = false) {
  if (!autoSwitchEnabled || assets.length === 0) return;

  const minutes = minutesAfterMidnight(new Date());
  if (minutes >= 21 * 60 + 30) {
    showFixedMood('night', ['晚安'], forceRefresh);
  } else if ((minutes >= 11 * 60 + 30 && minutes <= 12 * 60 + 30) || (minutes >= 17 * 60 && minutes <= 18 * 60)) {
    showFixedMood('hungry', ['饿了'], forceRefresh);
  } else {
    const now = Date.now();
    if (!forceRefresh && now - lastRandomSwitchAt < RANDOM_INTERVAL_MS) return;
    lastFixedRule = 'random';
    lastRandomSwitchAt = now;
    showAsset(randomAsset());
  }
}

ipcMain.handle('open-context-menu', () => {
  buildMenu().popup({ window: mainWindow });
});

app.whenReady().then(() => {
  createWindow();
  setInterval(() => applyAutomaticRule(false), RULE_CHECK_INTERVAL_MS);
});

app.on('window-all-closed', (event) => {
  event.preventDefault();
});
