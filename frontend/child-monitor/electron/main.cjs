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
let lockFocusInterval = null;

function registerLockShortcuts() {
  // Block common escape shortcuts
  // Note: 'Super' alone is NOT a valid Electron accelerator — use Meta+key combos
  const shortcuts = [
    'Alt+F4',
    'Alt+Tab',
    'Alt+Escape',
    'CommandOrControl+W',
    'CommandOrControl+Q',
    'CommandOrControl+Escape',
    'Meta+D',      // Show desktop (Windows)
    'Meta+E',      // Explorer (Windows)
    'Meta+R',      // Run dialog (Windows)
    'Meta+Tab',    // Task view (Windows)
    'F11',         // Toggle fullscreen
    'Alt+Space',   // Window menu
  ];

  for (const key of shortcuts) {
    try {
      globalShortcut.register(key, () => {
        // Ensure lock window stays focused
        if (lockWindow && !lockWindow.isDestroyed()) {
          lockWindow.focus();
        }
      });
    } catch (err) {
      console.warn(`Could not register shortcut ${key}:`, err.message);
    }
  }
}

function createLockScreen() {
  if (lockWindow) return;

  lockWindow = new BrowserWindow({
    fullscreen: true,
    alwaysOnTop: true,
    frame: false,
    skipTaskbar: true,
    closable: false,
    minimizable: false,
    maximizable: false,
    resizable: false,
    movable: false,
    focusable: true,
    kiosk: true,
    webPreferences: {
      preload: path.join(__dirname, 'lockPreload.cjs'),
      contextIsolation: true,
      nodeIntegration: false,
    },
  });

  // Highest z-order level so it stays above taskbar and other windows
  lockWindow.setAlwaysOnTop(true, 'screen-saver');

  lockWindow.loadFile(path.join(__dirname, 'lockScreen.html'));

  // Register shortcuts once after window is created
  registerLockShortcuts();

  lockWindow.on('blur', () => {
    // Re-focus lock window if it loses focus
    if (lockWindow && !lockWindow.isDestroyed()) {
      lockWindow.focus();
    }
  });

  // Periodically re-focus and re-assert always-on-top to defeat OS task switching
  lockFocusInterval = setInterval(() => {
    if (lockWindow && !lockWindow.isDestroyed()) {
      lockWindow.setAlwaysOnTop(true, 'screen-saver');
      lockWindow.focus();
    } else {
      clearInterval(lockFocusInterval);
      lockFocusInterval = null;
    }
  }, 500);

  lockWindow.on('closed', () => {
    lockWindow = null;
    globalShortcut.unregisterAll();
    if (lockFocusInterval) {
      clearInterval(lockFocusInterval);
      lockFocusInterval = null;
    }
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

    // Clear focus interval
    if (lockFocusInterval) {
      clearInterval(lockFocusInterval);
      lockFocusInterval = null;
    }

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
