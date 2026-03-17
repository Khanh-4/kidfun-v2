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
import { useTranslation } from 'react-i18next';
import authService from '../services/authService';
import api from '../services/api';

function Account() {
  const { t } = useTranslation();
  const currentUser = authService.getCurrentUser();

  const [profileData, setProfileData] = useState({
    fullName: currentUser?.fullName || '',
    email: currentUser?.email || '',
    phoneNumber: currentUser?.phoneNumber || '',
  });

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

  const handleUpdateProfile = async (e) => {
    e.preventDefault();
    setLoading({ ...loading, profile: true });
    setError({ ...error, profile: '' });

    try {
      await api.put('/auth/profile', {
        fullName: profileData.fullName,
        phoneNumber: profileData.phoneNumber,
      });

      const updatedUser = { ...currentUser, ...profileData };
      localStorage.setItem('user', JSON.stringify(updatedUser));

      setSnackbar({ open: true, message: t('account.profileUpdated'), severity: 'success' });
    } catch (err) {
      setError({
        ...error,
        profile: err.response?.data?.message || t('account.profileUpdateFailed'),
      });
    } finally {
      setLoading({ ...loading, profile: false });
    }
  };

  const handleChangePassword = async (e) => {
    e.preventDefault();
    setError({ ...error, password: '' });

    if (passwordData.newPassword.length < 6) {
      setError({ ...error, password: t('account.passwordTooShort') });
      return;
    }

    if (passwordData.newPassword !== passwordData.confirmPassword) {
      setError({ ...error, password: t('account.passwordMismatch') });
      return;
    }

    setLoading({ ...loading, password: true });

    try {
      await api.put('/auth/change-password', {
        currentPassword: passwordData.currentPassword,
        newPassword: passwordData.newPassword,
      });

      setPasswordData({ currentPassword: '', newPassword: '', confirmPassword: '' });
      setSnackbar({ open: true, message: t('account.passwordChanged'), severity: 'success' });
    } catch (err) {
      setError({
        ...error,
        password: err.response?.data?.message || t('account.passwordChangeFailed'),
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
        {t('account.title')}
      </Typography>

      <Grid container spacing={3}>
        {/* Personal info */}
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
                  <Typography variant="h6">{t('account.personalInfo')}</Typography>
                  <Typography variant="body2" color="text.secondary">
                    {t('account.personalInfoDesc')}
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
                  label={t('account.fullName')}
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
                  label={t('account.email')}
                  value={profileData.email}
                  disabled
                  sx={{ mb: 2 }}
                  helperText={t('account.emailReadonly')}
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
                  label={t('account.phone')}
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
                  {loading.profile ? t('account.saving') : t('account.saveChanges')}
                </Button>
              </form>
            </CardContent>
          </Card>
        </Grid>

        {/* Change password */}
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
                  <Typography variant="h6">{t('account.changePassword')}</Typography>
                  <Typography variant="body2" color="text.secondary">
                    {t('account.changePasswordDesc')}
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
                  label={t('account.currentPassword')}
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
                  label={t('account.newPassword')}
                  type={showPasswords.new ? 'text' : 'password'}
                  value={passwordData.newPassword}
                  onChange={(e) => setPasswordData({ ...passwordData, newPassword: e.target.value })}
                  sx={{ mb: 2 }}
                  helperText={t('account.passwordHelp')}
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
                  label={t('account.confirmNewPassword')}
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
                  {loading.password ? t('account.changingPassword') : t('account.changePasswordBtn')}
                </Button>
              </form>
            </CardContent>
          </Card>
        </Grid>
      </Grid>

      {/* Snackbar */}
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
