import { useNavigate, useLocation } from 'react-router-dom';
import {
  Box,
  Drawer,
  AppBar,
  Toolbar,
  List,
  Typography,
  Divider,
  IconButton,
  ListItem,
  ListItemButton,
  ListItemIcon,
  ListItemText,
  Avatar,
  Menu,
  MenuItem,
  Badge,
  Button,
} from '@mui/material';
import {
  Menu as MenuIcon,
  Dashboard as DashboardIcon,
  People as PeopleIcon,
  Devices as DevicesIcon,
  Assessment as AssessmentIcon,
  Logout as LogoutIcon,
  Person as PersonIcon,
  Notifications as NotificationsIcon,
  Timer as TimerIcon,
  Block as BlockIcon,
  History as HistoryIcon,
} from '@mui/icons-material';
import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import authService from '../../services/authService';

function Sidebar({ drawerWidth, mobileOpen, handleDrawerToggle, unreadCount = 0 }) {
  const { t, i18n } = useTranslation();
  const navigate = useNavigate();
  const location = useLocation();
  const user = authService.getCurrentUser();
  const [anchorEl, setAnchorEl] = useState(null);

  const menuItems = [
    { text: t('sidebar.dashboard'), icon: <DashboardIcon />, path: '/' },
    { text: t('sidebar.profiles'), icon: <PeopleIcon />, path: '/profiles' },
    { text: t('sidebar.devices'), icon: <DevicesIcon />, path: '/devices' },
    { text: t('sidebar.timeSettings'), icon: <TimerIcon />, path: '/time-settings' },
    { text: t('sidebar.blockedSites'), icon: <BlockIcon />, path: '/blocked-sites' },
    { text: t('sidebar.notifications'), icon: <NotificationsIcon />, path: '/notifications' },
    { text: t('sidebar.activityHistory'), icon: <HistoryIcon />, path: '/activity-history' },
    { text: t('sidebar.reports'), icon: <AssessmentIcon />, path: '/reports' },
  ];

  const handleMenuOpen = (event) => {
    setAnchorEl(event.currentTarget);
  };

  const handleMenuClose = () => {
    setAnchorEl(null);
  };

  const handleLogout = () => {
    authService.logout();
    navigate('/login');
  };

  const toggleLanguage = () => {
    const newLng = i18n.language === 'vi' ? 'en' : 'vi';
    i18n.changeLanguage(newLng);
    localStorage.setItem('language', newLng);
  };

  const drawer = (
    <Box sx={{ height: '100%', display: 'flex', flexDirection: 'column' }}>
      {/* Logo */}
      <Box sx={{ p: 3, textAlign: 'center' }}>
        <Typography
          variant="h5"
          sx={{
            fontWeight: 700,
            background: 'linear-gradient(45deg, #6366f1, #f472b6)',
            backgroundClip: 'text',
            WebkitBackgroundClip: 'text',
            WebkitTextFillColor: 'transparent',
          }}
        >
          🎯 KidFun
        </Typography>
        <Typography variant="caption" color="text.secondary">
          {t('sidebar.parentDashboard')}
        </Typography>
      </Box>

      <Divider />

      {/* Menu items */}
      <List sx={{ flex: 1, px: 2, py: 1 }}>
        {menuItems.map((item) => (
          <ListItem key={item.path} disablePadding sx={{ mb: 0.5 }}>
            <ListItemButton
              onClick={() => navigate(item.path)}
              selected={location.pathname === item.path}
              sx={{
                borderRadius: 2,
                '&.Mui-selected': {
                  bgcolor: 'primary.main',
                  color: 'white',
                  '&:hover': {
                    bgcolor: 'primary.dark',
                  },
                  '& .MuiListItemIcon-root': {
                    color: 'white',
                  },
                },
              }}
            >
              <ListItemIcon sx={{ minWidth: 40 }}>
                {item.path === '/notifications' && unreadCount > 0 ? (
                  <Badge badgeContent={unreadCount} color="error">{item.icon}</Badge>
                ) : item.icon}
              </ListItemIcon>
              <ListItemText primary={item.text} />
            </ListItemButton>
          </ListItem>
        ))}
      </List>

      <Divider />

      {/* User info */}
      <Box sx={{ p: 2 }}>
        <ListItemButton onClick={handleMenuOpen} sx={{ borderRadius: 2 }}>
          <Avatar sx={{ width: 32, height: 32, mr: 1.5, bgcolor: 'primary.main' }}>
            {user?.fullName?.charAt(0) || 'U'}
          </Avatar>
          <Box sx={{ overflow: 'hidden' }}>
            <Typography variant="body2" fontWeight={500} noWrap>
              {user?.fullName || 'User'}
            </Typography>
            <Typography variant="caption" color="text.secondary" noWrap>
              {user?.email || ''}
            </Typography>
          </Box>
        </ListItemButton>
      </Box>
    </Box>
  );

  return (
    <>
      {/* AppBar for mobile */}
      <AppBar
        position="fixed"
        sx={{
          width: { sm: `calc(100% - ${drawerWidth}px)` },
          ml: { sm: `${drawerWidth}px` },
          bgcolor: 'background.paper',
          color: 'text.primary',
          boxShadow: 1,
        }}
      >
        <Toolbar>
          <IconButton
            color="inherit"
            edge="start"
            onClick={handleDrawerToggle}
            sx={{ mr: 2, display: { sm: 'none' } }}
          >
            <MenuIcon />
          </IconButton>
          <Typography variant="h6" noWrap component="div" sx={{ flexGrow: 1 }}>
            {menuItems.find((item) => item.path === location.pathname)?.text || 'KidFun'}
          </Typography>
          <Button
            size="small"
            variant="outlined"
            onClick={toggleLanguage}
            sx={{ minWidth: 40, px: 1, fontWeight: 700, fontSize: '0.75rem' }}
          >
            {i18n.language === 'vi' ? 'EN' : 'VI'}
          </Button>
        </Toolbar>
      </AppBar>

      {/* Sidebar drawer */}
      <Box
        component="nav"
        sx={{ width: { sm: drawerWidth }, flexShrink: { sm: 0 } }}
      >
        {/* Mobile drawer */}
        <Drawer
          variant="temporary"
          open={mobileOpen}
          onClose={handleDrawerToggle}
          ModalProps={{ keepMounted: true }}
          sx={{
            display: { xs: 'block', sm: 'none' },
            '& .MuiDrawer-paper': {
              boxSizing: 'border-box',
              width: drawerWidth,
            },
          }}
        >
          {drawer}
        </Drawer>

        {/* Desktop drawer */}
        <Drawer
          variant="permanent"
          sx={{
            display: { xs: 'none', sm: 'block' },
            '& .MuiDrawer-paper': {
              boxSizing: 'border-box',
              width: drawerWidth,
              borderRight: '1px solid',
              borderColor: 'divider',
            },
          }}
          open
        >
          {drawer}
        </Drawer>
      </Box>

      {/* User menu */}
      <Menu
        anchorEl={anchorEl}
        open={Boolean(anchorEl)}
        onClose={handleMenuClose}
        transformOrigin={{ horizontal: 'left', vertical: 'top' }}
        anchorOrigin={{ horizontal: 'left', vertical: 'bottom' }}
      >
        <MenuItem onClick={() => { handleMenuClose(); navigate('/account'); }}>
          <ListItemIcon>
            <PersonIcon fontSize="small" />
          </ListItemIcon>
          {t('sidebar.account')}
        </MenuItem>
        <MenuItem onClick={handleLogout}>
          <ListItemIcon>
            <LogoutIcon fontSize="small" />
          </ListItemIcon>
          {t('sidebar.logout')}
        </MenuItem>
      </Menu>
    </>
  );
}

export default Sidebar;
