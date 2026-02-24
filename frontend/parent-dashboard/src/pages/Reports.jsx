import { useState, useEffect, useCallback } from 'react';
import {
  Box,
  Grid,
  Card,
  CardContent,
  Typography,
  FormControl,
  InputLabel,
  Select,
  MenuItem,
  CircularProgress,
  Alert,
} from '@mui/material';
import {
  AccessTime as AccessTimeIcon,
  TrendingUp as TrendingUpIcon,
  EmojiEvents as EmojiEventsIcon,
  CheckCircle as CheckCircleIcon,
} from '@mui/icons-material';
import {
  LineChart,
  Line,
  BarChart,
  Bar,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
  Cell,
} from 'recharts';
import api from '../services/api';
import profileService from '../services/profileService';

const PERIOD_OPTIONS = [
  { value: '7days', label: '7 ngày qua' },
  { value: '30days', label: '30 ngày qua' },
  { value: '90days', label: '90 ngày qua' },
];

function formatMinutes(minutes) {
  if (minutes < 60) return `${minutes} phút`;
  const h = Math.floor(minutes / 60);
  const m = minutes % 60;
  return m > 0 ? `${h}h ${m}p` : `${h}h`;
}

function formatDate(dateStr) {
  const d = new Date(dateStr + 'T00:00:00');
  return `${d.getDate()}/${d.getMonth() + 1}`;
}

