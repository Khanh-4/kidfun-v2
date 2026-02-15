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
    Snackbar,
    Alert,
    CircularProgress,
} from '@mui/material';
import {
    Timer as TimerIcon,
    Warning as WarningIcon,
    MoreTime as MoreTimeIcon,
    EmojiEvents as TrophyIcon,
    LinkOff as LinkOffIcon,
} from '@mui/icons-material';
import api from '../services/api';
import socketService from '../services/socketService';
import LockScreen from '../components/LockScreen';

function ChildDashboard({ device }) {
    // State management
    const [status, setStatus] = useState(null);
    const [timeRemaining, setTimeRemaining] = useState(0); // in seconds
    const [isLocked, setIsLocked] = useState(false);
    const [sessionId, setSessionId] = useState(null);
    const [lastWarning, setLastWarning] = useState(null);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState(null);

    // UI state
    const [showWarning, setShowWarning] = useState(false);
    const [warningLevel, setWarningLevel] = useState('warning'); // 'info', 'warning', 'error'
    const [showRequestDialog, setShowRequestDialog] = useState(false);
    const [requestReason, setRequestReason] = useState('');
    const [requestSent, setRequestSent] = useState(false);
    const [snackbar, setSnackbar] = useState({ open: false, message: '', severity: 'success' });

    // Derived values — use effectiveLimit (dailyLimit + bonus) for progress bar
    const effectiveLimit = status
        ? status.timeLimit.dailyLimitMinutes + (status.timeLimit.bonusMinutes || 0)
        : 120;
    const timeUsedMinutes = status
        ? status.usageToday.totalMinutes
        : 0;
    const progressPercent = effectiveLimit > 0
        ? Math.min(100, (timeUsedMinutes / effectiveLimit) * 100)
        : 0;

    // useEffect 1: Load initial status
    useEffect(() => {
        const loadStatus = async () => {
            try {
                setLoading(true);
                setError(null);

                const response = await api.get('/child/status');
                setStatus(response.data);
                setTimeRemaining(response.data.remainingMinutes * 60); // convert to seconds

                // Start session if not active
                if (!response.data.activeSession) {
                    const sessionRes = await api.post('/child/session/start', {
                        appName: 'KidFun Monitor'
                    });
                    setSessionId(sessionRes.data.session.id);
                } else {
                    setSessionId(response.data.activeSession.id);
                }

                setLoading(false);
            } catch (err) {
                console.error('Load status error:', err);
                setError(err.response?.data?.message || 'Không thể tải thông tin. Vui lòng thử lại.');
                setLoading(false);
            }
        };

        loadStatus();
    }, []);

    // useEffect 2: Countdown timer (mỗi giây)
    useEffect(() => {
        if (!status || timeRemaining <= 0) {
            if (timeRemaining <= 0 && status) {
                setIsLocked(true);
            }
            return;
        }

        const timer = setInterval(() => {
            setTimeRemaining((prev) => {
                const newValue = Math.max(0, prev - 1);
                if (newValue === 0) {
                    setIsLocked(true);
                }
                return newValue;
            });
        }, 1000);

        return () => clearInterval(timer);
    }, [status, timeRemaining]);

    // useEffect 3: Heartbeat (mỗi 60 giây)
    useEffect(() => {
        if (!sessionId || !status) return;

        const interval = setInterval(async () => {
            try {
                const elapsedMinutes = Math.floor(
                    (effectiveLimit * 60 - timeRemaining) / 60
                );

                const response = await api.post('/child/session/heartbeat', {
                    sessionId,
                    elapsedMinutes
                });

                // Update remaining time from server (để sync)
                if (response.data.remainingMinutes !== undefined) {
                    setTimeRemaining(response.data.remainingMinutes * 60);
                }
            } catch (err) {
                console.error('Heartbeat error:', err);
            }
        }, 60000); // 60 seconds

        return () => clearInterval(interval);
    }, [sessionId, status, timeRemaining, effectiveLimit]);

    // useEffect 4: Warning triggers
    useEffect(() => {
        if (!status || timeRemaining <= 0) return;

        const minutes = Math.floor(timeRemaining / 60);

        // 30 phút warning
        if (minutes === 30 && lastWarning !== 30) {
            setLastWarning(30);
            setWarningLevel('info');
            setShowWarning(true);
            api.post('/child/warnings', {
                warningType: 'TIME_WARNING_30',
                message: 'Còn 30 phút sử dụng hôm nay',
                remainingMinutes: 30
            }).catch(err => console.error('Warning log error:', err));
        }

        // 15 phút warning
        if (minutes === 15 && lastWarning !== 15) {
            setLastWarning(15);
            setWarningLevel('warning');
            setShowWarning(true);
            api.post('/child/warnings', {
                warningType: 'TIME_WARNING_15',
                message: 'Còn 15 phút sử dụng hôm nay',
                remainingMinutes: 15
            }).catch(err => console.error('Warning log error:', err));
        }

        // 5 phút warning
        if (minutes === 5 && lastWarning !== 5) {
            setLastWarning(5);
            setWarningLevel('error');
            setShowWarning(true);
            api.post('/child/warnings', {
                warningType: 'TIME_WARNING_5',
                message: 'Còn 5 phút sử dụng hôm nay',
                remainingMinutes: 5
            }).catch(err => console.error('Warning log error:', err));
        }
    }, [timeRemaining, lastWarning, status]);

    // useEffect 5: Cleanup on unmount
    useEffect(() => {
        return () => {
            if (sessionId) {
                api.post('/child/session/end', {
                    sessionId,
                    reason: 'APP_CLOSED'
                }).catch(err => console.error('End session error:', err));
            }
        };
    }, [sessionId]);

    // useEffect 6: Socket listeners
    useEffect(() => {
        if (!status?.device.userId) return;

        socketService.connect(status.device.userId);

        socketService.onDeviceRemoved(() => {
            localStorage.removeItem('deviceCode');
            localStorage.removeItem('device');
            window.location.reload();
        });

        socketService.onTimeExtensionResponse((data) => {
            if (data.approved) {
                // Persist bonus to backend
                api.post('/child/bonus', {
                    additionalMinutes: data.additionalMinutes
                }).catch(err => console.error('Save bonus error:', err));

                // Update remaining time: add only the bonus minutes
                setTimeRemaining((prev) => prev + data.additionalMinutes * 60);
                setIsLocked(false);

                // Update status so progress bar reflects bonus
                setStatus((prev) => prev ? {
                    ...prev,
                    timeLimit: {
                        ...prev.timeLimit,
                        bonusMinutes: (prev.timeLimit.bonusMinutes || 0) + data.additionalMinutes
                    }
                } : prev);

                setSnackbar({
                    open: true,
                    message: `Bố mẹ đã duyệt thêm ${data.additionalMinutes} phút!`,
                    severity: 'success',
                });
            } else {
                setSnackbar({
                    open: true,
                    message: 'Bố mẹ đã từ chối yêu cầu',
                    severity: 'warning',
                });
            }
        });

        return () => {
            socketService.disconnect();
        };
    }, [status?.device.userId]);

    // Handlers
    const formatTime = (seconds) => {
        const hours = Math.floor(seconds / 3600);
        const mins = Math.floor((seconds % 3600) / 60);
        const secs = seconds % 60;

        if (hours > 0) {
            return `${hours} giờ ${mins} phút`;
        }
        if (mins > 0) {
            return `${mins} phút ${secs} giây`;
        }
        return `${secs} giây`;
    };

    const handleRequestTime = () => {
        socketService.requestTimeExtension(
            status.device.userId,
            status.device.deviceName,
            requestReason,
            30
        );

        setRequestSent(true);
        setTimeout(() => {
            setShowRequestDialog(false);
            setRequestSent(false);
            setRequestReason('');
        }, 2000);
    };

    const handleUnlink = () => {
        if (window.confirm('Bạn có chắc muốn hủy liên kết thiết bị này?')) {
            if (sessionId) {
                api.post('/child/session/end', {
                    sessionId,
                    reason: 'UNLINK'
                }).catch(err => console.error('End session error:', err));
            }
            localStorage.removeItem('deviceCode');
            localStorage.removeItem('device');
            window.location.reload();
        }
    };

    const getStatusColor = () => {
        if (progressPercent >= 90) return 'error';
        if (progressPercent >= 70) return 'warning';
        return 'success';
    };

    const getWarningMessage = () => {
        const minutes = Math.floor(timeRemaining / 60);
        if (minutes === 30) return 'Bạn còn 30 phút sử dụng hôm nay!';
        if (minutes === 15) return 'Sắp hết thời gian rồi! Còn 15 phút.';
        if (minutes === 5) return 'Khẩn cấp! Chỉ còn 5 phút nữa!';
        return `Bạn còn ${minutes} phút sử dụng hôm nay.`;
    };

    // Loading state
    if (loading) {
        return (
            <Box
                sx={{
                    minHeight: '100vh',
                    background: 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    flexDirection: 'column',
                    gap: 2,
                    color: 'white',
                }}
            >
                <CircularProgress size={60} sx={{ color: 'white' }} />
                <Typography variant="h6">Đang tải...</Typography>
            </Box>
        );
    }

    // Error state
    if (error) {
        return (
            <Box
                sx={{
                    minHeight: '100vh',
                    background: 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    flexDirection: 'column',
                    gap: 2,
                    color: 'white',
                    p: 3,
                    textAlign: 'center',
                }}
            >
                <WarningIcon sx={{ fontSize: 80 }} />
                <Typography variant="h5" fontWeight={600}>
                    Có lỗi xảy ra
                </Typography>
                <Typography variant="body1" sx={{ maxWidth: 400 }}>
                    {error}
                </Typography>
                <Button
                    variant="contained"
                    color="warning"
                    onClick={() => window.location.reload()}
                    sx={{ mt: 2 }}
                >
                    Thử lại
                </Button>
            </Box>
        );
    }

    return (
        <Box
            sx={{
                minHeight: '100vh',
                background: 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)',
                p: 2,
            }}
        >
            {/* Lock Screen Overlay */}
            {isLocked && (
                <LockScreen
                    device={status?.device}
                    onRequestTime={() => setShowRequestDialog(true)}
                    onUnlink={handleUnlink}
                />
            )}

            {/* Header */}
            <Box sx={{ textAlign: 'center', color: 'white', mb: 3, pt: 2 }}>
                <Typography variant="h4" fontWeight={700}>
                    🎮 KidFun
                </Typography>
                <Chip
                    label={status?.profile?.profileName || 'Đang tải...'}
                    sx={{
                        mt: 1,
                        bgcolor: 'rgba(255,255,255,0.2)',
                        color: 'white',
                        fontWeight: 600,
                    }}
                />
            </Box>

            {/* Main Time Card */}
            <Card sx={{ maxWidth: 400, mx: 'auto', borderRadius: 4, mb: 3 }}>
                <CardContent sx={{ p: 4, textAlign: 'center' }}>
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

                    <Typography variant="h3" fontWeight={700} color={`${getStatusColor()}.main`}>
                        {formatTime(timeRemaining)}
                    </Typography>
                    <Typography color="text.secondary" gutterBottom>
                        Thời gian còn lại hôm nay
                    </Typography>

                    <Box sx={{ mt: 3, mb: 2 }}>
                        <LinearProgress
                            variant="determinate"
                            value={progressPercent}
                            color={getStatusColor()}
                            sx={{ height: 12, borderRadius: 6 }}
                        />
                        <Box sx={{ display: 'flex', justifyContent: 'space-between', mt: 1 }}>
                            <Typography variant="caption" color="text.secondary">
                                Đã dùng: {Math.floor(timeUsedMinutes)} phút
                            </Typography>
                            <Typography variant="caption" color="text.secondary">
                                Giới hạn: {effectiveLimit} phút
                            </Typography>
                        </Box>
                    </Box>

                    <Button
                        variant="outlined"
                        startIcon={<MoreTimeIcon />}
                        onClick={() => setShowRequestDialog(true)}
                        sx={{ mt: 2, borderRadius: 2 }}
                    >
                        Xin thêm thời gian
                    </Button>
                    <Button
                        variant="text"
                        color="error"
                        startIcon={<LinkOffIcon />}
                        onClick={handleUnlink}
                        sx={{ mt: 1 }}
                        size="small"
                    >
                        Hủy liên kết
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
                                Hãy tiếp tục tuân thủ giới hạn nhé!
                            </Typography>
                        </Box>
                    </Box>
                </CardContent>
            </Card>

            {/* Warning Dialog */}
            <Dialog open={showWarning} onClose={() => setShowWarning(false)}>
                <DialogTitle sx={{ textAlign: 'center', pt: 3 }}>
                    <WarningIcon color={warningLevel} sx={{ fontSize: 48 }} />
                    <Typography variant="h6" sx={{ mt: 1 }}>
                        {warningLevel === 'error'
                            ? 'Khẩn cấp!'
                            : warningLevel === 'warning'
                            ? 'Sắp hết thời gian!'
                            : 'Thông báo'}
                    </Typography>
                </DialogTitle>
                <DialogContent>
                    <Typography textAlign="center">
                        {getWarningMessage()}
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
                onClose={() => !requestSent && setShowRequestDialog(false)}
                maxWidth="sm"
                fullWidth
                sx={{ zIndex: 10000 }}
            >
                <DialogTitle>
                    <MoreTimeIcon sx={{ mr: 1, verticalAlign: 'middle' }} />
                    Xin thêm thời gian
                </DialogTitle>
                <DialogContent>
                    {requestSent ? (
                        <Box sx={{ textAlign: 'center', py: 3 }}>
                            <Typography variant="h6" color="success.main">
                                Đã gửi yêu cầu!
                            </Typography>
                            <Typography color="text.secondary">Chờ bố mẹ phê duyệt nhé!</Typography>
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

            {/* Snackbar */}
            <Snackbar
                open={snackbar.open}
                autoHideDuration={4000}
                onClose={() => setSnackbar({ ...snackbar, open: false })}
                anchorOrigin={{ vertical: 'top', horizontal: 'center' }}
                sx={{ zIndex: 10001 }}
            >
                <Alert severity={snackbar.severity} sx={{ width: '100%' }}>
                    {snackbar.message}
                </Alert>
            </Snackbar>
        </Box>
    );
}

export default ChildDashboard;
