const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('lockAPI', {
  requestMoreTime: () => {
    ipcRenderer.send('lock-request-more-time');
  },
  onUnlock: (callback) => {
    ipcRenderer.on('unlock-screen', () => callback());
  },
});
