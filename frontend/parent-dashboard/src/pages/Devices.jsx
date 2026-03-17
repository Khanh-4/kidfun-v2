import { useState, useEffect } from 'react';
import {
  Box,
  Grid,
  Card,
  CardContent,
  Typography,
  Button,
  Chip,
  Avatar,
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  TextField,
  Alert,
  IconButton,
  Menu,
  MenuItem,
  ListItemIcon,
  Snackbar,
} from '@mui/material';
import {
  Add as AddIcon,
  Computer as ComputerIcon,
  Smartphone as SmartphoneIcon,
  Tablet as TabletIcon,
  Wifi as WifiIcon,
  WifiOff as WifiOffIcon,
  MoreVert as MoreVertIcon,
  Delete as DeleteIcon,
  Person as PersonIcon,
} from '@mui/icons-material';
import { useTranslation } from 'react-i18next';
import api from '../services/api';
import socketService from '../services/socketService';
import authService from '../services/authService';

function Devices() {
  const { t } = useTranslation();
  const [devices, setDevices] = useState([]);
  const [profiles, setProfiles] = useState([]);
  const [loading, setLoading] = useState(true);
  const [openDialog, setOpenDialog] = useState(false);
  const [openProfileDialog, setOpenProfileDialog] = useState(false);
  const [selectedProfileId, setSelectedProfileId] = useState('');
  const [pairingProfileId, setPairingProfileId] = useState('');
  const [error, setError] = useState('');
  const [pairingCode, setPairingCode] = useState(null);
  const [generatingCode, setGeneratingCode] = useState(false);
  const [anchorEl, setAnchorEl] = useState(null);
  const [selectedDevice, setSelectedDevice] = useState(null);
  const [deviceForProfile, setDeviceForProfile] = useState(null);
  const [snackbar, setSnackbar] = useState({ open: false, message: '', severity: 'success' });

  const user = authService.getCurrentUser();

  useEffect(() => {
    socketService.connect(user?.id);
  }, [user?.id]);

  useEffect(() => {
    loadDevices();
    loadProfiles();
  }, []);

  const loadDevices = async () => {
    try {
      const response = await api.get('/devices');
      // Lọc bỏ device đang chờ ghép nối (pending)
      const linkedDevices = (response.data || []).filter(
        (d) => d.deviceName !== 'Pending Device'
      );
      setDevices(linkedDevices);
    } catch (error) {
      console.error('Error loading devices:', error);
    } finally {
      setLoading(false);
    }
  };

  const loadProfiles = async () => {
    try {
      const response = await api.get('/profiles');
      setProfiles(response.data);
    } catch (error) {
      console.error('Error loading profiles:', error);
    }
  };

  const handleOpenDialog = () => {
    setPairingProfileId('');
    setError('');
    setPairingCode(null);
    setOpenDialog(true);
  };

  const handleCloseDialog = () => {
    setOpenDialog(false);
    setPairingCode(null);
    if (pairingCode) loadDevices();
  };

  const handleGeneratePairingCode = async () => {
    if (!pairingProfileId) {
      setError(t('devices.selectProfileFirst') || 'Vui lòng chọn hồ sơ con');
      return;
    }

    setGeneratingCode(true);
    setError('');
    try {
      const response = await api.post('/devices/generate-pairing-code', {
        profileId: parseInt(pairingProfileId),
      });
      setPairingCode(response.data.pairingCode);
    } catch (error) {
      setError(error.response?.data?.message || t('common.error'));
    } finally {
      setGeneratingCode(false);
    }
  };

  const handleMenuOpen = (event, device) => {
    setAnchorEl(event.currentTarget);
    setSelectedDevice(device);
  };

  const handleMenuClose = () => {
    setAnchorEl(null);
    setSelectedDevice(null);
  };

  const handleDeleteDevice = async () => {
    if (!selectedDevice) return;

    try {
      await api.delete(`/devices/${selectedDevice.id}`);
      socketService.removeDevice(user?.id, selectedDevice.id, selectedDevice.deviceCode);
      handleMenuClose();
      loadDevices();
    } catch (error) {
      console.error('Error deleting device:', error);
    }
  };

  const handleOpenProfileDialog = () => {
    setDeviceForProfile(selectedDevice);
    setSelectedProfileId(selectedDevice?.profileId?.toString() || '');
    setError('');
    setOpenProfileDialog(true);
    setAnchorEl(null);
    setSelectedDevice(null);
  };

  const handleCloseProfileDialog = () => {
    setOpenProfileDialog(false);
    setDeviceForProfile(null);
    setSelectedProfileId('');
    setError('');
  };

  const handleAssignProfile = async () => {
    if (!deviceForProfile) {
      setError(t('devices.noDeviceSelected'));
      return;
    }

    try {
      setError('');
      const payload = {
        deviceName: deviceForProfile.deviceName,
        osVersion: deviceForProfile.osVersion,
        isOnline: deviceForProfile.isOnline,
        profileId: selectedProfileId === '' ? null : parseInt(selectedProfileId)
      };

      await api.put(`/devices/${deviceForProfile.id}`, payload);

      handleCloseProfileDialog();
      setSnackbar({ open: true, message: t('devices.assignSuccess'), severity: 'success' });
      loadDevices();
    } catch (error) {
      const errorMsg = error.response?.data?.message || t('devices.assignFailed');
      setError(errorMsg);
      setSnackbar({ open: true, message: errorMsg, severity: 'error' });
    }
  };

  const getDeviceIcon = (name) => {
    const lowerName = name.toLowerCase();
    if (lowerName.includes('phone') || lowerName.includes('iphone') || lowerName.includes('android')) {
      return <SmartphoneIcon />;
    }
    if (lowerName.includes('tablet') || lowerName.includes('ipad')) {
      return <TabletIcon />;
    }
    return <ComputerIcon />;
  };

  return (
    <Box>
      {/* Header */}
      <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 3 }}>
        <Typography variant="h4">{t('devices.title')}</Typography>
        <Button variant="contained" startIcon={<AddIcon />} onClick={handleOpenDialog}>
          {t('devices.addDevice')}
        </Button>
      </Box>

      {/* Devices Grid */}
      {loading ? (
        <Typography>{t('common.loading')}</Typography>
      ) : devices.length > 0 ? (
        <Grid container spacing={3}>
          {devices.map((device) => (
            <Grid item xs={12} sm={6} md={4} key={device.id}>
              <Card>
                <CardContent>
                  <Box sx={{ display: 'flex', alignItems: 'center', mb: 2 }}>
                    <Avatar sx={{ bgcolor: device.isOnline ? 'success.light' : 'grey.300', mr: 2 }}>
                      {getDeviceIcon(device.deviceName)}
                    </Avatar>
                    <Box sx={{ flex: 1 }}>
                      <Typography variant="h6">{device.deviceName}</Typography>
                      <Typography variant="body2" color="text.secondary">
                        {device.osVersion || t('devices.unknown')}
                      </Typography>
                    </Box>
                    <IconButton onClick={(e) => handleMenuOpen(e, device)}>
                      <MoreVertIcon />
                    </IconButton>
                  </Box>

                  <Box sx={{ display: 'flex', gap: 1, flexWrap: 'wrap', mb: 2 }}>
                    <Chip
                      icon={device.isOnline ? <WifiIcon /> : <WifiOffIcon />}
                      label={device.isOnline ? t('devices.online') : t('devices.offline')}
                      size="small"
                      color={device.isOnline ? 'success' : 'default'}
                    />
                    {device.profile ? (
                      <Chip
                        icon={<PersonIcon />}
                        label={device.profile.profileName}
                        size="small"
                        color="primary"
                      />
                    ) : (
                      <Chip label={t('devices.noProfile')} size="small" variant="outlined" />
                    )}
                  </Box>

                  <Box sx={{ bgcolor: 'grey.100', p: 1.5, borderRadius: 1 }}>
                    <Typography variant="caption" color="text.secondary">
                      {t('devices.connectionCode')}
                    </Typography>
                    <Typography variant="h6" fontFamily="monospace" color="primary.main">
                      {device.deviceCode}
                    </Typography>
                  </Box>
                </CardContent>
              </Card>
            </Grid>
          ))}
        </Grid>
      ) : (
        <Card>
          <CardContent sx={{ textAlign: 'center', py: 6 }}>
            <ComputerIcon sx={{ fontSize: 64, color: 'text.secondary', mb: 2 }} />
            <Typography variant="h6" color="text.secondary" gutterBottom>
              {t('devices.noDevices')}
            </Typography>
            <Typography color="text.secondary" sx={{ mb: 3 }}>
              {t('devices.noDevicesDesc')}
            </Typography>
            <Button variant="contained" startIcon={<AddIcon />} onClick={handleOpenDialog}>
              {t('devices.addFirst')}
            </Button>
          </CardContent>
        </Card>
      )}

      {/* Context Menu */}
      <Menu anchorEl={anchorEl} open={Boolean(anchorEl)} onClose={handleMenuClose}>
        <MenuItem onClick={handleOpenProfileDialog}>
          <ListItemIcon>
            <PersonIcon fontSize="small" />
          </ListItemIcon>
          {t('devices.assignProfile')}
        </MenuItem>
        <MenuItem onClick={handleDeleteDevice} sx={{ color: 'error.main' }}>
          <ListItemIcon>
            <DeleteIcon fontSize="small" color="error" />
          </ListItemIcon>
          {t('devices.deleteDevice')}
        </MenuItem>
      </Menu>

      {/* Assign Profile Dialog */}
      <Dialog open={openProfileDialog} onClose={handleCloseProfileDialog} maxWidth="sm" fullWidth>
        <DialogTitle>{t('devices.assignProfileTitle')}</DialogTitle>
        <DialogContent>
          {error && (
            <Alert severity="error" sx={{ mb: 2, mt: 1 }}>
              {error}
            </Alert>
          )}
          <Typography variant="body2" color="text.secondary" sx={{ mb: 2, mt: 1 }}>
            {t('devices.assignProfileDesc')} <strong>{deviceForProfile?.deviceName}</strong>
          </Typography>
          <TextField
            select
            fullWidth
            label={t('devices.selectProfile')}
            value={selectedProfileId}
            onChange={(e) => setSelectedProfileId(e.target.value)}
            sx={{ mt: 1 }}
          >
            <MenuItem value="">
              <em>{t('devices.noAssign')}</em>
            </MenuItem>
            {profiles.map((profile) => (
              <MenuItem key={profile.id} value={profile.id.toString()}>
                {profile.profileName}
              </MenuItem>
            ))}
          </TextField>
        </DialogContent>
        <DialogActions sx={{ px: 3, pb: 2 }}>
          <Button onClick={handleCloseProfileDialog}>{t('common.cancel')}</Button>
          <Button variant="contained" onClick={handleAssignProfile}>
            {t('common.save')}
          </Button>
        </DialogActions>
      </Dialog>

      {/* Generate Pairing Code Dialog */}
      <Dialog open={openDialog} onClose={handleCloseDialog} maxWidth="sm" fullWidth>
        <DialogTitle>{t('devices.addNew') || 'Thêm thiết bị mới'}</DialogTitle>
        <DialogContent>
          {error && (
            <Alert severity="error" sx={{ mb: 2, mt: 1 }}>
              {error}
            </Alert>
          )}

          {pairingCode ? (
            <Box sx={{ textAlign: 'center', py: 2 }}>
              <Alert severity="success" sx={{ mb: 3 }}>
                Mã ghép nối đã được tạo!
              </Alert>
              <Typography variant="body1" gutterBottom>
                Nhập mã này trên thiết bị của bé để kết nối:
              </Typography>
              <Box sx={{ bgcolor: 'primary.light', p: 3, borderRadius: 2, my: 2 }}>
                <Typography variant="h3" fontFamily="monospace" color="white" letterSpacing="0.3em">
                  {pairingCode}
                </Typography>
              </Box>
              <Typography variant="body2" color="text.secondary">
                Mã có hiệu lực trong 10 phút
              </Typography>
            </Box>
          ) : (
            <>
              <Typography variant="body2" color="text.secondary" sx={{ mt: 1, mb: 2 }}>
                Chọn hồ sơ con để tạo mã ghép nối cho thiết bị mới
              </Typography>
              <TextField
                select
                fullWidth
                label={t('devices.selectProfile') || 'Chọn hồ sơ'}
                value={pairingProfileId}
                onChange={(e) => setPairingProfileId(e.target.value)}
              >
                {profiles.map((profile) => (
                  <MenuItem key={profile.id} value={profile.id.toString()}>
                    {profile.profileName}
                  </MenuItem>
                ))}
              </TextField>
            </>
          )}
        </DialogContent>
        <DialogActions sx={{ px: 3, pb: 2 }}>
          {pairingCode ? (
            <Button variant="contained" onClick={handleCloseDialog}>
              {t('devices.done') || 'Xong'}
            </Button>
          ) : (
            <>
              <Button onClick={handleCloseDialog}>{t('common.cancel')}</Button>
              <Button
                variant="contained"
                onClick={handleGeneratePairingCode}
                disabled={generatingCode || !pairingProfileId}
              >
                {generatingCode ? 'Đang tạo...' : 'Tạo mã ghép nối'}
              </Button>
            </>
          )}
        </DialogActions>
      </Dialog>

      {/* Snackbar */}
      <Snackbar
        open={snackbar.open}
        autoHideDuration={4000}
        onClose={() => setSnackbar({ ...snackbar, open: false })}
        anchorOrigin={{ vertical: 'bottom', horizontal: 'center' }}
      >
        <Alert
          onClose={() => setSnackbar({ ...snackbar, open: false })}
          severity={snackbar.severity}
          sx={{ width: '100%' }}
        >
          {snackbar.message}
        </Alert>
      </Snackbar>
    </Box>
  );
}

export default Devices;
