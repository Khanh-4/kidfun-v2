import { useState, useEffect } from 'react';
import {
  Box,
  Card,
  CardContent,
  Typography,
  Button,
  LinearProgress,
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  TextField,
  Avatar,
  Chip,
} from '@mui/material';
import {
  Timer as TimerIcon,
  Warning as WarningIcon,
  MoreTime as MoreTimeIcon,
  EmojiEvents as TrophyIcon,
} from '@mui/icons-material';

function ChildDashboard({ device }) {
  const [timeUsed, setTimeUsed] = useState(45); // phút đã dùng
  const [timeLimit, setTimeLimit] = useState(120); // giới hạn 2 giờ
  const [showWarning, setShowWarning] = useState(false);
  const [showRequestDialog, setShowRequestDialog] = useState(false);
  const [requestReason, setRequestReason] = useState('');
  const [requestSent, setRequestSent] = useState(false);

  const timeRemaining = timeLimit - timeUsed;
  const progressPercent = (timeUsed / timeLimit) * 100;

  // Cảnh báo khi còn 15 phút
  useEffect(() => {
    if (timeRemaining <= 15 && timeRemaining > 0) {
      setShowWarning(true);
    }
  }, [timeRemaining]);

  // Format thời gian
  const formatTime = (minutes) => {
    const hours = Math.floor(minutes / 60);
    const mins = minutes % 60;
    if (hours > 0) {
      return `${hours} giờ ${mins} phút`;
    }
    return `${mins} phút`;
  };

  // Gửi yêu cầu thêm thời gian
  const handleRequestTime = () => {
    // TODO: Gửi request qua Socket.IO
    console.log('Requesting more time:', requestReason);
    setRequestSent(true);
    setTimeout(() => {
      setShowRequestDialog(false);
      setRequestSent(false);
      setRequestReason('');
    }, 2000);
  };

  // Xác định màu sắc dựa trên thời gian còn lại
  const getStatusColor = () => {
    if (progressPercent >= 90) return 'error';
    if (progressPercent >= 70) return 'warning';
    return 'success';
  };

  return (
    <Box
      sx={{
        minHeight: '100vh',
        background: 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)',
        p: 2,
      }}
    >
      {/* Header */}
      <Box sx={{ textAlign: 'center', color: 'white', mb: 3, pt: 2 }}>
        <Typography variant="h4" fontWeight={700}>
          🎮 KidFun
        </Typography>
        <Chip
          label={device?.deviceName || 'Thiết bị của bé'}
          sx={{ mt: 1, bgcolor: 'rgba(255,255,255,0.2)', color: 'white' }}
        />
      </Box>

      {/* Main Time Card */}
      <Card sx={{ maxWidth: 400, mx: 'auto', borderRadius: 4, mb: 3 }}>
        <CardContent sx={{ p: 4, textAlign: 'center' }}>
          {/* Avatar */}
          <Avatar
            sx={{
              width: 80,
              height: 80,
              mx: 'auto',
              mb: 2,
              bgcolor: `${getStatusColor()}.main`,
              fontSize: '2rem',
            }}
          >
            <TimerIcon sx={{ fontSize: 40 }} />
          </Avatar>

          {/* Time Remaining */}
          <Typography variant="h3" fontWeight={700} color={`${getStatusColor()}.main`}>
            {formatTime(timeRemaining)}
          </Typography>
          <Typography color="text.secondary" gutterBottom>
            Thời gian còn lại hôm nay
          </Typography>

          {/* Progress Bar */}
          <Box sx={{ mt: 3, mb: 2 }}>
            <LinearProgress
              variant="determinate"
              value={progressPercent}
              color={getStatusColor()}
              sx={{ height: 12, borderRadius: 6 }}
            />
            <Box sx={{ display: 'flex', justifyContent: 'space-between', mt: 1 }}>
              <Typography variant="caption" color="text.secondary">
                Đã dùng: {formatTime(timeUsed)}
              </Typography>
              <Typography variant="caption" color="text.secondary">
                Giới hạn: {formatTime(timeLimit)}
              </Typography>
            </Box>
          </Box>

          {/* Request More Time Button */}
          <Button
            variant="outlined"
            startIcon={<MoreTimeIcon />}
            onClick={() => setShowRequestDialog(true)}
            sx={{ mt: 2, borderRadius: 2 }}
          >
            Xin thêm thời gian
          </Button>
        </CardContent>
      </Card>

      {/* Achievement Card */}
      <Card sx={{ maxWidth: 400, mx: 'auto', borderRadius: 4 }}>
        <CardContent sx={{ p: 3 }}>
          <Box sx={{ display: 'flex', alignItems: 'center', gap: 2 }}>
            <Avatar sx={{ bgcolor: 'warning.light' }}>
              <TrophyIcon color="warning" />
            </Avatar>
            <Box>
              <Typography variant="h6">Làm tốt lắm! 🌟</Typography>
              <Typography variant="body2" color="text.secondary">
                Bạn đã tuân thủ giới hạn 5 ngày liên tiếp!
              </Typography>
            </Box>
          </Box>
        </CardContent>
      </Card>

      {/* Warning Dialog */}
      <Dialog open={showWarning} onClose={() => setShowWarning(false)}>
        <DialogTitle sx={{ textAlign: 'center', pt: 3 }}>
          <WarningIcon color="warning" sx={{ fontSize: 48 }} />
          <Typography variant="h6" sx={{ mt: 1 }}>
            Sắp hết thời gian rồi!
          </Typography>
        </DialogTitle>
        <DialogContent>
          <Typography textAlign="center">
            Bạn còn <strong>{timeRemaining} phút</strong> sử dụng hôm nay.
            <br />
            Hãy hoàn thành công việc và nghỉ ngơi nhé! 😊
          </Typography>
        </DialogContent>
        <DialogActions sx={{ justifyContent: 'center', pb: 3 }}>
          <Button variant="contained" onClick={() => setShowWarning(false)}>
            Tôi hiểu rồi
          </Button>
        </DialogActions>
      </Dialog>

      {/* Request More Time Dialog */}
      <Dialog 
        open={showRequestDialog} 
        onClose={() => setShowRequestDialog(false)}
        maxWidth="sm"
        fullWidth
      >
        <DialogTitle>
          <MoreTimeIcon sx={{ mr: 1, verticalAlign: 'middle' }} />
          Xin thêm thời gian
        </DialogTitle>
        <DialogContent>
          {requestSent ? (
            <Box sx={{ textAlign: 'center', py: 3 }}>
              <Typography variant="h6" color="success.main">
                ✅ Đã gửi yêu cầu!
              </Typography>
              <Typography color="text.secondary">
                Chờ bố mẹ phê duyệt nhé!
              </Typography>
            </Box>
          ) : (
            <>
              <Typography sx={{ mb: 2 }}>
                Cho bố mẹ biết lý do bạn cần thêm thời gian nhé:
              </Typography>
              <TextField
                fullWidth
                multiline
                rows={3}
                placeholder="VD: Con cần hoàn thành bài tập online..."
                value={requestReason}
                onChange={(e) => setRequestReason(e.target.value)}
              />
            </>
          )}
        </DialogContent>
        {!requestSent && (
          <DialogActions sx={{ px: 3, pb: 2 }}>
            <Button onClick={() => setShowRequestDialog(false)}>Hủy</Button>
            <Button 
              variant="contained" 
              onClick={handleRequestTime}
              disabled={!requestReason.trim()}
            >
              Gửi yêu cầu
            </Button>
          </DialogActions>
        )}
      </Dialog>
    </Box>
  );
}

export default ChildDashboard;