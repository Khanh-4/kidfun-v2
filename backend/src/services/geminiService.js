const { GoogleGenerativeAI } = require('@google/generative-ai');

let model = null;

function getModel() {
  if (model) return model;
  if (!process.env.GEMINI_API_KEY) return null;

  const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);
  model = genAI.getGenerativeModel({
    model: 'gemini-2.0-flash',
    generationConfig: {
      temperature: 0.2,
      responseMimeType: 'application/json',
    },
  });
  return model;
}

const ANALYSIS_PROMPT = `Bạn là chuyên gia phân tích an toàn nội dung cho trẻ em từ 6-15 tuổi.
Phân tích video YouTube dưới đây (dựa trên title, channel name, và thumbnail) để xác định mức độ an toàn.

Trả về JSON với format CHÍNH XÁC:
{
  "dangerLevel": <số từ 1 đến 5>,
  "category": "<SAFE|BULLY|SEXUAL|DRUG|VIOLENCE|SELF_HARM|DISTURBING>",
  "summary": "<tóm tắt ngắn 1-2 câu lý do đánh giá, bằng tiếng Việt>"
}

Mức độ nguy hiểm:
- 1: Hoàn toàn an toàn (giáo dục, giải trí trẻ em phù hợp)
- 2: An toàn với cảnh báo nhỏ (giải trí người lớn nhưng không nguy hiểm)
- 3: Đáng nghi (nội dung gây tranh cãi, bạo lực nhẹ, ngôn từ không phù hợp)
- 4: Nguy hiểm (nội dung 18+, bạo lực rõ ràng, drug, gambling)
- 5: Cực kỳ nguy hiểm (self-harm, sexual abuse, predator content, ELSAGATE)

Categories:
- SAFE: An toàn cho trẻ
- BULLY: Bắt nạt, ngôn ngữ thù địch
- SEXUAL: Nội dung tình dục, gợi cảm
- DRUG: Ma túy, rượu, thuốc lá
- VIOLENCE: Bạo lực, máu me
- SELF_HARM: Tự hại, tự sát
- DISTURBING: Đáng sợ, ELSAGATE, đánh lừa trẻ em

Title: {title}
Channel: {channel}
`;

const VALID_CATEGORIES = ['SAFE', 'BULLY', 'SEXUAL', 'DRUG', 'VIOLENCE', 'SELF_HARM', 'DISTURBING'];

const RETRY_DELAYS_MS = [5000, 10000, 20000];

function isTransientError(err) {
  const msg = err.message || '';
  return msg.includes('503') || msg.includes('Service Unavailable') ||
    msg.includes('overloaded') || msg.includes('high demand') ||
    msg.includes('429') || msg.includes('Too Many Requests');
}

exports.analyzeVideo = async ({ title, channel, thumbnailUrl }) => {
  const aiModel = getModel();
  if (!aiModel) {
    console.warn('⚠️ [GEMINI] API key not set, skipping analysis');
    return { dangerLevel: 1, category: 'SAFE', summary: 'Chưa có API key để phân tích' };
  }

  const prompt = ANALYSIS_PROMPT
    .replace('{title}', title || 'Unknown')
    .replace('{channel}', channel || 'Unknown');

  const parts = [{ text: prompt }];

  if (thumbnailUrl) {
    try {
      const response = await fetch(thumbnailUrl);
      const buffer = await response.arrayBuffer();
      const base64 = Buffer.from(buffer).toString('base64');
      parts.push({ inlineData: { mimeType: 'image/jpeg', data: base64 } });
    } catch (e) {
      console.warn('⚠️ [GEMINI] Cannot fetch thumbnail, fallback to text-only:', e.message);
    }
  }

  let lastErr;
  for (let attempt = 0; attempt <= RETRY_DELAYS_MS.length; attempt++) {
    try {
      const result = await aiModel.generateContent({ contents: [{ role: 'user', parts }] });
      const text = result.response.text();
      const parsed = JSON.parse(text);

      const dangerLevel = Math.max(1, Math.min(5, parseInt(parsed.dangerLevel) || 1));
      const category = VALID_CATEGORIES.includes(parsed.category) ? parsed.category : 'SAFE';
      const summary = (parsed.summary || '').slice(0, 500);

      return { dangerLevel, category, summary };
    } catch (err) {
      lastErr = err;
      if (isTransientError(err) && attempt < RETRY_DELAYS_MS.length) {
        const delay = RETRY_DELAYS_MS[attempt];
        console.warn(`⚠️ [GEMINI] Transient error (attempt ${attempt + 1}), retrying in ${delay / 1000}s: ${err.message}`);
        await new Promise(r => setTimeout(r, delay));
      } else {
        break;
      }
    }
  }

  if (isTransientError(lastErr)) {
    // Re-throw so the worker can skip marking this log as analyzed
    throw lastErr;
  }
  console.error('❌ [GEMINI] Analysis error:', lastErr.message);
  return { dangerLevel: 1, category: 'SAFE', summary: 'Phân tích thất bại' };
};
