const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('petBird', {
  onShowAsset: (callback) => ipcRenderer.on('show-asset', (_event, asset) => callback(asset)),
  openContextMenu: () => ipcRenderer.invoke('open-context-menu')
});
