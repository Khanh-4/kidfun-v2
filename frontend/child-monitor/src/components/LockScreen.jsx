import { Box, Typography, Button, Avatar } from '@mui/material';
import {
    Lock as LockIcon,
    MoreTime as MoreTimeIcon,
    LinkOff as LinkOffIcon,
} from '@mui/icons-material';

function LockScreen({ device, onRequestTime, onUnlink }) {
    return (
        <Box
            sx={{
                position: 'fixed',
                top: 0,
                left: 0,
                right: 0,
                bottom: 0,
                zIndex: 9999,
                bgcolor: 'rgba(99, 102, 241, 0.95)',
                backdropFilter: 'blur(10px)',
                display: 'flex',
                flexDirection: 'column',
                alignItems: 'center',
                justifyContent: 'center',
                color: 'white',
                textAlign: 'center',
                p: 3,
            }}
        >
            <Avatar
                sx={{
                    width: 120,
                    height: 120,
                    bgcolor: 'rgba(255, 255, 255, 0.2)',
                    mb: 3,
                    animation: 'pulse 2s ease-in-out infinite',
                    '@keyframes pulse': {
                        '0%, 100%': { transform: 'scale(1)' },
                        '50%': { transform: 'scale(1.05)' },
                    },
                }}
            >
                <LockIcon sx={{ fontSize: 60 }} />
            </Avatar>

            <Typography
                variant="h3"
                fontWeight={700}
                gutterBottom
                sx={{
                    fontSize: { xs: '2rem', sm: '3rem' },
                }}
            >
                Hết giờ rồi bạn ơi! ⏰
            </Typography>

            <Typography
                variant="h6"
                sx={{
                    mb: 4,
                    opacity: 0.9,
                    maxWidth: 500,
                    fontSize: { xs: '1rem', sm: '1.25rem' },
                }}
            >
                Bạn đã hết thời gian sử dụng hôm nay.
                <br />
                Hãy nghỉ ngơi và quay lại vào ngày mai nhé! 😊
            </Typography>

            <Box
                sx={{
                    display: 'flex',
                    gap: 2,
                    flexDirection: 'column',
                    width: '100%',
                    maxWidth: 300,
                }}
            >
                <Button
                    variant="contained"
                    size="large"
                    color="warning"
                    startIcon={<MoreTimeIcon />}
                    onClick={onRequestTime}
                    sx={{
                        py: 2,
                        borderRadius: 3,
                        fontSize: '1.1rem',
                        fontWeight: 600,
                        boxShadow: '0 4px 12px rgba(0,0,0,0.2)',
                        '&:hover': {
                            transform: 'translateY(-2px)',
                            boxShadow: '0 6px 16px rgba(0,0,0,0.3)',
                        },
                        transition: 'all 0.2s',
                    }}
                >
                    Xin bố mẹ thêm giờ
                </Button>

                <Button
                    variant="outlined"
                    size="small"
                    color="inherit"
                    startIcon={<LinkOffIcon />}
                    onClick={onUnlink}
                    sx={{
                        borderColor: 'rgba(255,255,255,0.5)',
                        color: 'white',
                        '&:hover': {
                            borderColor: 'white',
                            bgcolor: 'rgba(255,255,255,0.1)',
                        },
                    }}
                >
                    Đăng xuất
                </Button>
            </Box>

            {device && (
                <Typography
                    variant="body2"
                    sx={{
                        mt: 4,
                        opacity: 0.7,
                        fontSize: '0.9rem',
                    }}
                >
                    Thiết bị: {device.deviceName}
                </Typography>
            )}
        </Box>
    );
}

export default LockScreen;
