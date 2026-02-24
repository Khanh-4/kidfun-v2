const { app, BrowserWindow, Tray, Menu, ipcMain, globalShortcut, nativeImage } = require('electron');
const path = require('path');
const hostsManager = require('./hostsManager.cjs');

const isDev = !app.isPackaged;

let mainWindow = null;
let lockWindow = null;
let tray = null;

// Auto-start on login
app.setLoginItemSettings({
  openAtLogin: true,
  args: ['--hidden'],
});

function createWindow() {
  const startHidden = process.argv.includes('--hidden');

  mainWindow = new BrowserWindow({
    width: 500,
    height: 700,
    minWidth: 400,
    minHeight: 600,
    show: !startHidden,
    webPreferences: {
      preload: path.join(__dirname, 'preload.cjs'),
      contextIsolation: true,
      nodeIntegration: false,
    },
  });

  if (isDev) {
    mainWindow.loadURL('http://localhost:5174');
    mainWindow.webContents.openDevTools();
  } else {
    mainWindow.loadFile(path.join(__dirname, '../dist/index.html'));
  }

  // Minimize to tray instead of closing
  mainWindow.on('close', (e) => {
    if (!app.isQuitting) {
      e.preventDefault();
      mainWindow.hide();
    }
  });
}

function createTray() {
  const iconPath = isDev
    ? path.join(__dirname, '..', 'public', 'tray-icon.png')
    : path.join(__dirname, '..', 'dist', 'tray-icon.png');

  let trayIcon;
  try {
    trayIcon = nativeImage.createFromPath(iconPath);
    if (trayIcon.isEmpty()) {
      trayIcon = nativeImage.createEmpty();
    }
  } catch {
    trayIcon = nativeImage.createEmpty();
  }

  tray = new Tray(trayIcon);
  tray.setToolTip('KidFun Child');

  const contextMenu = Menu.buildFromTemplate([
    {
      label: 'Show',
      click: () => {
        if (mainWindow) {
          mainWindow.show();
          mainWindow.focus();
        }
      },
    },
    {
      label: 'Hide',
      click: () => {
        if (mainWindow) {
          mainWindow.hide();
        }
      },
    },
    { type: 'separator' },
    {
      label: 'Quit',
      click: () => {
        app.isQuitting = true;
        app.quit();
      },
    },
  ]);

  tray.setContextMenu(contextMenu);

  tray.on('double-click', () => {
    if (mainWindow) {
      mainWindow.show();
      mainWindow.focus();
    }
  });
}

// Lock screen — fullscreen kiosk mode
function createLockScreen() {
  if (lockWindow) return;

  lockWindow = new BrowserWindow({
    fullscreen: true,
    alwaysOnTop: true,
    frame: false,
    kiosk: true,
    skipTaskbar: true,
    closable: false,
    minimizable: false,
    resizable: false,
    movable: false,
    webPreferences: {
      preload: path.join(__dirname, 'lockPreload.cjs'),
      contextIsolation: true,
      nodeIntegration: false,
    },
  });

  lockWindow.loadFile(path.join(__dirname, 'lockScreen.html'));

  // Block keyboard shortcuts to prevent escape
  lockWindow.on('focus', () => {
    globalShortcut.register('Alt+F4', () => {});
    globalShortcut.register('Alt+Tab', () => {});
    globalShortcut.register('CommandOrControl+W', () => {});
    globalShortcut.register('CommandOrControl+Q', () => {});
    globalShortcut.register('Super', () => {});
  });

  lockWindow.on('blur', () => {
    // Re-focus lock window if it loses focus
    if (lockWindow && !lockWindow.isDestroyed()) {
      lockWindow.focus();
    }
  });

  lockWindow.on('closed', () => {
    lockWindow = null;
    globalShortcut.unregisterAll();
  });

  // Prevent closing via system commands
  lockWindow.on('close', (e) => {
    e.preventDefault();
  });
}

function destroyLockScreen() {
  if (lockWindow && !lockWindow.isDestroyed()) {
    // Notify lock screen before closing
    lockWindow.webContents.send('unlock-screen');

    // Unregister shortcuts
    globalShortcut.unregisterAll();

    // Remove close prevention and destroy
    lockWindow.removeAllListeners('close');
    lockWindow.destroy();
    lockWindow = null;
  }
}

// IPC Handlers
ipcMain.on('lock-screen', () => {
  createLockScreen();
});

ipcMain.on('unlock-screen', () => {
  destroyLockScreen();
});

ipcMain.handle('update-blocked-sites', async (event, sites) => {
  try {
    const success = hostsManager.updateBlockedSites(sites);
    return { success };
  } catch (err) {
    console.error('Failed to update blocked sites:', err);
    return { success: false, error: err.message };
  }
});

// Lock screen requests more time → forward to main window (renderer handles socket)
ipcMain.on('lock-request-more-time', () => {
  if (mainWindow && !mainWindow.isDestroyed()) {
    mainWindow.webContents.send('lock-request-more-time');
  }
});

// Cleanup on quit
app.on('before-quit', () => {
  hostsManager.removeAllBlocks();
  globalShortcut.unregisterAll();
});

app.whenReady().then(() => {
  createWindow();
  createTray();
});

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') {
    app.quit();
  }
});

app.on('activate', () => {
  if (mainWindow) {
    mainWindow.show();
  }
});
