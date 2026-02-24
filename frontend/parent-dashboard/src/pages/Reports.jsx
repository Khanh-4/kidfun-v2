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
import { useTranslation } from 'react-i18next';
import api from '../services/api';
import profileService from '../services/profileService';

function Reports() {
  const { t } = useTranslation();

  const PERIOD_OPTIONS = [
    { value: '7days', label: t('reports.7days') },
    { value: '30days', label: t('reports.30days') },
    { value: '90days', label: t('reports.90days') },
  ];

  const [profiles, setProfiles] = useState([]);
  const [selectedProfile, setSelectedProfile] = useState('');
  const [period, setPeriod] = useState('7days');
  const [report, setReport] = useState(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);

  function formatMinutes(minutes) {
    if (minutes < 60) return `${minutes} ${t('reports.minuteUnit')}`;
    const h = Math.floor(minutes / 60);
    const m = minutes % 60;
    return m > 0 ? t('reports.hourMinute', { h, m }) : t('reports.hourUnit', { h });
  }

  function formatDate(dateStr) {
    const d = new Date(dateStr + 'T00:00:00');
    return `${d.getDate()}/${d.getMonth() + 1}`;
  }

  useEffect(() => {
    profileService.getAll().then((data) => {
      setProfiles(data);
      if (data.length > 0) {
        setSelectedProfile(data[0].id);
      }
    });
  }, []);

  const fetchReport = useCallback(async () => {
    if (!selectedProfile) return;
    setLoading(true);
    setError(null);
    try {
      const res = await api.get(`/monitoring/reports/${selectedProfile}`, {
        params: { period },
      });
      setReport(res.data);
    } catch {
      setError(t('common.error'));
      setReport(null);
    } finally {
      setLoading(false);
    }
  }, [selectedProfile, period, t]);

  useEffect(() => {
    fetchReport();
  }, [fetchReport]);

  const dailyChartData = report?.dailyUsage?.map((d) => ({
    date: formatDate(d.date),
    minutes: d.minutes,
  })) || [];

  const comparisonData = report
    ? [
        { name: t('reports.weekday'), minutes: report.weekdayAvg },
        { name: t('reports.weekend'), minutes: report.weekendAvg },
      ]
    : [];

  const periodLabel = PERIOD_OPTIONS.find((p) => p.value === period)?.label || '';

  const statCards = report
    ? [
        {
          label: t('reports.totalTime'),
          value: formatMinutes(report.totalMinutes),
          sub: periodLabel,
          color: 'primary.main',
          icon: <AccessTimeIcon />,
        },
        {
          label: t('reports.avgPerDay'),
          value: formatMinutes(report.avgMinutesPerDay),
          sub: periodLabel,
          color: 'secondary.main',
          icon: <TrendingUpIcon />,
        },
        {
          label: t('reports.peakDay'),
          value: report.peakDay?.date
            ? formatMinutes(report.peakDay.minutes)
            : '—',
          sub: report.peakDay?.date ? formatDate(report.peakDay.date) : t('reports.noData'),
          color: 'warning.main',
          icon: <EmojiEventsIcon />,
        },
        {
          label: t('reports.compliance'),
          value: `${report.complianceRate}%`,
          sub: periodLabel,
          color: 'success.main',
          icon: <CheckCircleIcon />,
        },
      ]
    : [];

  const hasData = report && report.totalMinutes > 0;

  return (
    <Box>
      {/* Header */}
      <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 3, flexWrap: 'wrap', gap: 2 }}>
        <Typography variant="h4">{t('reports.title')}</Typography>
        <Box sx={{ display: 'flex', gap: 2 }}>
          <FormControl size="small" sx={{ minWidth: 150 }}>
            <InputLabel>{t('reports.profile')}</InputLabel>
            <Select
              value={selectedProfile}
              label={t('reports.profile')}
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
            <InputLabel>{t('reports.period')}</InputLabel>
            <Select
              value={period}
              label={t('reports.period')}
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

      {loading && (
        <Box sx={{ display: 'flex', justifyContent: 'center', py: 8 }}>
          <CircularProgress />
        </Box>
      )}

      {error && !loading && (
        <Alert severity="error" sx={{ mb: 3 }}>{error}</Alert>
      )}

      {!loading && profiles.length === 0 && (
        <Alert severity="info">{t('reports.noProfiles')}</Alert>
      )}

      {!loading && !error && report && !hasData && (
        <Alert severity="info">{t('reports.noUsageData')}</Alert>
      )}

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
            <Grid item xs={12} md={8}>
              <Card>
                <CardContent>
                  <Typography variant="h6" gutterBottom>
                    {t('reports.dailyChart')}
                  </Typography>
                  <Box sx={{ height: 300 }}>
                    <ResponsiveContainer width="100%" height="100%">
                      <LineChart data={dailyChartData}>
                        <CartesianGrid strokeDasharray="3 3" />
                        <XAxis dataKey="date" />
                        <YAxis unit={t('reports.minuteShort')} allowDecimals={false} />
                        <Tooltip formatter={(value) => [formatMinutes(value), t('reports.time')]} />
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

            <Grid item xs={12} md={4}>
              <Card>
                <CardContent>
                  <Typography variant="h6" gutterBottom>
                    {t('reports.comparisonChart')}
                  </Typography>
                  <Box sx={{ height: 300 }}>
                    <ResponsiveContainer width="100%" height="100%">
                      <BarChart data={comparisonData}>
                        <CartesianGrid strokeDasharray="3 3" />
                        <XAxis dataKey="name" />
                        <YAxis unit={t('reports.minuteShort')} allowDecimals={false} />
                        <Tooltip formatter={(value) => [formatMinutes(value), t('reports.average')]} />
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
