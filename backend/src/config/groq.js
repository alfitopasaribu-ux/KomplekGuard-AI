module.exports = {
  apiKey: process.env.GROQ_API_KEY,
  model: process.env.GROQ_MODEL || 'llama-3.1-8b-instant',
  baseUrl: 'https://api.groq.com/openai/v1/chat/completions',
};