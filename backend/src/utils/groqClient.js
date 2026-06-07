const axios = require('axios');
const groqConfig = require('../config/groq');

const callGroq = async (systemPrompt, userMessage) => {
  const response = await axios.post(
    groqConfig.baseUrl,
    {
      model: groqConfig.model,
      messages: [
        { role: 'system', content: systemPrompt },
        { role: 'user', content: userMessage },
      ],
      max_tokens: 1024,
      temperature: 0.3,
    },
    {
      headers: {
        Authorization: `Bearer ${groqConfig.apiKey}`,
        'Content-Type': 'application/json',
      },
    }
  );
  return response.data.choices[0].message.content;
};

module.exports = { callGroq };