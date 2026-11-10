module.exports = {
  apiKey: process.env.GROQ_API_KEY,
  model: process.env.GROQ_MODEL || 'openai/gpt-oss-20b',
  baseUrl: 'https://api.groq.com/openai/v1/chat/completions',
};