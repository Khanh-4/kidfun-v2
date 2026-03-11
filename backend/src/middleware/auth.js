const jwt = require('jsonwebtoken');

const authenticate = (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;

    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({ success: false, message: 'Access token required', code: 'MISSING_TOKEN' });
    }

    const token = authHeader.split(' ')[1];
    const decoded = jwt.verify(token, process.env.JWT_SECRET);

    req.user = decoded;
    next();
  } catch (error) {
    if (error.name === 'TokenExpiredError') {
      return res.status(401).json({ success: false, message: 'Token expired', code: 'TOKEN_EXPIRED' });
    }
    return res.status(401).json({ success: false, message: 'Invalid token', code: 'INVALID_TOKEN' });
  }
};

const authorizeParent = (req, res, next) => {
  if (req.user.role !== 'PARENT') {
    return res.status(403).json({ success: false, message: 'Parent access required', code: 'FORBIDDEN' });
  }
  next();
};

module.exports = { authenticate, authorizeParent };
