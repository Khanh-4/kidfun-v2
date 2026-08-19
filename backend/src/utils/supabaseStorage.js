const { createClient } = require('@supabase/supabase-js');

// Bucket riêng, private (không public) — audio SOS của trẻ em là dữ liệu
// nhạy cảm, không nên có URL công khai vĩnh viễn. Playback dùng signed URL
// có hạn (xem getSosAudioSignedUrl).
const SOS_AUDIO_BUCKET = 'sos-audio';
const SIGNED_URL_EXPIRY_SECONDS = 24 * 60 * 60; // 24h — đủ để parent nghe lại trong ngày

let client = null;
const getClient = () => {
  if (!client) {
    if (!process.env.SUPABASE_URL || !process.env.SUPABASE_SERVICE_ROLE_KEY) {
      throw new Error('SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY not configured');
    }
    client = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_SERVICE_ROLE_KEY);
  }
  return client;
};

/**
 * Upload buffer audio SOS lên Supabase Storage.
 * Trả về storage path (không phải URL) — lưu path này vào DB, không lưu URL.
 */
async function uploadSosAudio(buffer, originalName, mimetype) {
  const ext = (originalName && originalName.split('.').pop()) || 'm4a';
  const objectPath = `sos_${Date.now()}_${Math.random().toString(36).slice(2, 8)}.${ext}`;

  const { error } = await getClient()
    .storage.from(SOS_AUDIO_BUCKET)
    .upload(objectPath, buffer, { contentType: mimetype, upsert: false });

  if (error) throw error;
  return objectPath;
}

/**
 * Đổi 1 storage path đã lưu trong DB thành signed URL có hạn để phát lại.
 * Trả null nếu path rỗng hoặc ký lỗi (không throw — audio không phát được
 * không nên làm sập cả API trả về lịch sử SOS).
 */
async function getSosAudioSignedUrl(objectPath) {
  if (!objectPath) return null;
  try {
    const { data, error } = await getClient()
      .storage.from(SOS_AUDIO_BUCKET)
      .createSignedUrl(objectPath, SIGNED_URL_EXPIRY_SECONDS);
    if (error) throw error;
    return data.signedUrl;
  } catch (err) {
    console.error('❌ [SupabaseStorage] Failed to sign URL for', objectPath, ':', err.message);
    return null;
  }
}

module.exports = { uploadSosAudio, getSosAudioSignedUrl };
