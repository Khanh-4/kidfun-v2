import { useState } from 'react';
import {
  Box,
  Card,
  CardContent,
  TextField,
  Button,
  Typography,
  Alert,
  CircularProgress,
} from '@mui/material';
import { Link as LinkIcon } from '@mui/icons-material';
import api from '../services/api';

function LinkDevice({ onLinked }) {
  const [pairingCode, setPairingCode] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  const handleSubmit = async (e) => {
    e.preventDefault();
    setLoading(true);
    setError('');

    try {
      const response = await api.post('/devices/link', { pairingCode: pairingCode.trim() });
      const device = response.data.device;
      localStorage.setItem('deviceCode', device.deviceCode);
      localStorage.setItem('device', JSON.stringify(device));
      onLinked(device);
    } catch (err) {
      setError(err.response?.data?.message || 'Mã ghép nối không hợp lệ hoặc đã hết hạn. Vui lòng thử lại.');
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
        background: 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)',
        p: 2,
      }}
    >
      <Card sx={{ maxWidth: 400, width: '100%', borderRadius: 4 }}>
        <CardContent sx={{ p: 4, textAlign: 'center' }}>
          {/* Logo */}
          <Typography
            variant="h3"
            sx={{
              fontWeight: 700,
              background: 'linear-gradient(45deg, #6366f1, #f472b6)',
              backgroundClip: 'text',
              WebkitBackgroundClip: 'text',
              WebkitTextFillColor: 'transparent',
              mb: 1,
            }}
          >
            🎮 KidFun
          </Typography>
          <Typography color="text.secondary" sx={{ mb: 4 }}>
            Ứng dụng dành cho bé
          </Typography>

          {/* Instruction */}
          <Box
            sx={{
              bgcolor: 'primary.light',
              color: 'white',
              p: 2,
              borderRadius: 2,
              mb: 3,
            }}
          >
            <Typography variant="body2">
              Hãy nhờ bố mẹ tạo <strong>mã ghép nối</strong> từ ứng dụng Parent Dashboard
            </Typography>
          </Box>

          {/* Error */}
          {error && (
            <Alert severity="error" sx={{ mb: 2 }}>
              {error}
            </Alert>
          )}

          {/* Form */}
          <form onSubmit={handleSubmit}>
            <TextField
              fullWidth
              label="Nhập mã ghép nối (6 số)"
              value={pairingCode}
              onChange={(e) => setPairingCode(e.target.value.replace(/\D/g, '').slice(0, 6))}
              placeholder="VD: 123456"
              sx={{ mb: 3 }}
              inputProps={{
                style: {
                  textAlign: 'center',
                  fontSize: '1.5rem',
                  fontFamily: 'monospace',
                  letterSpacing: '0.3em',
                },
                maxLength: 6,
                inputMode: 'numeric',
              }}
            />

            <Button
              type="submit"
              fullWidth
              variant="contained"
              size="large"
              disabled={loading || pairingCode.length !== 6}
              startIcon={loading ? <CircularProgress size={20} color="inherit" /> : <LinkIcon />}
              sx={{ py: 1.5, borderRadius: 2 }}
            >
              {loading ? 'Đang kết nối...' : 'Kết nối thiết bị'}
            </Button>
          </form>
        </CardContent>
      </Card>
    </Box>
  );
}

export default LinkDevice;