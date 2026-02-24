import { useState, useEffect } from 'react';
import {
  Box,
  Grid,
  Card,
  CardContent,
  Typography,
  Button,
  Avatar,
  IconButton,
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  TextField,
  Alert,
  Chip,
  Menu,
  MenuItem,
  ListItemIcon,
} from '@mui/material';
import {
  Add as AddIcon,
  MoreVert as MoreVertIcon,
  Edit as EditIcon,
  Delete as DeleteIcon,
  Person as PersonIcon,
} from '@mui/icons-material';
import { useTranslation } from 'react-i18next';
import profileService from '../services/profileService';

function Profiles() {
  const { t } = useTranslation();
  const [profiles, setProfiles] = useState([]);
  const [loading, setLoading] = useState(true);
  const [openDialog, setOpenDialog] = useState(false);
  const [editingProfile, setEditingProfile] = useState(null);
  const [formData, setFormData] = useState({ profileName: '', dateOfBirth: '' });
  const [error, setError] = useState('');
  const [anchorEl, setAnchorEl] = useState(null);
  const [selectedProfile, setSelectedProfile] = useState(null);

  useEffect(() => {
    loadProfiles();
  }, []);

  const loadProfiles = async () => {
    try {
      const data = await profileService.getAll();
      setProfiles(data);
    } catch (error) {
      console.error('Error loading profiles:', error);
    } finally {
      setLoading(false);
    }
  };

  const handleOpenDialog = (profile = null) => {
    if (profile) {
      setEditingProfile(profile);
      setFormData({
        profileName: profile.profileName,
        dateOfBirth: profile.dateOfBirth ? profile.dateOfBirth.split('T')[0] : '',
      });
    } else {
      setEditingProfile(null);
      setFormData({ profileName: '', dateOfBirth: '' });
    }
    setError('');
    setOpenDialog(true);
    setAnchorEl(null);
  };

  const handleCloseDialog = () => {
    setOpenDialog(false);
    setEditingProfile(null);
    setFormData({ profileName: '', dateOfBirth: '' });
    setError('');
  };

  const handleSubmit = async () => {
    if (!formData.profileName.trim()) {
      setError(t('profiles.nameRequired'));
      return;
    }

    try {
      if (editingProfile) {
        await profileService.update(editingProfile.id, formData);
      } else {
        await profileService.create(formData);
      }
      handleCloseDialog();
      loadProfiles();
    } catch (error) {
      setError(error.response?.data?.error || t('common.error'));
    }
  };

  const handleDelete = async () => {
    if (!selectedProfile) return;

    try {
      await profileService.delete(selectedProfile.id);
      setAnchorEl(null);
      setSelectedProfile(null);
      loadProfiles();
    } catch (error) {
      console.error('Error deleting profile:', error);
    }
  };

  const handleMenuOpen = (event, profile) => {
    setAnchorEl(event.currentTarget);
    setSelectedProfile(profile);
  };

  const handleMenuClose = () => {
    setAnchorEl(null);
    setSelectedProfile(null);
  };

  const getAge = (dateOfBirth) => {
    if (!dateOfBirth) return null;
    const today = new Date();
    const birth = new Date(dateOfBirth);
    let age = today.getFullYear() - birth.getFullYear();
    const monthDiff = today.getMonth() - birth.getMonth();
    if (monthDiff < 0 || (monthDiff === 0 && today.getDate() < birth.getDate())) {
      age--;
    }
    return age;
  };

  return (
    <Box>
      {/* Header */}
      <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 3 }}>
        <Typography variant="h4">{t('profiles.title')}</Typography>
        <Button
          variant="contained"
          startIcon={<AddIcon />}
          onClick={() => handleOpenDialog()}
        >
          {t('profiles.addProfile')}
        </Button>
      </Box>

      {/* Profiles Grid */}
      {loading ? (
        <Typography>{t('common.loading')}</Typography>
      ) : profiles.length > 0 ? (
        <Grid container spacing={3}>
          {profiles.map((profile) => (
            <Grid item xs={12} sm={6} md={4} key={profile.id}>
              <Card>
                <CardContent>
                  <Box sx={{ display: 'flex', alignItems: 'flex-start', mb: 2 }}>
                    <Avatar
                      sx={{
                        width: 56,
                        height: 56,
                        mr: 2,
                        bgcolor: 'primary.main',
                        fontSize: '1.5rem',
                      }}
                    >
                      {profile.profileName?.charAt(0) || '?'}
                    </Avatar>
                    <Box sx={{ flex: 1 }}>
                      <Typography variant="h6">{profile.profileName}</Typography>
                      {profile.dateOfBirth && (
                        <Typography variant="body2" color="text.secondary">
                          {t('profiles.yearsOld', { age: getAge(profile.dateOfBirth) })}
                        </Typography>
                      )}
                    </Box>
                    <IconButton onClick={(e) => handleMenuOpen(e, profile)}>
                      <MoreVertIcon />
                    </IconButton>
                  </Box>

                  <Box sx={{ display: 'flex', gap: 1, flexWrap: 'wrap' }}>
                    <Chip
                      label={profile.isActive ? t('profiles.active') : t('profiles.inactive')}
                      size="small"
                      color={profile.isActive ? 'success' : 'default'}
                    />
                    <Chip
                      label={t('profiles.limitsCount', { count: profile.timeLimits?.length || 0 })}
                      size="small"
                      variant="outlined"
                    />
                  </Box>
                </CardContent>
              </Card>
            </Grid>
          ))}
        </Grid>
      ) : (
        <Card>
          <CardContent sx={{ textAlign: 'center', py: 6 }}>
            <PersonIcon sx={{ fontSize: 64, color: 'text.secondary', mb: 2 }} />
            <Typography variant="h6" color="text.secondary" gutterBottom>
              {t('profiles.noProfiles')}
            </Typography>
            <Typography color="text.secondary" sx={{ mb: 3 }}>
              {t('profiles.noProfilesDesc')}
            </Typography>
            <Button variant="contained" startIcon={<AddIcon />} onClick={() => handleOpenDialog()}>
              {t('profiles.addFirst')}
            </Button>
          </CardContent>
        </Card>
      )}

      {/* Context Menu */}
      <Menu anchorEl={anchorEl} open={Boolean(anchorEl)} onClose={handleMenuClose}>
        <MenuItem onClick={() => handleOpenDialog(selectedProfile)}>
          <ListItemIcon>
            <EditIcon fontSize="small" />
          </ListItemIcon>
          {t('profiles.edit')}
        </MenuItem>
        <MenuItem onClick={handleDelete} sx={{ color: 'error.main' }}>
          <ListItemIcon>
            <DeleteIcon fontSize="small" color="error" />
          </ListItemIcon>
          {t('profiles.delete')}
        </MenuItem>
      </Menu>

      {/* Add/Edit Dialog */}
      <Dialog open={openDialog} onClose={handleCloseDialog} maxWidth="sm" fullWidth>
        <DialogTitle>
          {editingProfile ? t('profiles.editProfile') : t('profiles.addNew')}
        </DialogTitle>
        <DialogContent>
          {error && (
            <Alert severity="error" sx={{ mb: 2, mt: 1 }}>
              {error}
            </Alert>
          )}
          <TextField
            fullWidth
            label={t('profiles.childName')}
            value={formData.profileName}
            onChange={(e) => setFormData({ ...formData, profileName: e.target.value })}
            sx={{ mt: 2, mb: 2 }}
            autoFocus
          />
          <TextField
            fullWidth
            label={t('profiles.dateOfBirth')}
            type="date"
            value={formData.dateOfBirth}
            onChange={(e) => setFormData({ ...formData, dateOfBirth: e.target.value })}
            InputLabelProps={{ shrink: true }}
          />
        </DialogContent>
        <DialogActions sx={{ px: 3, pb: 2 }}>
          <Button onClick={handleCloseDialog}>{t('common.cancel')}</Button>
          <Button variant="contained" onClick={handleSubmit}>
            {editingProfile ? t('profiles.update') : t('profiles.add')}
          </Button>
        </DialogActions>
      </Dialog>
    </Box>
  );
}

export default Profiles;
