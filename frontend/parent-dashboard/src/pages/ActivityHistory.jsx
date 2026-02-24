import { useState, useEffect, useCallback } from 'react';
import {
  Box,
  Typography,
  Card,
  CardContent,
  Grid,
  FormControl,
  InputLabel,
  Select,
  MenuItem,
  TextField,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  TablePagination,
  Paper,
  CircularProgress,
  Chip,
} from '@mui/material';
import {
  AccessTime as AccessTimeIcon,
  TrendingUp as TrendingUpIcon,
  EmojiEvents as EmojiEventsIcon,
} from '@mui/icons-material';
import { useTranslation } from 'react-i18next';
import api from '../services/api';
import profileService from '../services/profileService';

function ActivityHistory() {
  const { t } = useTranslation();
  const [profiles, setProfiles] = useState([]);
  const [selectedProfile, setSelectedProfile] = useState('');
  const [dateRange, setDateRange] = useState('7days');
  const [customStart, setCustomStart] = useState('');
  const [customEnd, setCustomEnd] = useState('');
  const [sessions, setSessions] = useState([]);
  const [totalCount, setTotalCount] = useState(0);
  const [summary, setSummary] = useState(null);
  const [page, setPage] = useState(0);
  const [rowsPerPage] = useState(10);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    const loadProfiles = async () => {
      try {
        const data = await profileService.getAll();
        setProfiles(data);
        if (data.length > 0) {
          setSelectedProfile(data[0].id);
        }
      } catch (err) {
        console.error('Error loading profiles:', err);
      }
    };
    loadProfiles();
  }, []);

  const getDateParams = useCallback(() => {
    const now = new Date();
    if (dateRange === '7days') {
      const start = new Date(now);
      start.setDate(start.getDate() - 7);
      return { startDate: start.toISOString().split('T')[0], endDate: now.toISOString().split('T')[0] };
    }
    if (dateRange === '30days') {
      const start = new Date(now);
      start.setDate(start.getDate() - 30);
      return { startDate: start.toISOString().split('T')[0], endDate: now.toISOString().split('T')[0] };
    }
    return { startDate: customStart, endDate: customEnd };
  }, [dateRange, customStart, customEnd]);

  const fetchData = useCallback(async () => {
    if (!selectedProfile) return;
    const { startDate, endDate } = getDateParams();
    if (dateRange === 'custom' && (!startDate || !endDate)) return;

    setLoading(true);
    try {
      const params = new URLSearchParams({
        startDate,
        endDate,
        page: page + 1,
        limit: rowsPerPage,
      });
      const response = await api.get(`/monitoring/activity-history/${selectedProfile}?${params}`);
      setSessions(response.data.sessions);
      setTotalCount(response.data.totalCount);
      setSummary(response.data.summary);
    } catch (err) {
      console.error('Error loading activity history:', err);
    } finally {
      setLoading(false);
    }
  }, [selectedProfile, getDateParams, dateRange, page, rowsPerPage]);

  useEffect(() => {
    fetchData();
  }, [fetchData]);

  useEffect(() => {
    setPage(0);
  }, [selectedProfile, dateRange, customStart, customEnd]);

  const formatDate = (dateStr) => {
    return new Date(dateStr).toLocaleDateString('vi-VN');
  };

  const formatTime = (dateStr) => {
    return new Date(dateStr).toLocaleTimeString('vi-VN', { hour: '2-digit', minute: '2-digit' });
  };

  const formatDuration = (minutes) => {
    if (!minutes) return '—';
    const h = Math.floor(minutes / 60);
    const m = minutes % 60;
    if (h > 0) return `${h}h ${m}m`;
    return `${m}m`;
  };

  return (
    <Box>
      <Typography variant="h4" gutterBottom>
        {t('activityHistory.title')}
      </Typography>

      {/* Filters */}
      <Card sx={{ mb: 3 }}>
        <CardContent>
          <Box sx={{ display: 'flex', gap: 2, flexWrap: 'wrap', alignItems: 'center' }}>
            <FormControl size="small" sx={{ minWidth: 180 }}>
              <InputLabel>{t('activityHistory.childProfile')}</InputLabel>
              <Select
                value={selectedProfile}
                label={t('activityHistory.childProfile')}
                onChange={(e) => setSelectedProfile(e.target.value)}
              >
                {profiles.map((p) => (
                  <MenuItem key={p.id} value={p.id}>
                    {p.profileName}
                  </MenuItem>
                ))}
              </Select>
            </FormControl>

            <FormControl size="small" sx={{ minWidth: 160 }}>
              <InputLabel>{t('activityHistory.dateRange')}</InputLabel>
              <Select
                value={dateRange}
                label={t('activityHistory.dateRange')}
                onChange={(e) => setDateRange(e.target.value)}
              >
                <MenuItem value="7days">{t('activityHistory.7days')}</MenuItem>
                <MenuItem value="30days">{t('activityHistory.30days')}</MenuItem>
                <MenuItem value="custom">{t('activityHistory.custom')}</MenuItem>
              </Select>
            </FormControl>

            {dateRange === 'custom' && (
              <>
                <TextField
                  size="small"
                  type="date"
                  label={t('activityHistory.fromDate')}
                  value={customStart}
                  onChange={(e) => setCustomStart(e.target.value)}
                  InputLabelProps={{ shrink: true }}
                />
                <TextField
                  size="small"
                  type="date"
                  label={t('activityHistory.toDate')}
                  value={customEnd}
                  onChange={(e) => setCustomEnd(e.target.value)}
                  InputLabelProps={{ shrink: true }}
                />
              </>
            )}
          </Box>
        </CardContent>
      </Card>

      {/* Summary Cards */}
      {summary && (
        <Grid container spacing={3} sx={{ mb: 3 }}>
          <Grid item xs={12} sm={4}>
            <Card>
              <CardContent sx={{ display: 'flex', alignItems: 'center', gap: 2 }}>
                <AccessTimeIcon color="primary" sx={{ fontSize: 40 }} />
                <Box>
                  <Typography variant="body2" color="text.secondary">
                    {t('activityHistory.totalTime')}
                  </Typography>
                  <Typography variant="h5" fontWeight={600}>
                    {formatDuration(summary.totalMinutes)}
                  </Typography>
                </Box>
              </CardContent>
            </Card>
          </Grid>
          <Grid item xs={12} sm={4}>
            <Card>
              <CardContent sx={{ display: 'flex', alignItems: 'center', gap: 2 }}>
                <TrendingUpIcon color="secondary" sx={{ fontSize: 40 }} />
                <Box>
                  <Typography variant="body2" color="text.secondary">
                    {t('activityHistory.avgPerDay')}
                  </Typography>
                  <Typography variant="h5" fontWeight={600}>
                    {formatDuration(summary.avgPerDay)}
                  </Typography>
                </Box>
              </CardContent>
            </Card>
          </Grid>
          <Grid item xs={12} sm={4}>
            <Card>
              <CardContent sx={{ display: 'flex', alignItems: 'center', gap: 2 }}>
                <EmojiEventsIcon sx={{ fontSize: 40, color: '#f59e0b' }} />
                <Box>
                  <Typography variant="body2" color="text.secondary">
                    {t('activityHistory.peakDay')}
                  </Typography>
                  {summary.peakDay ? (
                    <>
                      <Typography variant="h5" fontWeight={600}>
                        {formatDuration(summary.peakDay.minutes)}
                      </Typography>
                      <Chip
                        label={formatDate(summary.peakDay.date)}
                        size="small"
                        variant="outlined"
                      />
                    </>
                  ) : (
                    <Typography variant="h5" fontWeight={600}>—</Typography>
                  )}
                </Box>
              </CardContent>
            </Card>
          </Grid>
        </Grid>
      )}

      {/* Sessions Table */}
      <Card>
        {loading ? (
          <Box sx={{ display: 'flex', justifyContent: 'center', py: 6 }}>
            <CircularProgress />
          </Box>
        ) : !selectedProfile ? (
          <CardContent sx={{ textAlign: 'center', py: 6 }}>
            <Typography color="text.secondary">
              {t('activityHistory.selectProfile')}
            </Typography>
          </CardContent>
        ) : sessions.length === 0 ? (
          <CardContent sx={{ textAlign: 'center', py: 6 }}>
            <Typography color="text.secondary">
              {t('activityHistory.noData')}
            </Typography>
          </CardContent>
        ) : (
          <>
            <TableContainer component={Paper} elevation={0}>
              <Table>
                <TableHead>
                  <TableRow>
                    <TableCell sx={{ fontWeight: 600 }}>{t('activityHistory.date')}</TableCell>
                    <TableCell sx={{ fontWeight: 600 }}>{t('activityHistory.device')}</TableCell>
                    <TableCell sx={{ fontWeight: 600 }}>{t('activityHistory.start')}</TableCell>
                    <TableCell sx={{ fontWeight: 600 }}>{t('activityHistory.end')}</TableCell>
                    <TableCell sx={{ fontWeight: 600 }}>{t('activityHistory.duration')}</TableCell>
                  </TableRow>
                </TableHead>
                <TableBody>
                  {sessions.map((session) => (
                    <TableRow key={session.id} hover>
                      <TableCell>{formatDate(session.startTime)}</TableCell>
                      <TableCell>{session.device?.deviceName || '—'}</TableCell>
                      <TableCell>{formatTime(session.startTime)}</TableCell>
                      <TableCell>
                        {session.endTime ? formatTime(session.endTime) : (
                          <Chip label={t('activityHistory.active')} size="small" color="success" />
                        )}
                      </TableCell>
                      <TableCell>
                        {session.totalMinutes != null ? formatDuration(session.totalMinutes) : '—'}
                      </TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </TableContainer>
            <TablePagination
              component="div"
              count={totalCount}
              page={page}
              onPageChange={(_, newPage) => setPage(newPage)}
              rowsPerPage={rowsPerPage}
              rowsPerPageOptions={[10]}
              labelDisplayedRows={({ from, to, count }) =>
                t('activityHistory.paginationLabel', {
                  from,
                  to,
                  total: count !== -1 ? count : `>${to}`,
                })
              }
            />
          </>
        )}
      </Card>
    </Box>
  );
}

export default ActivityHistory;
