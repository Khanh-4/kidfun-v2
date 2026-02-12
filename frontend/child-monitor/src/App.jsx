import { useState, useEffect } from 'react';
import { ThemeProvider, createTheme } from '@mui/material/styles';
import CssBaseline from '@mui/material/CssBaseline';
import LinkDevice from './pages/LinkDevice';
import ChildDashboard from './pages/ChildDashboard';

// Theme cho trẻ em - màu sắc vui tươi
const theme = createTheme({
  palette: {
    primary: {
      main: '#6366f1',
      light: '#818cf8',
      dark: '#4f46e5',
    },
    secondary: {
      main: '#f472b6',
    },
    success: {
      main: '#22c55e',
    },
    warning: {
      main: '#f59e0b',
    },
    error: {
      main: '#ef4444',
    },
  },
  typography: {
    fontFamily: '"Nunito", "Roboto", sans-serif',
  },
  shape: {
    borderRadius: 16,
  },
  components: {
    MuiButton: {
      styleOverrides: {
        root: {
          textTransform: 'none',
          fontWeight: 600,
        },
      },
    },
  },
});

function App() {
  const [device, setDevice] = useState(null);
  const [isLinked, setIsLinked] = useState(false);

  useEffect(() => {
    // Kiểm tra xem đã liên kết thiết bị chưa
    const savedDevice = localStorage.getItem('device');
    if (savedDevice) {
      setDevice(JSON.parse(savedDevice));
      setIsLinked(true);
    }
  }, []);

  const handleLinked = (deviceData) => {
    setDevice(deviceData);
    setIsLinked(true);
  };

  return (
    <ThemeProvider theme={theme}>
      <CssBaseline />
      {isLinked ? (
        <ChildDashboard device={device} />
      ) : (
        <LinkDevice onLinked={handleLinked} />
      )}
    </ThemeProvider>
  );
}

export default App;