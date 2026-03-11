const nodemailer = require('nodemailer');
const dns = require('dns');

if (!process.env.SMTP_USER || !process.env.SMTP_PASS) {
  console.warn('⚠️  SMTP_USER hoặc SMTP_PASS chưa được cấu hình trong .env — chức năng gửi email sẽ không hoạt động');
}

const transporter = nodemailer.createTransport({
  host: 'smtp.gmail.com',
  port: 587,
  secure: false,
  auth: {
    user: process.env.SMTP_USER,
    pass: process.env.SMTP_PASS,
  },
  // Fix ENETUNREACH trên Railway: ép kết nối qua IPv4 thay vì IPv6
  dnsLookup: (hostname, options, callback) => {
    dns.resolve4(hostname, (err, addresses) => {
      if (err) return callback(err);
      callback(null, addresses[0], 4);
    });
  },
});

const sendResetPasswordEmail = async (email, resetToken) => {
  const resetUrl = `http://localhost:5173/reset-password/${resetToken}`;

  const html = `
    <div style="max-width: 480px; margin: 0 auto; font-family: 'Segoe UI', Arial, sans-serif; color: #1e293b;">
      <div style="text-align: center; padding: 32px 0 16px;">
        <h1 style="margin: 0; font-size: 28px; font-weight: 700; background: linear-gradient(45deg, #6366f1, #f472b6); -webkit-background-clip: text; -webkit-text-fill-color: transparent;">
          🎯 KidFun
        </h1>
      </div>
      <div style="background: #ffffff; border-radius: 12px; padding: 32px; border: 1px solid #e2e8f0;">
        <h2 style="margin: 0 0 16px; font-size: 20px; color: #1e293b;">Đặt lại mật khẩu</h2>
        <p style="margin: 0 0 8px; color: #475569; line-height: 1.6;">Xin chào,</p>
        <p style="margin: 0 0 24px; color: #475569; line-height: 1.6;">
          Chúng tôi nhận được yêu cầu đặt lại mật khẩu cho tài khoản KidFun của bạn.
          Nhấn nút bên dưới để tạo mật khẩu mới:
        </p>
        <div style="text-align: center; margin: 0 0 24px;">
          <a href="${resetUrl}" style="display: inline-block; padding: 14px 32px; background: linear-gradient(45deg, #6366f1, #818cf8); color: #ffffff; text-decoration: none; border-radius: 8px; font-weight: 600; font-size: 16px;">
            Đặt lại mật khẩu
          </a>
        </div>
        <p style="margin: 0 0 8px; color: #64748b; font-size: 14px; line-height: 1.6;">
          Liên kết này sẽ hết hạn sau <strong>1 giờ</strong>.
        </p>
        <p style="margin: 0; color: #64748b; font-size: 14px; line-height: 1.6;">
          Nếu bạn không yêu cầu đặt lại mật khẩu, vui lòng bỏ qua email này. Tài khoản của bạn vẫn an toàn.
        </p>
      </div>
      <div style="text-align: center; padding: 24px 0; color: #94a3b8; font-size: 12px;">
        © ${new Date().getFullYear()} KidFun — Hệ thống quản lý thiết bị thông minh cho trẻ em
      </div>
    </div>
  `;

  await transporter.sendMail({
    from: `"KidFun" <${process.env.SMTP_USER}>`,
    to: email,
    subject: 'Đặt lại mật khẩu — KidFun',
    html,
  });
};

module.exports = { sendResetPasswordEmail };
