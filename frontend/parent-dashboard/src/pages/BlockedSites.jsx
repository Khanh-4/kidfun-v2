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
  Button,
  Alert,
  Snackbar,
  Chip,
  Divider,
  CircularProgress,
  TextField,
  Dialog,
  DialogTitle,
  DialogContent,
  DialogContentText,
  DialogActions,
} from '@mui/material';
import {
  Block as BlockIcon,
  Add as AddIcon,
  Language as WebsiteIcon,
  Apps as AppIcon,
} from '@mui/icons-material';
import profileService from '../services/profileService';
import api from '../services/api';

function BlockedSites() {
  const [profiles, setProfiles] = useState([]);
  const [selectedProfileId, setSelectedProfileId] = useState('');
  const [blockedSites, setBlockedSites] = useState([]);
  const [loading, setLoading] = useState(true);
  const [adding, setAdding] = useState(false);
  const [snackbar, setSnackbar] = useState({ open: false, message: '', severity: 'success' });

  // Form state
  const [blockType, setBlockType] = useState('website');
  const [blockValue, setBlockValue] = useState('');

  // Delete confirm dialog
  const [deleteDialog, setDeleteDialog] = useState({ open: false, item: null });

  useEffect(() => {
    loadProfiles();
  }, []);

  useEffect(() => {
    if (selectedProfileId) {
      loadBlockedSites(selectedProfileId);
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

  const loadBlockedSites = async (profileId) => {
    try {
      const { data } = await api.get(`/blocked-sites/${profileId}`);
      setBlockedSites(data);
    } catch (error) {
      setSnackbar({ open: true, message: 'Không thể tải danh sách chặn', severity: 'error' });
    }
  };

  const handleAdd = async () => {
    const trimmed = blockValue.trim();
    if (!trimmed) return;

    setAdding(true);
    try {
      const { data } = await api.post('/blocked-sites', {
        profileId: selectedProfileId,
        blockType,
        blockValue: trimmed,
      });
      setBlockedSites((prev) => [data, ...prev]);
      setBlockValue('');
      setSnackbar({ open: true, message: 'Đã thêm thành công!', severity: 'success' });
    } catch (error) {
      const msg = error.response?.status === 409
        ? 'Mục này đã tồn tại trong danh sách chặn'
        : 'Thêm thất bại. Vui lòng thử lại.';
      setSnackbar({ open: true, message: msg, severity: 'error' });
    } finally {
      setAdding(false);
    }
  };

  const handleDeleteConfirm = async () => {
    const item = deleteDialog.item;
    if (!item) return;

    try {
      await api.delete(`/blocked-sites/${item.id}`);
      setBlockedSites((prev) => prev.filter((s) => s.id !== item.id));
      setSnackbar({ open: true, message: 'Đã xóa thành công!', severity: 'success' });
    } catch (error) {
      setSnackbar({ open: true, message: 'Xóa thất bại. Vui lòng thử lại.', severity: 'error' });
    } finally {
      setDeleteDialog({ open: false, item: null });
    }
  };

  const handleKeyDown = (e) => {
    if (e.key === 'Enter' && blockValue.trim()) {
      handleAdd();
    }
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
          Chặn nội dung
        </Typography>
        <Card>
          <CardContent sx={{ textAlign: 'center', py: 6 }}>
            <BlockIcon sx={{ fontSize: 64, color: 'text.disabled', mb: 2 }} />
            <Typography variant="h6" color="text.secondary">
              Chưa có hồ sơ con nào
            </Typography>
            <Typography color="text.secondary" sx={{ mt: 1 }}>
              Hãy tạo hồ sơ con trước để quản lý nội dung bị chặn.
            </Typography>
          </CardContent>
        </Card>
      </Box>
    );
  }

  const websites = blockedSites.filter((s) => s.blockType === 'website');
  const apps = blockedSites.filter((s) => s.blockType === 'app');

  return (
    <Box>
      <Typography variant="h4" gutterBottom>
        Chặn nội dung
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

      {/* Add form */}
      <Card sx={{ mb: 3 }}>
        <CardContent>
          <Typography variant="h6" gutterBottom>
            Thêm mục chặn
          </Typography>
          <Box sx={{ display: 'flex', gap: 2, alignItems: 'flex-start', flexWrap: 'wrap' }}>
            <FormControl sx={{ minWidth: 160 }}>
              <InputLabel>Loại</InputLabel>
              <Select
                value={blockType}
                label="Loại"
                onChange={(e) => setBlockType(e.target.value)}
              >
                <MenuItem value="website">Website</MenuItem>
                <MenuItem value="app">Ứng dụng</MenuItem>
              </Select>
            </FormControl>
            <TextField
              label={blockType === 'website' ? 'URL website (vd: facebook.com)' : 'Tên ứng dụng (vd: TikTok)'}
              value={blockValue}
              onChange={(e) => setBlockValue(e.target.value)}
              onKeyDown={handleKeyDown}
              sx={{ flex: 1, minWidth: 250 }}
            />
            <Button
              variant="contained"
              startIcon={adding ? <CircularProgress size={20} color="inherit" /> : <AddIcon />}
              onClick={handleAdd}
              disabled={adding || !blockValue.trim()}
              sx={{ height: 56 }}
            >
              Thêm
            </Button>
          </Box>
        </CardContent>
      </Card>

      {/* Blocked websites list */}
      <Card sx={{ mb: 3 }}>
        <CardContent>
          <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, mb: 2 }}>
            <WebsiteIcon color="error" />
            <Typography variant="h6">
              Website bị chặn
            </Typography>
            <Chip label={websites.length} size="small" color="error" variant="outlined" />
          </Box>
          <Divider sx={{ mb: 2 }} />
          {websites.length === 0 ? (
            <Typography color="text.secondary" sx={{ py: 2, textAlign: 'center' }}>
              Chưa có website nào bị chặn
            </Typography>
          ) : (
            <Box sx={{ display: 'flex', flexWrap: 'wrap', gap: 1 }}>
              {websites.map((site) => (
                <Chip
                  key={site.id}
                  label={site.blockValue}
                  onDelete={() => setDeleteDialog({ open: true, item: site })}
                  color="error"
                  variant="outlined"
                  icon={<WebsiteIcon />}
                />
              ))}
            </Box>
          )}
        </CardContent>
      </Card>

      {/* Blocked apps list */}
      <Card sx={{ mb: 3 }}>
        <CardContent>
          <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, mb: 2 }}>
            <AppIcon color="warning" />
            <Typography variant="h6">
              Ứng dụng bị chặn
            </Typography>
            <Chip label={apps.length} size="small" color="warning" variant="outlined" />
          </Box>
          <Divider sx={{ mb: 2 }} />
          {apps.length === 0 ? (
            <Typography color="text.secondary" sx={{ py: 2, textAlign: 'center' }}>
              Chưa có ứng dụng nào bị chặn
            </Typography>
          ) : (
            <Box sx={{ display: 'flex', flexWrap: 'wrap', gap: 1 }}>
              {apps.map((site) => (
                <Chip
                  key={site.id}
                  label={site.blockValue}
                  onDelete={() => setDeleteDialog({ open: true, item: site })}
                  color="warning"
                  variant="outlined"
                  icon={<AppIcon />}
                />
              ))}
            </Box>
          )}
        </CardContent>
      </Card>

      {/* Delete confirm dialog */}
      <Dialog
        open={deleteDialog.open}
        onClose={() => setDeleteDialog({ open: false, item: null })}
      >
        <DialogTitle>Xác nhận xóa</DialogTitle>
        <DialogContent>
          <DialogContentText>
            Bạn có chắc muốn bỏ chặn{' '}
            <strong>{deleteDialog.item?.blockValue}</strong>
            {' '}({deleteDialog.item?.blockType === 'website' ? 'website' : 'ứng dụng'})?
          </DialogContentText>
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setDeleteDialog({ open: false, item: null })}>
            Hủy
          </Button>
          <Button onClick={handleDeleteConfirm} color="error" variant="contained">
            Xóa
          </Button>
        </DialogActions>
      </Dialog>

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

export default BlockedSites;
