import { useState, useEffect } from 'react';
import {
  Box,
  Typography,
  Card,
  CardContent,
  FormControl,
  InputLabel,
  Select,
  MenuItem,
  Slider,
  Button,
  Alert,
  Snackbar,
  Grid,
  Chip,
  Divider,
  CircularProgress,
  TextField,
  InputAdornment,
} from '@mui/material';
import {
  Timer as TimerIcon,
  Save as SaveIcon,
  ContentCopy as CopyIcon,
} from '@mui/icons-material';
import profileService from '../services/profileService';
import api from '../services/api';

const DAYS = [
  { value: 1, label: 'Thứ 2', short: 'T2' },
  { value: 2, label: 'Thứ 3', short: 'T3' },
  { value: 3, label: 'Thứ 4', short: 'T4' },
  { value: 4, label: 'Thứ 5', short: 'T5' },
  { value: 5, label: 'Thứ 6', short: 'T6' },
  { value: 6, label: 'Thứ 7', short: 'T7' },
  { value: 0, label: 'Chủ nhật', short: 'CN' },
];

const formatMinutes = (minutes) => {
  const h = Math.floor(minutes / 60);
  const m = minutes % 60;
  if (h === 0) return `${m} phút`;
  if (m === 0) return `${h} giờ`;
  return `${h}g ${m}p`;
};

