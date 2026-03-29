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
import api from '../services/api';

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

  // Get today's daily limit from timeLimits
  const todayDOW = new Date().getDay();
  const todayLimit = profile.timeLimits?.find((tl) => tl.dayOfWeek === todayDOW);
  const dailyLimit = todayLimit?.dailyLimitMinutes || 120;

  // todayUsage is not available from getAllProfiles, show limit info instead
  const warningCount = profile._count?.warnings || 0;

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
              {dailyLimit} {t('dashboard.minuteUnit')}
            </Typography>
          </Box>
          <LinearProgress
            variant="determinate"
            value={0}
            sx={{
              height: 8,
              borderRadius: 4,
              bgcolor: 'grey.200',
              '& .MuiLinearProgress-bar': {
                bgcolor: 'success.main',
              },
            }}
          />
        </Box>

        <Typography variant="caption" color="text.secondary">
          {t('dashboard.warningsToday', { count: warningCount })}
        </Typography>
      </CardContent>
    </Card>
  );
}

function Dashboard() {
  const { t } = useTranslation();
  const [profiles, setProfiles] = useState([]);
  const [deviceCount, setDeviceCount] = useState(0);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    loadData();
  }, []);

  const loadData = async () => {
    try {
      const [profilesData, devicesResponse] = await Promise.all([
        profileService.getAll(),
        api.get('/devices'),
      ]);
      setProfiles(profilesData);

      // Filter out pending devices
      const linkedDevices = (devicesResponse.data || []).filter(
        (d) => d.deviceName !== 'Pending Device'
      );
      setDeviceCount(linkedDevices.length);
    } catch (error) {
      console.error('Error loading dashboard data:', error);
    } finally {
      setLoading(false);
    }
  };

  // Compute stats from real data
  const totalWarnings = profiles.reduce((sum, p) => sum + (p._count?.warnings || 0), 0);
  const totalUsageLogs = profiles.reduce((sum, p) => sum + (p._count?.usageLogs || 0), 0);

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
      value: deviceCount,
      icon: <DevicesIcon />,
      color: 'secondary',
      subtitle: t('dashboard.devicesSubtitle'),
    },
    {
      title: t('dashboard.avgTimeTitle'),
      value: totalUsageLogs > 0 ? `${totalUsageLogs}` : '0',
      icon: <TimerIcon />,
      color: 'success',
      subtitle: t('dashboard.avgTimeSubtitle'),
    },
    {
      title: t('dashboard.warningsTitle'),
      value: totalWarnings,
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