function Reports() {
  const [profiles, setProfiles] = useState([]);
  const [selectedProfile, setSelectedProfile] = useState('');
  const [period, setPeriod] = useState('7days');
  const [report, setReport] = useState(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);

  // Fetch profiles on mount
  useEffect(() => {
    profileService.getAll().then((data) => {
      setProfiles(data);
      if (data.length > 0) {
        setSelectedProfile(data[0].id);
      }
    });
  }, []);

  // Fetch report when profile or period changes
  const fetchReport = useCallback(async () => {
    if (!selectedProfile) return;
    setLoading(true);
    setError(null);
    try {
      const res = await api.get(`/monitoring/reports/${selectedProfile}`, {
        params: { period },
      });
      setReport(res.data);
    } catch (err) {
      setError('Không thể tải dữ liệu báo cáo');
      setReport(null);
    } finally {
      setLoading(false);
    }
  }, [selectedProfile, period]);

  useEffect(() => {
    fetchReport();
  }, [fetchReport]);

  // Prepare chart data
  const dailyChartData = report?.dailyUsage?.map((d) => ({
    date: formatDate(d.date),
    minutes: d.minutes,
  })) || [];

  const comparisonData = report
    ? [
        { name: 'Ngày thường\n(T2-T6)', minutes: report.weekdayAvg },
        { name: 'Cuối tuần\n(T7-CN)', minutes: report.weekendAvg },
      ]
    : [];

  const periodLabel = PERIOD_OPTIONS.find((p) => p.value === period)?.label || '';

  const statCards = report
    ? [
        {
          label: 'Tổng thời gian',
          value: formatMinutes(report.totalMinutes),
          sub: periodLabel,
          color: 'primary.main',
          icon: <AccessTimeIcon />,
        },
        {
          label: 'Trung bình/ngày',
          value: formatMinutes(report.avgMinutesPerDay),
          sub: periodLabel,
          color: 'secondary.main',
          icon: <TrendingUpIcon />,
        },
        {
          label: 'Ngày dùng nhiều nhất',
          value: report.peakDay?.date
            ? formatMinutes(report.peakDay.minutes)
            : '—',
          sub: report.peakDay?.date ? formatDate(report.peakDay.date) : 'Chưa có dữ liệu',
          color: 'warning.main',
          icon: <EmojiEventsIcon />,
        },
        {
          label: 'Tuân thủ giới hạn',
          value: `${report.complianceRate}%`,
          sub: periodLabel,
          color: 'success.main',
          icon: <CheckCircleIcon />,
        },
      ]
    : [];

  // Empty state: no data at all
  const hasData = report && report.totalMinutes > 0;

  return (
    <Box>
      {/* Header */}
      <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 3, flexWrap: 'wrap', gap: 2 }}>
        <Typography variant="h4">Báo cáo</Typography>
        <Box sx={{ display: 'flex', gap: 2 }}>
          <FormControl size="small" sx={{ minWidth: 150 }}>
            <InputLabel>Hồ sơ</InputLabel>
            <Select
              value={selectedProfile}
              label="Hồ sơ"
              onChange={(e) => setSelectedProfile(e.target.value)}
            >
              {profiles.map((p) => (
                <MenuItem key={p.id} value={p.id}>
                  {p.profileName}
                </MenuItem>
              ))}
            </Select>
          </FormControl>
          <FormControl size="small" sx={{ minWidth: 150 }}>
            <InputLabel>Thời gian</InputLabel>
            <Select
              value={period}
              label="Thời gian"
              onChange={(e) => setPeriod(e.target.value)}
            >
              {PERIOD_OPTIONS.map((opt) => (
                <MenuItem key={opt.value} value={opt.value}>
                  {opt.label}
                </MenuItem>
              ))}
            </Select>
          </FormControl>
        </Box>
      </Box>

      {/* Loading */}
      {loading && (
        <Box sx={{ display: 'flex', justifyContent: 'center', py: 8 }}>
          <CircularProgress />
        </Box>
      )}

      {/* Error */}
      {error && !loading && (
        <Alert severity="error" sx={{ mb: 3 }}>{error}</Alert>
      )}

      {/* No profiles */}
      {!loading && profiles.length === 0 && (
        <Alert severity="info">
          Chưa có hồ sơ con nào. Hãy tạo hồ sơ trước khi xem báo cáo.
        </Alert>
      )}

      {/* Empty state */}
      {!loading && !error && report && !hasData && (
        <Alert severity="info">
          Chưa có dữ liệu sử dụng trong khoảng thời gian này.
        </Alert>
      )}

      {/* Report content */}
      {!loading && !error && hasData && (
        <>
          {/* Stats Cards */}
          <Grid container spacing={3} sx={{ mb: 3 }}>
            {statCards.map((card) => (
              <Grid item xs={12} sm={6} md={3} key={card.label}>
                <Card>
                  <CardContent>
                    <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
                      <Box>
                        <Typography color="text.secondary" variant="body2">
                          {card.label}
                        </Typography>
                        <Typography variant="h4" color={card.color} sx={{ my: 1 }}>
                          {card.value}
                        </Typography>
                        <Typography variant="caption" color="text.secondary">
                          {card.sub}
                        </Typography>
                      </Box>
                      <Box sx={{ color: card.color, opacity: 0.3 }}>
                        {card.icon}
                      </Box>
                    </Box>
                  </CardContent>
                </Card>
              </Grid>
            ))}
          </Grid>

          {/* Charts */}
          <Grid container spacing={3}>
            {/* Daily Usage Line Chart */}
            <Grid item xs={12} md={8}>
              <Card>
                <CardContent>
                  <Typography variant="h6" gutterBottom>
                    Thời gian sử dụng theo ngày
                  </Typography>
                  <Box sx={{ height: 300 }}>
                    <ResponsiveContainer width="100%" height="100%">
                      <LineChart data={dailyChartData}>
                        <CartesianGrid strokeDasharray="3 3" />
                        <XAxis dataKey="date" />
                        <YAxis
                          unit="p"
                          allowDecimals={false}
                        />
                        <Tooltip
                          formatter={(value) => [`${formatMinutes(value)}`, 'Thời gian']}
                        />
                        <Line
                          type="monotone"
                          dataKey="minutes"
                          stroke="#6366f1"
                          strokeWidth={2}
                          dot={{ r: 3 }}
                          activeDot={{ r: 5 }}
                        />
                      </LineChart>
                    </ResponsiveContainer>
                  </Box>
                </CardContent>
              </Card>
            </Grid>

            {/* Weekday vs Weekend Bar Chart */}
            <Grid item xs={12} md={4}>
              <Card>
                <CardContent>
                  <Typography variant="h6" gutterBottom>
                    Ngày thường vs Cuối tuần
                  </Typography>
                  <Box sx={{ height: 300 }}>
                    <ResponsiveContainer width="100%" height="100%">
                      <BarChart data={comparisonData}>
                        <CartesianGrid strokeDasharray="3 3" />
                        <XAxis dataKey="name" />
                        <YAxis unit="p" allowDecimals={false} />
                        <Tooltip
                          formatter={(value) => [`${formatMinutes(value)}`, 'Trung bình']}
                        />
                        <Bar dataKey="minutes" radius={[4, 4, 0, 0]}>
                          {comparisonData.map((_, index) => (
                            <Cell key={index} fill={index === 0 ? '#6366f1' : '#f472b6'} />
                          ))}
                        </Bar>
                      </BarChart>
                    </ResponsiveContainer>
                  </Box>
                </CardContent>
              </Card>
            </Grid>
          </Grid>
        </>
      )}
    </Box>
  );
}

export default Reports;
