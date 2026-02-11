import { useState } from 'react';
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
} from '@mui/material';
import {
  BarChart,
  Bar,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
  PieChart,
  Pie,
  Cell,
  Legend,
} from 'recharts';

// Mock data - sẽ thay bằng API sau
const weeklyData = [
  { day: 'T2', hours: 2.5 },
  { day: 'T3', hours: 3.0 },
  { day: 'T4', hours: 2.0 },
  { day: 'T5', hours: 2.8 },
  { day: 'T6', hours: 3.5 },
  { day: 'T7', hours: 4.0 },
  { day: 'CN', hours: 4.5 },
];

const appUsageData = [
  { name: 'YouTube', value: 35, color: '#FF0000' },
  { name: 'Games', value: 25, color: '#6366f1' },
  { name: 'Education', value: 20, color: '#22c55e' },
  { name: 'Social', value: 15, color: '#f472b6' },
  { name: 'Other', value: 5, color: '#94a3b8' },
];

function Reports() {
  const [timeRange, setTimeRange] = useState('week');
  const [selectedProfile, setSelectedProfile] = useState('all');

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
              <MenuItem value="all">Tất cả</MenuItem>
            </Select>
          </FormControl>
          <FormControl size="small" sx={{ minWidth: 150 }}>
            <InputLabel>Thời gian</InputLabel>
            <Select
              value={timeRange}
              label="Thời gian"
              onChange={(e) => setTimeRange(e.target.value)}
            >
              <MenuItem value="week">7 ngày qua</MenuItem>
              <MenuItem value="month">30 ngày qua</MenuItem>
              <MenuItem value="year">12 tháng qua</MenuItem>
            </Select>
          </FormControl>
        </Box>
      </Box>

      {/* Stats Cards */}
      <Grid container spacing={3} sx={{ mb: 3 }}>
        <Grid item xs={12} sm={6} md={3}>
          <Card>
            <CardContent>
              <Typography color="text.secondary" variant="body2">
                Tổng thời gian
              </Typography>
              <Typography variant="h4" color="primary.main">
                22.3h
              </Typography>
              <Typography variant="caption" color="text.secondary">
                Trong 7 ngày qua
              </Typography>
            </CardContent>
          </Card>
        </Grid>
        <Grid item xs={12} sm={6} md={3}>
          <Card>
            <CardContent>
              <Typography color="text.secondary" variant="body2">
                Trung bình/ngày
              </Typography>
              <Typography variant="h4" color="secondary.main">
                3.2h
              </Typography>
              <Typography variant="caption" color="text.secondary">
                Giới hạn: 2h/ngày
              </Typography>
            </CardContent>
          </Card>
        </Grid>
        <Grid item xs={12} sm={6} md={3}>
          <Card>
            <CardContent>
              <Typography color="text.secondary" variant="body2">
                Số lần cảnh báo
              </Typography>
              <Typography variant="h4" color="warning.main">
                12
              </Typography>
              <Typography variant="caption" color="text.secondary">
                Giảm 20% so với tuần trước
              </Typography>
            </CardContent>
          </Card>
        </Grid>
        <Grid item xs={12} sm={6} md={3}>
          <Card>
            <CardContent>
              <Typography color="text.secondary" variant="body2">
                Tuân thủ giới hạn
              </Typography>
              <Typography variant="h4" color="success.main">
                71%
              </Typography>
              <Typography variant="caption" color="text.secondary">
                5/7 ngày đạt mục tiêu
              </Typography>
            </CardContent>
          </Card>
        </Grid>
      </Grid>

      {/* Charts */}
      <Grid container spacing={3}>
        {/* Weekly Usage Chart */}
        <Grid item xs={12} md={8}>
          <Card>
            <CardContent>
              <Typography variant="h6" gutterBottom>
                Thời gian sử dụng theo ngày
              </Typography>
              <Box sx={{ height: 300 }}>
                <ResponsiveContainer width="100%" height="100%">
                  <BarChart data={weeklyData}>
                    <CartesianGrid strokeDasharray="3 3" />
                    <XAxis dataKey="day" />
                    <YAxis unit="h" />
                    <Tooltip formatter={(value) => [`${value} giờ`, 'Thời gian']} />
                    <Bar dataKey="hours" fill="#6366f1" radius={[4, 4, 0, 0]} />
                  </BarChart>
                </ResponsiveContainer>
              </Box>
            </CardContent>
          </Card>
        </Grid>

        {/* App Usage Pie Chart */}
        <Grid item xs={12} md={4}>
          <Card>
            <CardContent>
              <Typography variant="h6" gutterBottom>
                Phân loại ứng dụng
              </Typography>
              <Box sx={{ height: 300 }}>
                <ResponsiveContainer width="100%" height="100%">
                  <PieChart>
                    <Pie
                      data={appUsageData}
                      cx="50%"
                      cy="50%"
                      innerRadius={60}
                      outerRadius={90}
                      paddingAngle={2}
                      dataKey="value"
                    >
                      {appUsageData.map((entry, index) => (
                        <Cell key={`cell-${index}`} fill={entry.color} />
                      ))}
                    </Pie>
                    <Tooltip formatter={(value) => [`${value}%`, 'Tỷ lệ']} />
                    <Legend />
                  </PieChart>
                </ResponsiveContainer>
              </Box>
            </CardContent>
          </Card>
        </Grid>
      </Grid>
    </Box>
  );
}

export default Reports;