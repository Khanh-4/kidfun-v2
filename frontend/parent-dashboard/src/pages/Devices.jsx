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
} from '@mui/icons-material';
import api from '../services/api';
import socketService from '../services/socketService';
import authService from '../services/authService';

function Devices() {
  const [devices, setDevices] = useState([]);
  const [loading, setLoading] = useState(true);
  const [openDialog, setOpenDialog] = useState(false);
  const [formData, setFormData] = useState({ deviceName: '', osVersion: '' });
  const [error, setError] = useState('');
  const [newDevice, setNewDevice] = useState(null);
  const [anchorEl, setAnchorEl] = useState(null);
  const [selectedDevice, setSelectedDevice] = useState(null);

  const user = authService.getCurrentUser();

  // Kết nối socket khi component mount
  useEffect(() => {
    socketService.connect(user?.id);
  }, [user?.id]);

  useEffect(() => {
    loadDevices();
  }, []);

  const loadDevices = async () => {
    try {
      const response = await api.get('/devices');
      setDevices(response.data);
    } catch (error) {
      console.error('Error loading devices:', error);
    } finally {
      setLoading(false);
    }
  };

  const handleOpenDialog = () => {
    setFormData({ deviceName: '', osVersion: '' });
    setError('');
    setNewDevice(null);
    setOpenDialog(true);
  };

  const handleCloseDialog = () => {
    setOpenDialog(false);
    setNewDevice(null);
  };

  const handleSubmit = async () => {
    if (!formData.deviceName.trim()) {
      setError('Vui lòng nhập tên thiết bị');
      return;
    }

    try {
      const response = await api.post('/devices', formData);
      setNewDevice(response.data.device);
      loadDevices();
    } catch (error) {
      setError(error.response?.data?.error || 'Có lỗi xảy ra');
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
      
      // Thông báo đến Child qua Socket.IO
      socketService.removeDevice(user?.id, selectedDevice.id, selectedDevice.deviceCode);
      
      handleMenuClose();
      loadDevices();
    } catch (error) {
      console.error('Error deleting device:', error);
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
        <Typography variant="h4">Thiết bị</Typography>
        <Button variant="contained" startIcon={<AddIcon />} onClick={handleOpenDialog}>
          Thêm thiết bị
        </Button>
      </Box>

      {/* Devices Grid */}
      {loading ? (
        <Typography>Đang tải...</Typography>
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
                        {device.osVersion || 'Không xác định'}
                      </Typography>
                    </Box>
                    <IconButton onClick={(e) => handleMenuOpen(e, device)}>
                      <MoreVertIcon />
                    </IconButton>
                  </Box>

                  <Box sx={{ display: 'flex', gap: 1, flexWrap: 'wrap', mb: 2 }}>
                    <Chip
                      icon={device.isOnline ? <WifiIcon /> : <WifiOffIcon />}
                      label={device.isOnline ? 'Trực tuyến' : 'Ngoại tuyến'}
                      size="small"
                      color={device.isOnline ? 'success' : 'default'}
                    />
                  </Box>

                  <Box sx={{ bgcolor: 'grey.100', p: 1.5, borderRadius: 1 }}>
                    <Typography variant="caption" color="text.secondary">
                      Mã kết nối
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
              Chưa có thiết bị nào
            </Typography>
            <Typography color="text.secondary" sx={{ mb: 3 }}>
              Thêm thiết bị của con để bắt đầu giám sát
            </Typography>
            <Button variant="contained" startIcon={<AddIcon />} onClick={handleOpenDialog}>
              Thêm thiết bị đầu tiên
            </Button>
          </CardContent>
        </Card>
      )}

      {/* Context Menu */}
      <Menu anchorEl={anchorEl} open={Boolean(anchorEl)} onClose={handleMenuClose}>
        <MenuItem onClick={handleDeleteDevice} sx={{ color: 'error.main' }}>
          <ListItemIcon>
            <DeleteIcon fontSize="small" color="error" />
          </ListItemIcon>
          Xóa thiết bị
        </MenuItem>
      </Menu>

      {/* Add Device Dialog */}
      <Dialog open={openDialog} onClose={handleCloseDialog} maxWidth="sm" fullWidth>
        <DialogTitle>Thêm thiết bị mới</DialogTitle>
        <DialogContent>
          {error && (
            <Alert severity="error" sx={{ mb: 2, mt: 1 }}>
              {error}
            </Alert>
          )}

          {newDevice ? (
            <Box sx={{ textAlign: 'center', py: 2 }}>
              <Alert severity="success" sx={{ mb: 3 }}>
                Thiết bị đã được tạo thành công!
              </Alert>
              <Typography variant="body1" gutterBottom>
                Sử dụng mã sau để kết nối thiết bị:
              </Typography>
              <Box sx={{ bgcolor: 'primary.light', p: 3, borderRadius: 2, my: 2 }}>
                <Typography variant="h3" fontFamily="monospace" color="white">
                  {newDevice.deviceCode}
                </Typography>
              </Box>
              <Typography variant="body2" color="text.secondary">
                Nhập mã này vào ứng dụng KidFun trên thiết bị của con
              </Typography>
            </Box>
          ) : (
            <>
              <TextField
                fullWidth
                label="Tên thiết bị"
                placeholder="VD: Máy tính bé An, iPad của con..."
                value={formData.deviceName}
                onChange={(e) => setFormData({ ...formData, deviceName: e.target.value })}
                sx={{ mt: 2, mb: 2 }}
                autoFocus
              />
              <TextField
                fullWidth
                label="Hệ điều hành (tùy chọn)"
                placeholder="VD: Windows 11, iOS 17, Android 14..."
                value={formData.osVersion}
                onChange={(e) => setFormData({ ...formData, osVersion: e.target.value })}
              />
            </>
          )}
        </DialogContent>
        <DialogActions sx={{ px: 3, pb: 2 }}>
          {newDevice ? (
            <Button variant="contained" onClick={handleCloseDialog}>
              Hoàn tất
            </Button>
          ) : (
            <>
              <Button onClick={handleCloseDialog}>Hủy</Button>
              <Button variant="contained" onClick={handleSubmit}>
                Thêm thiết bị
              </Button>
            </>
          )}
        </DialogActions>
      </Dialog>
    </Box>
  );
}

export default Devices;