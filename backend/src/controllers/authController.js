const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { PrismaClient } = require('@prisma/client');

const prisma = new PrismaClient();

// Tạo JWT token
const generateToken = (user) => {
  return jwt.sign(
    { userId: user.id, email: user.email },
    process.env.JWT_SECRET,
    { expiresIn: process.env.JWT_EXPIRES_IN || '24h' }
  );
};

// POST /api/auth/register
const register = async (req, res) => {
  try {
    const { email, password, fullName, phoneNumber } = req.body;

    // Kiểm tra email đã tồn tại
    const existingUser = await prisma.user.findUnique({ where: { email } });
    if (existingUser) {
      return res.status(400).json({ error: 'Email already registered' });
    }

    // Hash password
    const passwordHash = await bcrypt.hash(password, 10);

    // Tạo user mới
    const user = await prisma.user.create({
      data: {
        email,
        passwordHash,
        fullName,
        phoneNumber
      },
      select: {
        id: true,
        email: true,
        fullName: true,
        phoneNumber: true,
        createdAt: true
      }
    });

    const token = generateToken(user);

    res.status(201).json({
      message: 'Registration successful',
      user,
      token
    });
  } catch (error) {
    console.error('Register error:', error);
    res.status(500).json({ error: 'Registration failed' });
  }
};

// POST /api/auth/login
const login = async (req, res) => {
  try {
    const { email, password } = req.body;

    // Tìm user
    const user = await prisma.user.findUnique({ where: { email } });
    if (!user) {
      return res.status(401).json({ error: 'Invalid email or password' });
    }

    // Kiểm tra password
    const isValidPassword = await bcrypt.compare(password, user.passwordHash);
    if (!isValidPassword) {
      return res.status(401).json({ error: 'Invalid email or password' });
    }

    const token = generateToken(user);

    res.json({
      message: 'Login successful',
      user: {
        id: user.id,
        email: user.email,
        fullName: user.fullName,
        phoneNumber: user.phoneNumber
      },
      token
    });
  } catch (error) {
    console.error('Login error:', error);
    res.status(500).json({ error: 'Login failed' });
  }
};

// POST /api/auth/refresh
const refreshToken = async (req, res) => {
  try {
    const { userId } = req.user;
    
    const user = await prisma.user.findUnique({ where: { id: userId } });
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    const token = generateToken(user);
    res.json({ token });
  } catch (error) {
    console.error('Refresh token error:', error);
    res.status(500).json({ error: 'Token refresh failed' });
  }
};

// POST /api/auth/logout
const logout = async (req, res) => {
  // Với JWT stateless, logout chủ yếu xử lý ở client
  res.json({ message: 'Logout successful' });
};

// PUT /api/auth/profile - Cập nhật thông tin cá nhân
const updateProfile = async (req, res) => {
  try {
    const { fullName, phoneNumber } = req.body;
    const userId = req.user.userId;

    const user = await prisma.user.update({
      where: { id: userId },
      data: {
        fullName,
        phoneNumber,
      },
      select: {
        id: true,
        email: true,
        fullName: true,
        phoneNumber: true,
      },
    });

    res.json({
      message: 'Profile updated successfully',
      user,
    });
  } catch (error) {
    console.error('Update profile error:', error);
    res.status(500).json({ error: 'Failed to update profile' });
  }
};

// PUT /api/auth/change-password - Đổi mật khẩu
const changePassword = async (req, res) => {
  try {
    const { currentPassword, newPassword } = req.body;
    const userId = req.user.userId;

    // Lấy user hiện tại
    const user = await prisma.user.findUnique({ where: { id: userId } });
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    // Kiểm tra mật khẩu hiện tại
    const isValidPassword = await bcrypt.compare(currentPassword, user.passwordHash);
    if (!isValidPassword) {
      return res.status(400).json({ error: 'Mật khẩu hiện tại không đúng' });
    }

    // Hash mật khẩu mới
    const newPasswordHash = await bcrypt.hash(newPassword, 10);

    // Cập nhật mật khẩu
    await prisma.user.update({
      where: { id: userId },
      data: { passwordHash: newPasswordHash },
    });

    res.json({ message: 'Password changed successfully' });
  } catch (error) {
    console.error('Change password error:', error);
    res.status(500).json({ error: 'Failed to change password' });
  }
};

module.exports = {
  register,
  login,
  refreshToken,
  logout,
  updateProfile,
  changePassword,
};