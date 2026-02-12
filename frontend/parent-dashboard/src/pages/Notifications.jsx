import { useState, useEffect } from 'react';
import {
  Box,
  Card,
  CardContent,
  Typography,
  Button,
  Avatar,
  Chip,
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  TextField,
  Alert,
  Snackbar,
} from '@mui/material';
import {
  Notifications as NotificationsIcon,
  MoreTime as MoreTimeIcon,
  Check as CheckIcon,
  Close as CloseIcon,
} from '@mui/icons-material';
import socketService from '../services/socketService';
import authService from '../services/authService';

function Notifications() {
  const [requests, setRequests] = useState([]);
  const [selectedRequest, setSelectedRequest] = useState(null);
  const [responseDialog, setResponseDialog] = useState(false);
  const [additionalMinutes, setAdditionalMinutes] = useState(30);
  const [snackbar, setSnackbar] = useState({ open: false, message: '', severity: 'success' });

  const user = authService.getCurrentUser();

  useEffect(() => {
    // Kết nối Socket
    socketService.connect(user?.id);

    // Lắng nghe yêu cầu từ Child
    socketService.onTimeExtensionRequest((data) => {
      setRequests((prev) => [data, ...prev]);
      setSnackbar({
        open: true,
        message: `${data.deviceName} xin thêm thời gian!`,
        severity: 'info',
      });
    });

    return () => {
      socketService.disconnect();
    };
  }, [user?.id]);

  const handleApprove = () => {
    socketService.respondTimeExtension(
      user?.id,
      true,
      additionalMinutes,
      `Đã duyệt thêm ${additionalMinutes} phút`
    );

    // Cập nhật UI
    setRequests((prev) =>
      prev.map((r) =>
        r.id === selectedRequest.id ? { ...r, status: 'approved', additionalMinutes } : r
      )
    );

    setResponseDialog(false);
    setSelectedRequest(null);
    setSnackbar({
      open: true,
      message: `Đã duyệt thêm ${additionalMinutes} phút!`,
      severity: 'success',
    });
  };

  const handleReject = (request) => {
    socketService.respondTimeExtension(user?.id, false, 0, 'Yêu cầu bị từ chối');

    // Cập nhật UI
    setRequests((prev) =>
      prev.map((r) => (r.id === request.id ? { ...r, status: 'rejected' } : r))
    );

    setSnackbar({
      open: true,
      message: 'Đã từ chối yêu cầu',
      severity: 'warning',
    });
  };

  const openApproveDialog = (request) => {
    setSelectedRequest(request);
    setAdditionalMinutes(30);
    setResponseDialog(true);
  };

  const formatTime = (isoString) => {
    return new Date(isoString).toLocaleTimeString('vi-VN', {
      hour: '2-digit',
      minute: '2-digit',
    });
  };

  return (
    <Box>
      <Typography variant="h4" sx={{ mb: 3 }}>
        Thông báo
      </Typography>

      {requests.length === 0 ? (
        <Card>
          <CardContent sx={{ textAlign: 'center', py: 6 }}>
            <NotificationsIcon sx={{ fontSize: 64, color: 'text.secondary', mb: 2 }} />
            <Typography variant="h6" color="text.secondary" gutterBottom>
              Chưa có thông báo nào
            </Typography>
            <Typography color="text.secondary">
              Các yêu cầu từ con sẽ hiển thị ở đây
            </Typography>
          </CardContent>
        </Card>
      ) : (
        <Box sx={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
          {requests.map((request) => (
            <Card key={request.id}>
              <CardContent>
                <Box sx={{ display: 'flex', alignItems: 'flex-start', gap: 2 }}>
                  <Avatar sx={{ bgcolor: 'primary.main' }}>
                    <MoreTimeIcon />
                  </Avatar>
                  <Box sx={{ flex: 1 }}>
                    <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, mb: 1 }}>
                      <Typography variant="h6">Xin thêm thời gian</Typography>
                      {request.status === 'approved' && (
                        <Chip label="Đã duyệt" color="success" size="small" />
                      )}
                      {request.status === 'rejected' && (
                        <Chip label="Đã từ chối" color="error" size="small" />
                      )}
                    </Box>
                    <Typography color="text.secondary" gutterBottom>
                      <strong>{request.deviceName}</strong> • {formatTime(request.timestamp)}
                    </Typography>
                    <Box sx={{ bgcolor: 'grey.100', p: 2, borderRadius: 2, mt: 1 }}>
                      <Typography variant="body2">
                        <strong>Lý do:</strong> {request.reason}
                      </Typography>
                    </Box>

                    {!request.status && (
                      <Box sx={{ display: 'flex', gap: 1, mt: 2 }}>
                        <Button
                          variant="contained"
                          color="success"
                          startIcon={<CheckIcon />}
                          onClick={() => openApproveDialog(request)}
                        >
                          Duyệt
                        </Button>
                        <Button
                          variant="outlined"
                          color="error"
                          startIcon={<CloseIcon />}
                          onClick={() => handleReject(request)}
                        >
                          Từ chối
                        </Button>
                      </Box>
                    )}

                    {request.status === 'approved' && (
                      <Typography color="success.main" sx={{ mt: 1 }}>
                        ✓ Đã thêm {request.additionalMinutes} phút
                      </Typography>
                    )}
                  </Box>
                </Box>
              </CardContent>
            </Card>
          ))}
        </Box>
      )}

      {/* Dialog duyệt yêu cầu */}
      <Dialog open={responseDialog} onClose={() => setResponseDialog(false)}>
        <DialogTitle>Duyệt yêu cầu thêm thời gian</DialogTitle>
        <DialogContent>
          <Typography sx={{ mb: 2 }}>
            Bạn muốn cho <strong>{selectedRequest?.deviceName}</strong> thêm bao nhiêu phút?
          </Typography>
          <TextField
            fullWidth
            type="number"
            label="Số phút thêm"
            value={additionalMinutes}
            onChange={(e) => setAdditionalMinutes(Number(e.target.value))}
            inputProps={{ min: 5, max: 120 }}
          />
        </DialogContent>
        <DialogActions sx={{ px: 3, pb: 2 }}>
          <Button onClick={() => setResponseDialog(false)}>Hủy</Button>
          <Button variant="contained" color="success" onClick={handleApprove}>
            Duyệt
          </Button>
        </DialogActions>
      </Dialog>

      {/* Snackbar */}
      <Snackbar
        open={snackbar.open}
        autoHideDuration={3000}
        onClose={() => setSnackbar({ ...snackbar, open: false })}
        anchorOrigin={{ vertical: 'bottom', horizontal: 'right' }}
      >
        <Alert severity={snackbar.severity}>{snackbar.message}</Alert>
      </Snackbar>
    </Box>
  );
}

export default Notifications;