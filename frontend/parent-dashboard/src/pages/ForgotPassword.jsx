import { useState } from 'react';
import { Link as RouterLink, useNavigate } from 'react-router-dom';
import {
  Box,
  Card,
  CardContent,
  TextField,
  Button,
  Typography,
  Link,
  Alert,
  InputAdornment,
  CircularProgress,
  IconButton,
} from '@mui/material';
import { Email, ArrowBack, Lock, Visibility, VisibilityOff, Dialpad } from '@mui/icons-material';
import { useTranslation } from 'react-i18next';
import api from '../services/api';

function ForgotPassword() {
  const { t } = useTranslation();
  const navigate = useNavigate();

  // Step 1: email, Step 2: OTP + new password
  const [step, setStep] = useState(1);
  const [email, setEmail] = useState('');
  const [otp, setOtp] = useState('');
  const [newPassword, setNewPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState(false);

  const handleSendOtp = async (e) => {
    e.preventDefault();
    setLoading(true);
    setError('');

    try {
      await api.post('/auth/forgot-password', { email });
      setStep(2);
    } catch (err) {
      setError(err.response?.data?.message || t('auth.forgotPassword.failed'));
    } finally {
      setLoading(false);
    }
  };

  const handleResetPassword = async (e) => {
    e.preventDefault();

    if (newPassword.length < 6) {
      setError(t('auth.resetPassword.passwordTooShort'));
      return;
    }

    if (newPassword !== confirmPassword) {
      setError(t('auth.resetPassword.passwordMismatch'));
      return;
    }

    setLoading(true);
    setError('');

    try {
      await api.post('/auth/reset-password-otp', { email, otp, newPassword });
      setSuccess(true);
      setTimeout(() => navigate('/login'), 3000);
    } catch (err) {
      setError(err.response?.data?.message || t('auth.resetPassword.failed'));
    } finally {
      setLoading(false);
    }
  };

  const handleResendOtp = async () => {
    setLoading(true);
    setError('');

    try {
      await api.post('/auth/forgot-password', { email });
      setError('');
    } catch (err) {
      setError(err.response?.data?.message || t('auth.forgotPassword.failed'));
    } finally {
      setLoading(false);
    }
  };

  return (
    <Box
      sx={{
        minHeight: '100vh',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        bgcolor: 'background.default',
        p: 2,
      }}
    >
      <Card sx={{ maxWidth: 420, width: '100%' }}>
        <CardContent sx={{ p: 4 }}>
          {/* Logo */}
          <Box sx={{ textAlign: 'center', mb: 4 }}>
            <Typography
              variant="h4"
              sx={{
                fontWeight: 700,
                background: 'linear-gradient(45deg, #6366f1, #f472b6)',
                backgroundClip: 'text',
                WebkitBackgroundClip: 'text',
                WebkitTextFillColor: 'transparent',
              }}
            >
              KidFun
            </Typography>
            <Typography color="text.secondary" sx={{ mt: 1 }}>
              {t('auth.forgotPassword.title')}
            </Typography>
          </Box>

          {success ? (
            <>
              <Alert severity="success" sx={{ mb: 3 }}>
                {t('auth.resetPassword.success')}
              </Alert>
              <Typography align="center">
                <Link component={RouterLink} to="/login" underline="hover" sx={{ display: 'inline-flex', alignItems: 'center', gap: 0.5 }}>
                  <ArrowBack fontSize="small" /> {t('auth.resetPassword.loginNow')}
                </Link>
              </Typography>
            </>
          ) : step === 1 ? (
            <>
              {error && (
                <Alert severity="error" sx={{ mb: 3 }}>
                  {error}
                </Alert>
              )}

              <Typography color="text.secondary" sx={{ mb: 3, fontSize: 14 }}>
                {t('auth.forgotPassword.description')}
              </Typography>

              <form onSubmit={handleSendOtp}>
                <TextField
                  fullWidth
                  label={t('auth.forgotPassword.email')}
                  type="email"
                  value={email}
                  onChange={(e) => { setEmail(e.target.value); setError(''); }}
                  required
                  sx={{ mb: 3 }}
                  InputProps={{
                    startAdornment: (
                      <InputAdornment position="start">
                        <Email color="action" />
                      </InputAdornment>
                    ),
                  }}
                />

                <Button
                  type="submit"
                  fullWidth
                  variant="contained"
                  size="large"
                  disabled={loading}
                  sx={{ mb: 2, py: 1.5 }}
                >
                  {loading ? <CircularProgress size={24} color="inherit" /> : t('auth.forgotPassword.submit')}
                </Button>
              </form>

              <Typography align="center">
                <Link component={RouterLink} to="/login" underline="hover" sx={{ display: 'inline-flex', alignItems: 'center', gap: 0.5 }}>
                  <ArrowBack fontSize="small" /> {t('auth.forgotPassword.backToLogin')}
                </Link>
              </Typography>
            </>
          ) : (
            <>
              {error && (
                <Alert severity="error" sx={{ mb: 3 }}>
                  {error}
                </Alert>
              )}

              <Alert severity="info" sx={{ mb: 3 }}>
                {t('auth.forgotPassword.otpSent', { email })}
              </Alert>

              <form onSubmit={handleResetPassword}>
                <TextField
                  fullWidth
                  label={t('auth.forgotPassword.otpLabel')}
                  value={otp}
                  onChange={(e) => {
                    const val = e.target.value.replace(/\D/g, '').slice(0, 6);
                    setOtp(val);
                    setError('');
                  }}
                  required
                  placeholder="000000"
                  sx={{ mb: 2 }}
                  inputProps={{ maxLength: 6, inputMode: 'numeric', style: { letterSpacing: '0.5em', textAlign: 'center', fontSize: '1.2rem' } }}
                  InputProps={{
                    startAdornment: (
                      <InputAdornment position="start">
                        <Dialpad color="action" />
                      </InputAdornment>
                    ),
                  }}
                />

                <TextField
                  fullWidth
                  label={t('auth.resetPassword.newPassword')}
                  name="newPassword"
                  type={showPassword ? 'text' : 'password'}
                  value={newPassword}
                  onChange={(e) => { setNewPassword(e.target.value); setError(''); }}
                  required
                  sx={{ mb: 2 }}
                  InputProps={{
                    startAdornment: (
                      <InputAdornment position="start">
                        <Lock color="action" />
                      </InputAdornment>
                    ),
                    endAdornment: (
                      <InputAdornment position="end">
                        <IconButton onClick={() => setShowPassword(!showPassword)} edge="end">
                          {showPassword ? <VisibilityOff /> : <Visibility />}
                        </IconButton>
                      </InputAdornment>
                    ),
                  }}
                />

                <TextField
                  fullWidth
                  label={t('auth.resetPassword.confirmPassword')}
                  name="confirmPassword"
                  type={showPassword ? 'text' : 'password'}
                  value={confirmPassword}
                  onChange={(e) => { setConfirmPassword(e.target.value); setError(''); }}
                  required
                  sx={{ mb: 3 }}
                  InputProps={{
                    startAdornment: (
                      <InputAdornment position="start">
                        <Lock color="action" />
                      </InputAdornment>
                    ),
                  }}
                />

                <Button
                  type="submit"
                  fullWidth
                  variant="contained"
                  size="large"
                  disabled={loading || otp.length !== 6}
                  sx={{ mb: 2, py: 1.5 }}
                >
                  {loading ? <CircularProgress size={24} color="inherit" /> : t('auth.resetPassword.submit')}
                </Button>
              </form>

              <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                <Link
                  component="button"
                  underline="hover"
                  onClick={() => { setStep(1); setOtp(''); setError(''); }}
                  sx={{ display: 'inline-flex', alignItems: 'center', gap: 0.5, fontSize: 14 }}
                >
                  <ArrowBack fontSize="small" /> {t('auth.forgotPassword.changeEmail')}
                </Link>
                <Link
                  component="button"
                  underline="hover"
                  onClick={handleResendOtp}
                  disabled={loading}
                  sx={{ fontSize: 14 }}
                >
                  {t('auth.forgotPassword.resendOtp')}
                </Link>
              </Box>
            </>
          )}
        </CardContent>
      </Card>
    </Box>
  );
}

export default ForgotPassword;