function TimeSettings() {
  const [profiles, setProfiles] = useState([]);
  const [selectedProfileId, setSelectedProfileId] = useState('');
  const [timeLimits, setTimeLimits] = useState({});
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [snackbar, setSnackbar] = useState({ open: false, message: '', severity: 'success' });
  const [applyAllValue, setApplyAllValue] = useState(120);

  useEffect(() => {
    loadProfiles();
  }, []);

  useEffect(() => {
    if (selectedProfileId) {
      loadTimeLimits(selectedProfileId);
    }
  }, [selectedProfileId]);

  const loadProfiles = async () => {
    try {
      const data = await profileService.getAll();
      setProfiles(data);
      if (data.length > 0) {
        setSelectedProfileId(data[0].id);
      }
    } catch (error) {
      setSnackbar({ open: true, message: 'Không thể tải danh sách hồ sơ', severity: 'error' });
    } finally {
      setLoading(false);
    }
  };

  const loadTimeLimits = async (profileId) => {
    try {
      const data = await profileService.getById(profileId);
      const limits = {};
      DAYS.forEach((day) => {
        const existing = data.timeLimits?.find((tl) => tl.dayOfWeek === day.value);
        limits[day.value] = existing ? existing.dailyLimitMinutes : 120;
      });
      setTimeLimits(limits);
    } catch (error) {
      setSnackbar({ open: true, message: 'Không thể tải giới hạn thời gian', severity: 'error' });
    }
  };

  const handleSliderChange = (dayOfWeek, newValue) => {
    setTimeLimits((prev) => ({ ...prev, [dayOfWeek]: newValue }));
  };

  const handleInputChange = (dayOfWeek, value) => {
    const minutes = Math.max(0, Math.min(480, parseInt(value) || 0));
    setTimeLimits((prev) => ({ ...prev, [dayOfWeek]: minutes }));
  };

  const handleApplyAll = () => {
    const newLimits = {};
    DAYS.forEach((day) => {
      newLimits[day.value] = applyAllValue;
    });
    setTimeLimits(newLimits);
  };

  const handleSave = async () => {
    setSaving(true);
    try {
      const payload = DAYS.map((day) => ({
        dayOfWeek: day.value,
        dailyLimitMinutes: timeLimits[day.value] ?? 120,
      }));

      await api.put(`/profiles/${selectedProfileId}/time-limits`, { timeLimits: payload });
      setSnackbar({ open: true, message: 'Đã lưu giới hạn thời gian thành công!', severity: 'success' });
    } catch (error) {
      setSnackbar({ open: true, message: 'Lưu thất bại. Vui lòng thử lại.', severity: 'error' });
    } finally {
      setSaving(false);
    }
  };

  const getSliderColor = (minutes) => {
    if (minutes <= 60) return 'success';
    if (minutes <= 180) return 'primary';
    return 'warning';
  };

  if (loading) {
    return (
      <Box sx={{ display: 'flex', justifyContent: 'center', mt: 10 }}>
        <CircularProgress />
      </Box>
    );
  }

  if (profiles.length === 0) {
    return (
      <Box>
        <Typography variant="h4" gutterBottom>
          Giới hạn thời gian
        </Typography>
        <Card>
          <CardContent sx={{ textAlign: 'center', py: 6 }}>
            <TimerIcon sx={{ fontSize: 64, color: 'text.disabled', mb: 2 }} />
            <Typography variant="h6" color="text.secondary">
              Chưa có hồ sơ con nào
            </Typography>
            <Typography color="text.secondary" sx={{ mt: 1 }}>
              Hãy tạo hồ sơ con trước để cài đặt giới hạn thời gian.
            </Typography>
          </CardContent>
        </Card>
      </Box>
    );
  }

  const selectedProfile = profiles.find((p) => p.id === selectedProfileId);

  return (
    <Box>
      <Typography variant="h4" gutterBottom>
        Giới hạn thời gian
      </Typography>

      {/* Profile selector */}
      <Card sx={{ mb: 3 }}>
        <CardContent>
          <FormControl fullWidth>
            <InputLabel>Chọn hồ sơ con</InputLabel>
            <Select
              value={selectedProfileId}
              label="Chọn hồ sơ con"
              onChange={(e) => setSelectedProfileId(e.target.value)}
            >
              {profiles.map((profile) => (
                <MenuItem key={profile.id} value={profile.id}>
                  {profile.profileName}
                </MenuItem>
              ))}
            </Select>
          </FormControl>
        </CardContent>
      </Card>

      {/* Apply all */}
      <Card sx={{ mb: 3 }}>
        <CardContent>
          <Box sx={{ display: 'flex', alignItems: 'center', gap: 2, flexWrap: 'wrap' }}>
            <CopyIcon color="action" />
            <Typography variant="body1" fontWeight={500}>
              Áp dụng cho tất cả:
            </Typography>
            <Slider
              value={applyAllValue}
              onChange={(_, val) => setApplyAllValue(val)}
              min={0}
              max={480}
              step={15}
              sx={{ flex: 1, minWidth: 150 }}
            />
            <Chip label={formatMinutes(applyAllValue)} color="primary" variant="outlined" />
            <Button variant="outlined" size="small" onClick={handleApplyAll}>
              Áp dụng
            </Button>
          </Box>
        </CardContent>
      </Card>

      {/* Per-day settings */}
      <Card sx={{ mb: 3 }}>
        <CardContent>
          <Typography variant="h6" gutterBottom>
            Cài đặt theo ngày — {selectedProfile?.profileName}
          </Typography>
          <Divider sx={{ mb: 3 }} />

          {DAYS.map((day, index) => (
            <Box key={day.value}>
              <Grid container spacing={2} alignItems="center" sx={{ py: 1.5 }}>
                <Grid size={{ xs: 3, sm: 2 }}>
                  <Chip
                    label={day.label}
                    size="small"
                    color={day.value === 0 || day.value === 6 ? 'secondary' : 'default'}
                    variant={day.value === 0 || day.value === 6 ? 'filled' : 'outlined'}
                  />
                </Grid>
                <Grid size={{ xs: 5, sm: 7 }}>
                  <Slider
                    value={timeLimits[day.value] ?? 120}
                    onChange={(_, val) => handleSliderChange(day.value, val)}
                    min={0}
                    max={480}
                    step={15}
                    color={getSliderColor(timeLimits[day.value] ?? 120)}
                    marks={[
                      { value: 0, label: '0' },
                      { value: 120, label: '2g' },
                      { value: 240, label: '4g' },
                      { value: 360, label: '6g' },
                      { value: 480, label: '8g' },
                    ]}
                  />
                </Grid>
                <Grid size={{ xs: 4, sm: 3 }}>
                  <TextField
                    size="small"
                    type="number"
                    value={timeLimits[day.value] ?? 120}
                    onChange={(e) => handleInputChange(day.value, e.target.value)}
                    slotProps={{
                      input: {
                        endAdornment: <InputAdornment position="end">phút</InputAdornment>,
                        inputProps: { min: 0, max: 480, step: 15 },
                      },
                    }}
                    sx={{ width: '100%' }}
                  />
                </Grid>
              </Grid>
              {index < DAYS.length - 1 && <Divider />}
            </Box>
          ))}
        </CardContent>
      </Card>

      {/* Save button */}
      <Box sx={{ display: 'flex', justifyContent: 'flex-end' }}>
        <Button
          variant="contained"
          size="large"
          startIcon={saving ? <CircularProgress size={20} color="inherit" /> : <SaveIcon />}
          onClick={handleSave}
          disabled={saving}
        >
          {saving ? 'Đang lưu...' : 'Lưu cài đặt'}
        </Button>
      </Box>

      {/* Snackbar */}
      <Snackbar
        open={snackbar.open}
        autoHideDuration={3000}
        onClose={() => setSnackbar((prev) => ({ ...prev, open: false }))}
        anchorOrigin={{ vertical: 'bottom', horizontal: 'center' }}
      >
        <Alert
          onClose={() => setSnackbar((prev) => ({ ...prev, open: false }))}
          severity={snackbar.severity}
          variant="filled"
        >
          {snackbar.message}
        </Alert>
      </Snackbar>
    </Box>
  );
}

export default TimeSettings;
