const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('electronAPI', {
  platform: process.platform,

  // Lock screen controls
  lockScreen: () => {
    ipcRenderer.send('lock-screen');
  },
  unlockScreen: () => {
    ipcRenderer.send('unlock-screen');
  },

  // Blocked sites management
  updateBlockedSites: (sites) => {
    return ipcRenderer.invoke('update-blocked-sites', sites);
  },

  // Listen for lock screen's "request more time" button
  onLockRequestMoreTime: (callback) => {
    ipcRenderer.on('lock-request-more-time', () => callback());
  },

  // Listen for emergency unlock (Ctrl+Shift+Alt+Q)
  onEmergencyUnlock: (callback) => {
    ipcRenderer.on('emergency-unlock', () => callback());
  },
});
