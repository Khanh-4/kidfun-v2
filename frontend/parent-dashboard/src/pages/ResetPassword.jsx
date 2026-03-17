import { useState } from 'react';
import { useParams, useNavigate, Link as RouterLink } from 'react-router-dom';
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
  IconButton,
  CircularProgress,
} from '@mui/material';
import { Lock, Visibility, VisibilityOff, ArrowBack } from '@mui/icons-material';
import { useTranslation } from 'react-i18next';
import api from '../services/api';

function ResetPassword() {
  const { t } = useTranslation();
  const { token } = useParams();
  const navigate = useNavigate();
  const [formData, setFormData] = useState({ newPassword: '', confirmPassword: '' });
  const [showPassword, setShowPassword] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState(false);

  const handleChange = (e) => {
    setFormData({ ...formData, [e.target.name]: e.target.value });
    setError('');
  };

  const handleSubmit = async (e) => {
    e.preventDefault();

    if (formData.newPassword.length < 6) {
      setError(t('auth.resetPassword.passwordTooShort'));
      return;
    }

    if (formData.newPassword !== formData.confirmPassword) {
      setError(t('auth.resetPassword.passwordMismatch'));
      return;
    }

    setLoading(true);
    setError('');

    try {
      await api.post('/auth/reset-password', { token, newPassword: formData.newPassword });
      setSuccess(true);
      setTimeout(() => navigate('/login'), 3000);
    } catch (err) {
      setError(err.response?.data?.message || t('auth.resetPassword.failed'));
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
              🎯 KidFun
            </Typography>
            <Typography color="text.secondary" sx={{ mt: 1 }}>
              {t('auth.resetPassword.title')}
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
          ) : (
            <>
              {error && (
                <Alert severity="error" sx={{ mb: 3 }}>
                  {error}
                </Alert>
              )}

              <form onSubmit={handleSubmit}>
                <TextField
                  fullWidth
                  label={t('auth.resetPassword.newPassword')}
                  name="newPassword"
                  type={showPassword ? 'text' : 'password'}
                  value={formData.newPassword}
                  onChange={handleChange}
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
                  value={formData.confirmPassword}
                  onChange={handleChange}
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
                  disabled={loading}
                  sx={{ mb: 2, py: 1.5 }}
                >
                  {loading ? <CircularProgress size={24} color="inherit" /> : t('auth.resetPassword.submit')}
                </Button>
              </form>

              <Typography align="center">
                <Link component={RouterLink} to="/login" underline="hover" sx={{ display: 'inline-flex', alignItems: 'center', gap: 0.5 }}>
                  <ArrowBack fontSize="small" /> {t('auth.forgotPassword.backToLogin')}
                </Link>
              </Typography>
            </>
          )}
        </CardContent>
      </Card>
    </Box>
  );
}

export default ResetPassword;
