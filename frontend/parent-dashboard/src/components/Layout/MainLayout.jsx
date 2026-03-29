import { useState, useEffect } from 'react';
import { Outlet } from 'react-router-dom';
import { Box, Toolbar, Snackbar, Alert } from '@mui/material';
import { useTranslation } from 'react-i18next';
import Sidebar from './Sidebar';
import socketService from '../../services/socketService';
import authService from '../../services/authService';
import api from '../../services/api';

const drawerWidth = 260;

function MainLayout() {
  const [mobileOpen, setMobileOpen] = useState(false);
  const [requests, setRequests] = useState([]);
  const [snackbar, setSnackbar] = useState({ open: false, message: '', severity: 'info' });

  const { t } = useTranslation();
  const user = authService.getCurrentUser();
  const unreadCount = requests.filter((r) => !r.status).length;

  const handleDrawerToggle = () => {
    setMobileOpen(!mobileOpen);
  };

  // Normalize socket timeExtensionRequest data to match UI expectations
  const normalizeRequest = (data) => ({
    id: data.requestId,
    profileId: data.profileId,
    profileName: data.profileName,
    deviceName: data.deviceName,
    requestMinutes: data.requestMinutes,
    reason: data.reason || '',
    createdAt: data.createdAt,
    status: null, // pending
  });

  // Fetch pending extension requests from REST API on mount
  useEffect(() => {
    const fetchPending = async () => {
      try {
        const response = await api.get('/extension-requests/pending');
        const pending = (response.data.requests || []).map((req) => ({
          id: req.id,
          profileId: req.profileId,
          profileName: req.profile?.profileName || '',
          deviceName: req.device?.deviceName || '',
          requestMinutes: req.requestMinutes,
          reason: req.reason || '',
          createdAt: req.createdAt,
          status: null, // pending
        }));
        setRequests(pending);
      } catch (err) {
        console.error('Failed to fetch pending requests:', err);
      }
    };

    if (user?.id) {
      fetchPending();
    }
  }, [user?.id]);

  // Connect socket once at layout level
  useEffect(() => {
    if (!user?.id) return;

    socketService.connect(user.id);

    socketService.onTimeExtensionRequest((data) => {
      const normalized = normalizeRequest(data);
      setRequests((prev) => {
        // Avoid duplicates (REST fetch + socket push on joinFamily)
        if (prev.some((r) => r.id === normalized.id)) return prev;
        return [normalized, ...prev];
      });
      setSnackbar({
        open: true,
        message: t('common.timeExtensionRequest', { device: data.deviceName }),
        severity: 'info',
      });
    });

    socketService.onSoftWarning((data) => {
      setSnackbar({
        open: true,
        message: `${data.profileName}: ${data.message}`,
        severity: 'warning',
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
