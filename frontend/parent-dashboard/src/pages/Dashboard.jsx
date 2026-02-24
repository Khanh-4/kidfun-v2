import { useState, useEffect } from 'react';
import {
  Box,
  Grid,
  Card,
  CardContent,
  Typography,
  Avatar,
  Chip,
  LinearProgress,
} from '@mui/material';
import {
  People as PeopleIcon,
  Devices as DevicesIcon,
  Timer as TimerIcon,
  Warning as WarningIcon,
} from '@mui/icons-material';
import { useTranslation } from 'react-i18next';
import profileService from '../services/profileService';

function StatCard({ title, value, icon, color, subtitle }) {
  return (
    <Card>
      <CardContent>
        <Box sx={{ display: 'flex', alignItems: 'center', mb: 2 }}>
          <Avatar sx={{ bgcolor: `${color}.light`, color: `${color}.main`, mr: 2 }}>
            {icon}
          </Avatar>
          <Box>
            <Typography color="text.secondary" variant="body2">
              {title}
            </Typography>
            <Typography variant="h4" fontWeight={600}>
              {value}
            </Typography>
          </Box>
        </Box>
        {subtitle && (
          <Typography variant="caption" color="text.secondary">
            {subtitle}
          </Typography>
        )}
      </CardContent>
    </Card>
  );
}

function ProfileCard({ profile }) {
  const { t } = useTranslation();
  const usagePercent = Math.min((profile.todayUsage || 0) / (profile.dailyLimit || 120) * 100, 100);

  return (
    <Card>
      <CardContent>
        <Box sx={{ display: 'flex', alignItems: 'center', mb: 2 }}>
          <Avatar
            sx={{
              width: 48,
              height: 48,
              mr: 2,
              bgcolor: 'primary.main',
              fontSize: '1.2rem',
            }}
          >
            {profile.profileName?.charAt(0) || '?'}
          </Avatar>
          <Box sx={{ flex: 1 }}>
            <Typography variant="h6">{profile.profileName}</Typography>
            <Chip
              label={profile.isActive ? t('dashboard.active') : t('dashboard.inactive')}
              size="small"
              color={profile.isActive ? 'success' : 'default'}
            />
          </Box>
        </Box>

        <Box sx={{ mb: 1 }}>
          <Box sx={{ display: 'flex', justifyContent: 'space-between', mb: 0.5 }}>
            <Typography variant="body2" color="text.secondary">
              {t('dashboard.todayUsage')}
            </Typography>
            <Typography variant="body2" fontWeight={500}>
              {profile.todayUsage || 0} / {profile.dailyLimit || 120} {t('dashboard.minuteUnit')}
            </Typography>
          </Box>
          <LinearProgress
            variant="determinate"
            value={usagePercent}
            sx={{
              height: 8,
              borderRadius: 4,
              bgcolor: 'grey.200',
              '& .MuiLinearProgress-bar': {
                bgcolor: usagePercent > 80 ? 'error.main' : usagePercent > 50 ? 'warning.main' : 'success.main',
              },
            }}
          />
        </Box>

        <Typography variant="caption" color="text.secondary">
          {t('dashboard.warningsToday', { count: profile._count?.warnings || 0 })}
        </Typography>
      </CardContent>
    </Card>
  );
}

function Dashboard() {
  const { t } = useTranslation();
  const [profiles, setProfiles] = useState([]);
  const [loading, setLoading] = useState(true);

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

  const stats = [
    {
      title: t('dashboard.profilesTitle'),
      value: profiles.length,
      icon: <PeopleIcon />,
      color: 'primary',
      subtitle: t('dashboard.profilesSubtitle'),
    },
    {
      title: t('dashboard.devicesTitle'),
      value: 0,
      icon: <DevicesIcon />,
      color: 'secondary',
      subtitle: t('dashboard.devicesSubtitle'),
    },
    {
      title: t('dashboard.avgTimeTitle'),
      value: '0h',
      icon: <TimerIcon />,
      color: 'success',
      subtitle: t('dashboard.avgTimeSubtitle'),
    },
    {
      title: t('dashboard.warningsTitle'),
      value: 0,
      icon: <WarningIcon />,
      color: 'warning',
      subtitle: t('dashboard.warningsSubtitle'),
    },
  ];

  return (
    <Box>
      <Typography variant="h4" sx={{ mb: 3 }}>
        {t('dashboard.greeting')}
      </Typography>

      {/* Stats */}
      <Grid container spacing={3} sx={{ mb: 4 }}>
        {stats.map((stat) => (
          <Grid item xs={12} sm={6} md={3} key={stat.title}>
            <StatCard {...stat} />
          </Grid>
        ))}
      </Grid>

      {/* Profiles */}
      <Typography variant="h5" sx={{ mb: 2 }}>
        {t('dashboard.yourProfiles')}
      </Typography>

      {loading ? (
        <LinearProgress />
      ) : profiles.length > 0 ? (
        <Grid container spacing={3}>
          {profiles.map((profile) => (
            <Grid item xs={12} sm={6} md={4} key={profile.id}>
              <ProfileCard profile={profile} />
            </Grid>
          ))}
        </Grid>
      ) : (
        <Card>
          <CardContent sx={{ textAlign: 'center', py: 4 }}>
            <PeopleIcon sx={{ fontSize: 48, color: 'text.secondary', mb: 2 }} />
            <Typography color="text.secondary">
              {t('dashboard.noProfiles')}
            </Typography>
          </CardContent>
        </Card>
      )}
    </Box>
  );
}

export default Dashboard;
