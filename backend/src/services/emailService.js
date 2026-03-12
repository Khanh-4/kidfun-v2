const { google } = require('googleapis');

const OAuth2 = google.auth.OAuth2;

if (!process.env.GMAIL_CLIENT_ID || !process.env.GMAIL_CLIENT_SECRET || !process.env.GMAIL_REFRESH_TOKEN) {
  console.warn('⚠️  GMAIL_CLIENT_ID / GMAIL_CLIENT_SECRET / GMAIL_REFRESH_TOKEN chưa được cấu hình trong .env — chức năng gửi email sẽ không hoạt động');
}

const oauth2Client = new OAuth2(
  process.env.GMAIL_CLIENT_ID,
  process.env.GMAIL_CLIENT_SECRET,
  'https://developers.google.com/oauthplayground'
);

oauth2Client.setCredentials({
  refresh_token: process.env.GMAIL_REFRESH_TOKEN,
});

/**
 * Tạo raw email theo chuẩn RFC 2822 (base64url)
 */
function buildRaw(to, from, subject, html) {
  const boundary = `boundary_${Date.now()}`;
  const mime = [
    `From: ${from}`,
    `To: ${to}`,
    `Subject: =?UTF-8?B?${Buffer.from(subject).toString('base64')}?=`,
    'MIME-Version: 1.0',
    `Content-Type: multipart/alternative; boundary="${boundary}"`,
    '',
    `--${boundary}`,
    'Content-Type: text/html; charset=UTF-8',
    'Content-Transfer-Encoding: quoted-printable',
    '',
    html,
    '',
    `--${boundary}--`,
  ].join('\r\n');

  return Buffer.from(mime).toString('base64url');
}

/**
 * Gửi email chung qua Gmail REST API (không dùng SMTP)
 * @param {string} to - Địa chỉ email nhận
 * @param {string} subject - Tiêu đề email
 * @param {string} html - Nội dung HTML
 */
async function sendEmail(to, subject, html) {
  const gmail = google.gmail({ version: 'v1', auth: oauth2Client });

  const from = `KidFun <${process.env.GMAIL_USER}>`;
  const raw = buildRaw(to, from, subject, html);

  const res = await gmail.users.messages.send({
    userId: 'me',
    requestBody: { raw },
  });

  console.log(`✅ Email sent to ${to} | messageId: ${res.data.id}`);
  return res.data;
}

const sendResetPasswordEmail = async (email, resetToken) => {
  const resetUrl = `${process.env.PARENT_DASHBOARD_URL || 'http://localhost:5173'}/reset-password/${resetToken}`;

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

  return sendEmail(email, 'Đặt lại mật khẩu — KidFun', html);
};

module.exports = { sendEmail, sendResetPasswordEmail };
