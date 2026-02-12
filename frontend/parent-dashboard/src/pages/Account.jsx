import { useState } from 'react';
import {
  Box,
  Card,
  CardContent,
  Typography,
  TextField,
  Button,
  Avatar,
  Divider,
  Alert,
  Grid,
  InputAdornment,
  IconButton,
  Snackbar,
} from '@mui/material';
import {
  Person as PersonIcon,
  Email as EmailIcon,
  Phone as PhoneIcon,
  Lock as LockIcon,
  Visibility,
  VisibilityOff,
  Save as SaveIcon,
} from '@mui/icons-material';
import authService from '../services/authService';
import api from '../services/api';

function Account() {
  const currentUser = authService.getCurrentUser();
  
  // State cho thông tin cá nhân
  const [profileData, setProfileData] = useState({
    fullName: currentUser?.fullName || '',
    email: currentUser?.email || '',
    phoneNumber: currentUser?.phoneNumber || '',
  });
  
  // State cho đổi mật khẩu
  const [passwordData, setPasswordData] = useState({
    currentPassword: '',
    newPassword: '',
    confirmPassword: '',
  });
  
  const [showPasswords, setShowPasswords] = useState({
    current: false,
    new: false,
    confirm: false,
  });
  
  const [loading, setLoading] = useState({ profile: false, password: false });
  const [error, setError] = useState({ profile: '', password: '' });
  const [snackbar, setSnackbar] = useState({ open: false, message: '', severity: 'success' });

  // Cập nhật thông tin cá nhân
  const handleUpdateProfile = async (e) => {
    e.preventDefault();
    setLoading({ ...loading, profile: true });
    setError({ ...error, profile: '' });

    try {
      const response = await api.put('/auth/profile', {
        fullName: profileData.fullName,
        phoneNumber: profileData.phoneNumber,
      });
      
      // Cập nhật localStorage
      const updatedUser = { ...currentUser, ...profileData };
      localStorage.setItem('user', JSON.stringify(updatedUser));
      
      setSnackbar({
        open: true,
        message: 'Cập nhật thông tin thành công!',
        severity: 'success',
      });
    } catch (err) {
      setError({
        ...error,
        profile: err.response?.data?.error || 'Cập nhật thất bại. Vui lòng thử lại.',
      });
    } finally {
      setLoading({ ...loading, profile: false });
    }
  };

  // Đổi mật khẩu
  const handleChangePassword = async (e) => {
    e.preventDefault();
    setError({ ...error, password: '' });

    // Validate
    if (passwordData.newPassword.length < 6) {
      setError({ ...error, password: 'Mật khẩu mới phải có ít nhất 6 ký tự' });
      return;
    }

    if (passwordData.newPassword !== passwordData.confirmPassword) {
      setError({ ...error, password: 'Mật khẩu xác nhận không khớp' });
      return;
    }

    setLoading({ ...loading, password: true });

    try {
      await api.put('/auth/change-password', {
        currentPassword: passwordData.currentPassword,
        newPassword: passwordData.newPassword,
      });
      
      setPasswordData({
        currentPassword: '',
        newPassword: '',
        confirmPassword: '',
      });
      
      setSnackbar({
        open: true,
        message: 'Đổi mật khẩu thành công!',
        severity: 'success',
      });
    } catch (err) {
      setError({
        ...error,
        password: err.response?.data?.error || 'Đổi mật khẩu thất bại. Vui lòng thử lại.',
      });
    } finally {
      setLoading({ ...loading, password: false });
    }
  };

  const togglePasswordVisibility = (field) => {
    setShowPasswords({ ...showPasswords, [field]: !showPasswords[field] });
  };

  return (
    <Box>
      <Typography variant="h4" sx={{ mb: 3 }}>
        Tài khoản
      </Typography>

      <Grid container spacing={3}>
        {/* Thông tin cá nhân */}
        <Grid item xs={12} md={6}>
          <Card>
            <CardContent>
              <Box sx={{ display: 'flex', alignItems: 'center', mb: 3 }}>
                <Avatar
                  sx={{
                    width: 64,
                    height: 64,
                    bgcolor: 'primary.main',
                    fontSize: '1.5rem',
                    mr: 2,
                  }}
                >
                  {profileData.fullName?.charAt(0) || 'U'}
                </Avatar>
                <Box>
                  <Typography variant="h6">Thông tin cá nhân</Typography>
                  <Typography variant="body2" color="text.secondary">
                    Cập nhật thông tin tài khoản của bạn
                  </Typography>
                </Box>
              </Box>

              <Divider sx={{ mb: 3 }} />

              {error.profile && (
                <Alert severity="error" sx={{ mb: 2 }}>
                  {error.profile}
                </Alert>
              )}

              <form onSubmit={handleUpdateProfile}>
                <TextField
                  fullWidth
                  label="Họ và tên"
                  value={profileData.fullName}
                  onChange={(e) => setProfileData({ ...profileData, fullName: e.target.value })}
                  sx={{ mb: 2 }}
                  InputProps={{
                    startAdornment: (
                      <InputAdornment position="start">
                        <PersonIcon color="action" />
                      </InputAdornment>
                    ),
                  }}
                />

                <TextField
                  fullWidth
                  label="Email"
                  value={profileData.email}
                  disabled
                  sx={{ mb: 2 }}
                  helperText="Email không thể thay đổi"
                  InputProps={{
                    startAdornment: (
                      <InputAdornment position="start">
                        <EmailIcon color="action" />
                      </InputAdornment>
                    ),
                  }}
                />

                <TextField
                  fullWidth
                  label="Số điện thoại"
                  value={profileData.phoneNumber}
                  onChange={(e) => setProfileData({ ...profileData, phoneNumber: e.target.value })}
                  sx={{ mb: 3 }}
                  InputProps={{
                    startAdornment: (
                      <InputAdornment position="start">
                        <PhoneIcon color="action" />
                      </InputAdornment>
                    ),
                  }}
                />

                <Button
                  type="submit"
                  variant="contained"
                  startIcon={<SaveIcon />}
                  disabled={loading.profile}
                  fullWidth
                >
                  {loading.profile ? 'Đang lưu...' : 'Lưu thay đổi'}
                </Button>
              </form>
            </CardContent>
          </Card>
        </Grid>

        {/* Đổi mật khẩu */}
        <Grid item xs={12} md={6}>
          <Card>
            <CardContent>
              <Box sx={{ display: 'flex', alignItems: 'center', mb: 3 }}>
                <Avatar
                  sx={{
                    width: 64,
                    height: 64,
                    bgcolor: 'secondary.main',
                    mr: 2,
                  }}
                >
                  <LockIcon fontSize="large" />
                </Avatar>
                <Box>
                  <Typography variant="h6">Đổi mật khẩu</Typography>
                  <Typography variant="body2" color="text.secondary">
                    Đảm bảo tài khoản của bạn an toàn
                  </Typography>
                </Box>
              </Box>

              <Divider sx={{ mb: 3 }} />

              {error.password && (
                <Alert severity="error" sx={{ mb: 2 }}>
                  {error.password}
                </Alert>
              )}

              <form onSubmit={handleChangePassword}>
                <TextField
                  fullWidth
                  label="Mật khẩu hiện tại"
                  type={showPasswords.current ? 'text' : 'password'}
                  value={passwordData.currentPassword}
                  onChange={(e) => setPasswordData({ ...passwordData, currentPassword: e.target.value })}
                  sx={{ mb: 2 }}
                  InputProps={{
                    startAdornment: (
                      <InputAdornment position="start">
                        <LockIcon color="action" />
                      </InputAdornment>
                    ),
                    endAdornment: (
                      <InputAdornment position="end">
                        <IconButton onClick={() => togglePasswordVisibility('current')} edge="end">
                          {showPasswords.current ? <VisibilityOff /> : <Visibility />}
                        </IconButton>
                      </InputAdornment>
                    ),
                  }}
                />

                <TextField
                  fullWidth
                  label="Mật khẩu mới"
                  type={showPasswords.new ? 'text' : 'password'}
                  value={passwordData.newPassword}
                  onChange={(e) => setPasswordData({ ...passwordData, newPassword: e.target.value })}
                  sx={{ mb: 2 }}
                  helperText="Mật khẩu phải có ít nhất 6 ký tự"
                  InputProps={{
                    startAdornment: (
                      <InputAdornment position="start">
                        <LockIcon color="action" />
                      </InputAdornment>
                    ),
                    endAdornment: (
                      <InputAdornment position="end">
                        <IconButton onClick={() => togglePasswordVisibility('new')} edge="end">
                          {showPasswords.new ? <VisibilityOff /> : <Visibility />}
                        </IconButton>
                      </InputAdornment>
                    ),
                  }}
                />

                <TextField
                  fullWidth
                  label="Xác nhận mật khẩu mới"
                  type={showPasswords.confirm ? 'text' : 'password'}
                  value={passwordData.confirmPassword}
                  onChange={(e) => setPasswordData({ ...passwordData, confirmPassword: e.target.value })}
                  sx={{ mb: 3 }}
                  InputProps={{
                    startAdornment: (
                      <InputAdornment position="start">
                        <LockIcon color="action" />
                      </InputAdornment>
                    ),
                    endAdornment: (
                      <InputAdornment position="end">
                        <IconButton onClick={() => togglePasswordVisibility('confirm')} edge="end">
                          {showPasswords.confirm ? <VisibilityOff /> : <Visibility />}
                        </IconButton>
                      </InputAdornment>
                    ),
                  }}
                />

                <Button
                  type="submit"
                  variant="contained"
                  color="secondary"
                  startIcon={<LockIcon />}
                  disabled={loading.password}
                  fullWidth
                >
                  {loading.password ? 'Đang đổi...' : 'Đổi mật khẩu'}
                </Button>
              </form>
            </CardContent>
          </Card>
        </Grid>
      </Grid>

      {/* Snackbar thông báo */}
      <Snackbar
        open={snackbar.open}
        autoHideDuration={3000}
        onClose={() => setSnackbar({ ...snackbar, open: false })}
        anchorOrigin={{ vertical: 'bottom', horizontal: 'right' }}
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

export default Account;