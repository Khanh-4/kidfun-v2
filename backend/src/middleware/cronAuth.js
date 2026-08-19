// Verifies requests to /api/cron/* actually come from Vercel Cron.
// Vercel automatically sends `Authorization: Bearer $CRON_SECRET` on cron
// invocations when the CRON_SECRET env var is set on the project —
// https://vercel.com/docs/cron-jobs/manage-cron-jobs#securing-cron-jobs
const verifyCronSecret = (req, res, next) => {
  if (!process.env.CRON_SECRET) {
    console.error('CRON_SECRET not configured — rejecting cron request');
    return res.status(500).json({ success: false, message: 'Cron not configured' });
  }
  if (req.headers.authorization !== `Bearer ${process.env.CRON_SECRET}`) {
    return res.status(401).json({ success: false, message: 'Unauthorized' });
  }
  next();
};

module.exports = verifyCronSecret;
