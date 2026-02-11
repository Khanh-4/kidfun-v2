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
              label={profile.isActive ? 'Đang hoạt động' : 'Không hoạt động'}
              size="small"
              color={profile.isActive ? 'success' : 'default'}
            />
          </Box>
        </Box>

        <Box sx={{ mb: 1 }}>
          <Box sx={{ display: 'flex', justifyContent: 'space-between', mb: 0.5 }}>
            <Typography variant="body2" color="text.secondary">
              Thời gian hôm nay
            </Typography>
            <Typography variant="body2" fontWeight={500}>
              {profile.todayUsage || 0} / {profile.dailyLimit || 120} phút
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
          {profile._count?.warnings || 0} cảnh báo hôm nay
        </Typography>
      </CardContent>
    </Card>
  );
}

function Dashboard() {
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
      title: 'Hồ sơ con',
      value: profiles.length,
      icon: <PeopleIcon />,
      color: 'primary',
      subtitle: 'Tổng số hồ sơ đã tạo',
    },
    {
      title: 'Thiết bị',
      value: 0,
      icon: <DevicesIcon />,
      color: 'secondary',
      subtitle: 'Thiết bị đang kết nối',
    },
    {
      title: 'Thời gian TB',
      value: '0h',
      icon: <TimerIcon />,
      color: 'success',
      subtitle: 'Trung bình mỗi ngày',
    },
    {
      title: 'Cảnh báo',
      value: 0,
      icon: <WarningIcon />,
      color: 'warning',
      subtitle: 'Trong 7 ngày qua',
    },
  ];

  return (
    <Box>
      <Typography variant="h4" sx={{ mb: 3 }}>
        Xin chào! 👋
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
        Hồ sơ con của bạn
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
              Chưa có hồ sơ nào. Hãy tạo hồ sơ con để bắt đầu!
            </Typography>
          </CardContent>
        </Card>
      )}
    </Box>
  );
}

export default Dashboard;