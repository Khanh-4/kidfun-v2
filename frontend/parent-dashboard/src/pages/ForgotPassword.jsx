import { useState } from 'react';
import { Link as RouterLink } from 'react-router-dom';
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
} from '@mui/material';
import { Email, ArrowBack } from '@mui/icons-material';
import { useTranslation } from 'react-i18next';
import api from '../services/api';

function ForgotPassword() {
  const { t } = useTranslation();
  const [email, setEmail] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState(false);

  const handleSubmit = async (e) => {
    e.preventDefault();
    setLoading(true);
    setError('');

    try {
      await api.post('/auth/forgot-password', { email });
      setSuccess(true);
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
              🎯 KidFun
            </Typography>
            <Typography color="text.secondary" sx={{ mt: 1 }}>
              {t('auth.forgotPassword.title')}
            </Typography>
          </Box>

          {success ? (
            <>
              <Alert severity="success" sx={{ mb: 3 }}>
                {t('auth.forgotPassword.success')}
              </Alert>
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

              <Typography color="text.secondary" sx={{ mb: 3, fontSize: 14 }}>
                {t('auth.forgotPassword.description')}
              </Typography>

              <form onSubmit={handleSubmit}>
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
          )}
        </CardContent>
      </Card>
    </Box>
  );
}

export default ForgotPassword;
