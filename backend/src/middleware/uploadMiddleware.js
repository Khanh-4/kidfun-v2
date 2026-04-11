const multer = require('multer');
const path = require('path');
const fs = require('fs');

const uploadDir = path.join(__dirname, '../../uploads/sos-audio');
if (!fs.existsSync(uploadDir)) fs.mkdirSync(uploadDir, { recursive: true });

const storage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, uploadDir),
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname) || '.m4a';
    cb(null, `sos_${Date.now()}${ext}`);
  },
});

const upload = multer({
  storage,
  limits: { fileSize: 5 * 1024 * 1024 }, // 5MB max
  fileFilter: (req, file, cb) => {
    const allowed = ['audio/mpeg', 'audio/mp4', 'audio/aac', 'audio/m4a', 'audio/x-m4a', 'audio/wav'];
    if (allowed.includes(file.mimetype)) cb(null, true);
    else cb(new Error('Invalid audio format'));
  },
});

exports.uploadAudio = (req, res, next) => {
  upload.single('audio')(req, res, (err) => {
    if (err instanceof multer.MulterError) {
      if (err.code === 'LIMIT_FILE_SIZE') {
        return res.status(400).json({ status: 'error', message: 'File too large (max 5MB)' });
      }
      return res.status(400).json({ status: 'error', message: err.message });
    } else if (err) {
      if (err.message === 'Invalid audio format') {
        return res.status(400).json({ status: 'error', message: err.message });
      }
      return res.status(500).json({ status: 'error', message: err.message || 'Upload error' });
    }
    next();
  });
};
