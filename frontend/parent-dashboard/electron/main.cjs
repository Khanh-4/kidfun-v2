const { app, BrowserWindow, Menu, Tray, ipcMain, Notification, nativeImage, dialog } = require('electron');
const path = require('path');
const fs = require('fs');

const isDev = !app.isPackaged;

// Đọc cấu hình từ file config hoặc environment
function loadConfig() {
  const defaults = { apiUrl: 'http://localhost:3001', devPort: 5173 };
  if (process.env.API_URL) {
    defaults.apiUrl = process.env.API_URL;
  }
  const configPath = isDev
    ? path.join(__dirname, '..', 'electron-config.json')
    : path.join(path.dirname(app.getPath('exe')), 'config.json');
  try {
    if (fs.existsSync(configPath)) {
      const config = JSON.parse(fs.readFileSync(configPath, 'utf-8'));
      if (config.apiUrl) defaults.apiUrl = config.apiUrl;
      if (config.devPort) defaults.devPort = config.devPort;
    }
  } catch (err) {
    console.warn('Could not read config file:', err.message);
  }
  return defaults;
}

const config = loadConfig();

let mainWindow = null;
let tray = null;

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 1280,
    height: 800,
    minWidth: 900,
    minHeight: 600,
    webPreferences: {
      preload: path.join(__dirname, 'preload.cjs'),
      contextIsolation: true,
      nodeIntegration: false,
    },
  });

  if (isDev) {
    mainWindow.loadURL(`http://localhost:${config.devPort}`);
    mainWindow.webContents.openDevTools();
  } else {
    mainWindow.loadFile(path.join(__dirname, '../dist/index.html'));
  }

  mainWindow.on('close', (e) => {
    if (!app.isQuitting) {
      e.preventDefault();
      mainWindow.hide();
    }
  });
}

function createMenu() {
  const template = [
    {
      label: 'File',
      submenu: [
        {
          label: 'Quit',
          accelerator: 'CmdOrCtrl+Q',
          click: () => {
            app.isQuitting = true;
            app.quit();
          },
        },
      ],
    },
    {
      label: 'View',
      submenu: [
        {
          label: 'Reload',
          accelerator: 'CmdOrCtrl+R',
          click: () => {
            if (mainWindow) mainWindow.reload();
          },
        },
        {
          label: 'Toggle DevTools',
          accelerator: 'F12',
          click: () => {
            if (mainWindow) mainWindow.webContents.toggleDevTools();
          },
        },
      ],
    },
    {
      label: 'Help',
      submenu: [
        {
          label: 'About KidFun Parent',
          click: () => {
            dialog.showMessageBox(mainWindow, {
              type: 'info',
              title: 'About KidFun Parent',
              message: 'KidFun Parent Dashboard',
              detail: `Version: ${app.getVersion()}\nSmart Parental Control System\nNhom 60 - HUTECH`,
            });
          },
        },
      ],
    },
  ];

  const menu = Menu.buildFromTemplate(template);
  Menu.setApplicationMenu(menu);
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
  tray.setToolTip('KidFun Parent');

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

// IPC: Show native notification
ipcMain.on('show-notification', (event, { title, body }) => {
  if (Notification.isSupported()) {
    const notification = new Notification({
      title: title || 'KidFun Parent',
      body: body || '',
      icon: isDev
        ? path.join(__dirname, '..', 'public', 'tray-icon.png')
        : path.join(__dirname, '..', 'dist', 'tray-icon.png'),
    });

    notification.on('click', () => {
      if (mainWindow) {
        mainWindow.show();
        mainWindow.focus();
      }
    });

    notification.show();
  }
});

app.whenReady().then(() => {
  createWindow();
  createMenu();
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
