import { useState } from 'react';
import { useOutletContext } from 'react-router-dom';
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
import { useTranslation } from 'react-i18next';
import api from '../services/api';
import socketService from '../services/socketService';

function Notifications() {
  const { t } = useTranslation();
  const { requests, setRequests } = useOutletContext();
  const [selectedRequest, setSelectedRequest] = useState(null);
  const [responseDialog, setResponseDialog] = useState(false);
  const [additionalMinutes, setAdditionalMinutes] = useState(30);
  const [snackbar, setSnackbar] = useState({ open: false, message: '', severity: 'success' });

  const handleApprove = async () => {
    if (!selectedRequest) return;

    try {
      // Use REST API for approve (writes to DB + emits socket to child)
      await api.put(`/extension-requests/${selectedRequest.id}/approve`, {
        responseMinutes: additionalMinutes,
      });

      setRequests((prev) =>
        prev.map((r) =>
          r.id === selectedRequest.id
            ? { ...r, status: 'approved', responseMinutes: additionalMinutes }
            : r
        )
      );

      setResponseDialog(false);
      setSelectedRequest(null);
      setSnackbar({
        open: true,
        message: t('notifications.approvedMessage', { minutes: additionalMinutes }),
        severity: 'success',
      });
    } catch (err) {
      console.error('Approve extension error:', err);
      setSnackbar({
        open: true,
        message: err.response?.data?.message || t('common.error'),
        severity: 'error',
      });
    }
  };

  const handleReject = (request) => {
    // Use socket for reject (no REST endpoint for reject)
    socketService.respondTimeExtension(request.id, false, 0);

    setRequests((prev) =>
      prev.map((r) => (r.id === request.id ? { ...r, status: 'rejected' } : r))
    );

    setSnackbar({
      open: true,
      message: t('notifications.rejectedMessage'),
      severity: 'warning',
    });
  };

  const openApproveDialog = (request) => {
    setSelectedRequest(request);
    setAdditionalMinutes(request.requestMinutes || 30);
    setResponseDialog(true);
  };

  const formatTime = (isoString) => {
    if (!isoString) return '';
    return new Date(isoString).toLocaleTimeString('vi-VN', {
      hour: '2-digit',
      minute: '2-digit',
    });
  };

  return (
    <Box>
      <Typography variant="h4" sx={{ mb: 3 }}>
        {t('notifications.title')}
      </Typography>

      {requests.length === 0 ? (
        <Card>
          <CardContent sx={{ textAlign: 'center', py: 6 }}>
            <NotificationsIcon sx={{ fontSize: 64, color: 'text.secondary', mb: 2 }} />
            <Typography variant="h6" color="text.secondary" gutterBottom>
              {t('notifications.noNotifications')}
            </Typography>
            <Typography color="text.secondary">
              {t('notifications.noNotificationsDesc')}
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
                      <Typography variant="h6">
                        {request.profileName
                          ? `${request.profileName} - ${t('notifications.requestTime')}`
                          : t('notifications.requestTime')}
                      </Typography>
                      {request.status === 'approved' && (
                        <Chip label={t('notifications.approved')} color="success" size="small" />
                      )}
                      {request.status === 'rejected' && (
                        <Chip label={t('notifications.rejected')} color="error" size="small" />
                      )}
                    </Box>
                    <Typography color="text.secondary" gutterBottom>
                      <strong>{request.deviceName}</strong> • {formatTime(request.createdAt)}
                      {request.requestMinutes && ` • ${request.requestMinutes} ${t('dashboard.minuteUnit') || 'phút'}`}
                    </Typography>
                    {request.reason && (
                      <Box sx={{ bgcolor: 'grey.100', p: 2, borderRadius: 2, mt: 1 }}>
                        <Typography variant="body2">
                          <strong>{t('notifications.reason')}</strong> {request.reason}
                        </Typography>
                      </Box>
                    )}

                    {!request.status && (
                      <Box sx={{ display: 'flex', gap: 1, mt: 2 }}>
                        <Button
                          variant="contained"
                          color="success"
                          startIcon={<CheckIcon />}
                          onClick={() => openApproveDialog(request)}
                        >
                          {t('notifications.approve')}
                        </Button>
                        <Button
                          variant="outlined"
                          color="error"
                          startIcon={<CloseIcon />}
                          onClick={() => handleReject(request)}
                        >
                          {t('notifications.reject')}
                        </Button>
                      </Box>
                    )}

                    {request.status === 'approved' && (
                      <Typography color="success.main" sx={{ mt: 1 }}>
                        {t('notifications.addedMinutes', { minutes: request.responseMinutes })}
                      </Typography>
                    )}
                  </Box>
                </Box>
              </CardContent>
            </Card>
          ))}
        </Box>
      )}

      {/* Approve Dialog */}
      <Dialog open={responseDialog} onClose={() => setResponseDialog(false)}>
        <DialogTitle>{t('notifications.approveTitle')}</DialogTitle>
        <DialogContent>
          <Typography sx={{ mb: 2 }}>
            {t('notifications.approveQuestion', { device: selectedRequest?.deviceName }).replace('<1>', '').replace('</1>', '')}
          </Typography>
          <TextField
            fullWidth
            type="number"
            label={t('notifications.additionalMinutes')}
            value={additionalMinutes}
            onChange={(e) => setAdditionalMinutes(Number(e.target.value))}
            inputProps={{ min: 5, max: 120 }}
          />
        </DialogContent>
        <DialogActions sx={{ px: 3, pb: 2 }}>
          <Button onClick={() => setResponseDialog(false)}>{t('common.cancel')}</Button>
          <Button variant="contained" color="success" onClick={handleApprove}>
            {t('notifications.approve')}
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
