import { useState, useEffect } from 'react';
import { Outlet } from 'react-router-dom';
import { Box, Toolbar, Snackbar, Alert } from '@mui/material';
import Sidebar from './Sidebar';
import socketService from '../../services/socketService';
import authService from '../../services/authService';

const drawerWidth = 260;

function MainLayout() {
  const [mobileOpen, setMobileOpen] = useState(false);
  const [requests, setRequests] = useState([]);
  const [snackbar, setSnackbar] = useState({ open: false, message: '', severity: 'info' });

  const user = authService.getCurrentUser();
  const unreadCount = requests.filter((r) => !r.status).length;

  const handleDrawerToggle = () => {
    setMobileOpen(!mobileOpen);
  };

  // Connect socket once at layout level
  useEffect(() => {
    if (!user?.id) return;

    socketService.connect(user.id);

    socketService.onTimeExtensionRequest((data) => {
      setRequests((prev) => [data, ...prev]);
      setSnackbar({
        open: true,
        message: `${data.deviceName} xin thêm thời gian!`,
        severity: 'info',
      });
    });

    return () => {
      socketService.disconnect();
    };
  }, [user?.id]);

  return (
    <Box sx={{ display: 'flex', minHeight: '100vh', bgcolor: 'background.default' }}>
      {/* Sidebar */}
      <Sidebar
        drawerWidth={drawerWidth}
        mobileOpen={mobileOpen}
        handleDrawerToggle={handleDrawerToggle}
        unreadCount={unreadCount}
      />

      {/* Main content */}
      <Box
        component="main"
        sx={{
          flexGrow: 1,
          p: 3,
          width: { sm: `calc(100% - ${drawerWidth}px)` },
          ml: { sm: `${drawerWidth}px` },
        }}
      >
        <Toolbar />
        <Outlet context={{ requests, setRequests }} />
      </Box>

      {/* Global notification snackbar */}
      <Snackbar
        open={snackbar.open}
        autoHideDuration={5000}
        onClose={() => setSnackbar((prev) => ({ ...prev, open: false }))}
        anchorOrigin={{ vertical: 'top', horizontal: 'right' }}
      >
        <Alert
          severity={snackbar.severity}
          onClose={() => setSnackbar((prev) => ({ ...prev, open: false }))}
        >
          {snackbar.message}
        </Alert>
      </Snackbar>
    </Box>
  );
}

export default MainLayout;
