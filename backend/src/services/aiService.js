const Groq = require('groq-sdk');
const OpenAI = require('openai');

const groqClient = process.env.GROQ_API_KEY
  ? new Groq({ apiKey: process.env.GROQ_API_KEY })
  : null;

const openRouterClient = process.env.OPENROUTER_API_KEY
  ? new OpenAI({
      baseURL: 'https://openrouter.ai/api/v1',
      apiKey: process.env.OPENROUTER_API_KEY,
      defaultHeaders: {
        'HTTP-Referer': 'https://kidfun-app.com',
        'X-Title': 'KidFun V3',
      },
    })
  : null;

const GROQ_MODEL = 'meta-llama/llama-4-scout-17b-16e-instruct';
const OPENROUTER_MODEL = 'meta-llama/llama-4-scout:free';

const ANALYSIS_PROMPT = `Bạn là chuyên gia phân tích an toàn nội dung cho trẻ em từ 6-15 tuổi.
Phân tích video YouTube dưới đây (dựa trên title, channel name, và thumbnail nếu có) để xác định mức độ an toàn.

Trả về CHỈ JSON, KHÔNG kèm text hay markdown:
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
  if (groqClient) {
    try {
      const result = await analyzeWithGroq(title, channel, thumbnailUrl);
      if (result) {
        console.log(`✅ [AI:GROQ] Analyzed: "${(title || '').slice(0, 40)}..." → Level ${result.dangerLevel}`);
        return result;
      }
    } catch (err) {
      console.warn(`⚠️ [AI:GROQ] Failed: ${err.message}. Falling back to OpenRouter...`);
    }
  }

  if (openRouterClient) {
    try {
      const result = await analyzeWithOpenRouter(title, channel, thumbnailUrl);
      if (result) {
        console.log(`✅ [AI:OPENROUTER] Analyzed: "${(title || '').slice(0, 40)}..." → Level ${result.dangerLevel}`);
        return result;
      }
    } catch (err) {
      console.warn(`⚠️ [AI:OPENROUTER] Failed: ${err.message}. All providers failed.`);
    }
  }

  console.error(`❌ [AI] All providers failed for: "${title}"`);
  return { dangerLevel: 1, category: 'SAFE', summary: 'Không thể phân tích — tất cả providers đều thất bại' };
};

async function analyzeWithGroq(title, channel, thumbnailUrl) {
  const prompt = ANALYSIS_PROMPT
    .replace('{title}', title || 'Unknown')
    .replace('{channel}', channel || 'Unknown');

  const contentParts = [{ type: 'text', text: prompt }];
  if (thumbnailUrl) {
    contentParts.push({ type: 'image_url', image_url: { url: thumbnailUrl } });
  }

  const response = await groqClient.chat.completions.create({
    model: GROQ_MODEL,
    messages: [{ role: 'user', content: contentParts }],
    temperature: 0.2,
    max_completion_tokens: 500,
    response_format: { type: 'json_object' },
  });

  const text = response.choices[0]?.message?.content;
  if (!text) throw new Error('Empty response from Groq');
  return parseAIResponse(text);
}

async function analyzeWithOpenRouter(title, channel, thumbnailUrl) {
  const prompt = ANALYSIS_PROMPT
    .replace('{title}', title || 'Unknown')
    .replace('{channel}', channel || 'Unknown');

  const contentParts = [{ type: 'text', text: prompt }];
  if (thumbnailUrl) {
    contentParts.push({ type: 'image_url', image_url: { url: thumbnailUrl } });
  }

  const response = await openRouterClient.chat.completions.create({
    model: OPENROUTER_MODEL,
    messages: [{ role: 'user', content: contentParts }],
    temperature: 0.2,
    max_tokens: 500,
  });

  const text = response.choices[0]?.message?.content;
  if (!text) throw new Error('Empty response from OpenRouter');
  return parseAIResponse(text);
}

function parseAIResponse(text) {
  try {
    const cleaned = text.replace(/```json\s*/g, '').replace(/```\s*/g, '').trim();
    const parsed = JSON.parse(cleaned);
    const dangerLevel = Math.max(1, Math.min(5, parseInt(parsed.dangerLevel) || 1));
    const category = VALID_CATEGORIES.includes(parsed.category) ? parsed.category : 'SAFE';
    const summary = (parsed.summary || '').slice(0, 500);
    return { dangerLevel, category, summary };
  } catch (err) {
    console.error('❌ [AI] JSON parse error:', err.message, 'Raw:', text.slice(0, 200));
    throw new Error('Invalid JSON response');
  }
}

exports.getProviderStatus = () => ({
  groq: { available: !!groqClient, model: GROQ_MODEL },
  openRouter: { available: !!openRouterClient, model: OPENROUTER_MODEL },
});

exports.isAIAvailable = () => !!groqClient || !!openRouterClient;
