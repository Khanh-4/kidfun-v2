const { GoogleGenerativeAI } = require('@google/generative-ai');

let model = null;

function getModel() {
  if (model) return model;
  if (!process.env.GEMINI_API_KEY) return null;

  const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);
  model = genAI.getGenerativeModel({
    model: 'gemini-2.5-flash',
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

exports.analyzeVideo = async ({ title, channel, thumbnailUrl }) => {
  const aiModel = getModel();
  if (!aiModel) {
    console.warn('⚠️ [GEMINI] API key not set, skipping analysis');
    return { dangerLevel: 1, category: 'SAFE', summary: 'Chưa có API key để phân tích' };
  }

  try {
    const prompt = ANALYSIS_PROMPT
      .replace('{title}', title || 'Unknown')
      .replace('{channel}', channel || 'Unknown');

    const parts = [{ text: prompt }];

    if (thumbnailUrl) {
      try {
        const response = await fetch(thumbnailUrl);
        const buffer = await response.arrayBuffer();
        const base64 = Buffer.from(buffer).toString('base64');
        parts.push({
          inlineData: {
            mimeType: 'image/jpeg',
            data: base64,
          },
        });
      } catch (e) {
        console.warn('⚠️ [GEMINI] Cannot fetch thumbnail, fallback to text-only:', e.message);
      }
    }

    const result = await aiModel.generateContent({ contents: [{ role: 'user', parts }] });
    const text = result.response.text();
    const parsed = JSON.parse(text);

    const dangerLevel = Math.max(1, Math.min(5, parseInt(parsed.dangerLevel) || 1));
    const category = VALID_CATEGORIES.includes(parsed.category) ? parsed.category : 'SAFE';
    const summary = (parsed.summary || '').slice(0, 500);

    return { dangerLevel, category, summary };
  } catch (err) {
    console.error('❌ [GEMINI] Analysis error:', err.message);
    return { dangerLevel: 1, category: 'SAFE', summary: 'Phân tích thất bại' };
  }
};
