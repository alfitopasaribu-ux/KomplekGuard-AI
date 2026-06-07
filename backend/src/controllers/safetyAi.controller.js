// Intentionally left blank. User will fill in implementation.
const prisma = require('../config/database');
const { sendSuccess, sendError } = require('../utils/response');

const GROQ_API_URL = 'https://api.groq.com/openai/v1/chat/completions';

async function callGroq(messages, temperature = 0.4) {
  if (!process.env.GROQ_API_KEY) {
    throw new Error('GROQ_API_KEY belum diatur di environment variables');
  }

  const response = await fetch(GROQ_API_URL, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${process.env.GROQ_API_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model: process.env.GROQ_MODEL || 'llama-3.1-8b-instant',
      messages,
      temperature,
    }),
  });

  const data = await response.json();

  if (!response.ok) {
    throw new Error(data?.error?.message || 'Gagal memanggil Groq AI');
  }

  return data.choices?.[0]?.message?.content || '';
}

function safeJsonParse(text) {
  try {
    const cleaned = text
      .replace(/```json/g, '')
      .replace(/```/g, '')
      .trim();

    return JSON.parse(cleaned);
  } catch (_) {
    return null;
  }
}

async function getSafetyContext() {
  const activeAlerts = await prisma.alert.findMany({
    where: {
      status: {
        in: ['AKTIF', 'DIPROSES'],
      },
    },
    include: {
      category: true,
      user: {
        select: {
          name: true,
          address: true,
        },
      },
    },
    orderBy: {
      createdAt: 'desc',
    },
    take: 10,
  });

  const todayStart = new Date();
  todayStart.setHours(0, 0, 0, 0);

  const weekStart = new Date();
  weekStart.setDate(weekStart.getDate() - 7);

  const totalToday = await prisma.alert.count({
    where: {
      createdAt: {
        gte: todayStart,
      },
    },
  });

  const totalWeek = await prisma.alert.count({
    where: {
      createdAt: {
        gte: weekStart,
      },
    },
  });

  const weekAlerts = await prisma.alert.findMany({
    where: {
      createdAt: {
        gte: weekStart,
      },
    },
    include: {
      category: true,
    },
  });

  const categoryCounter = {};

  for (const alert of weekAlerts) {
    const name =
      alert.customCategory ||
      alert.category?.name ||
      'Tidak diketahui';

    categoryCounter[name] = (categoryCounter[name] || 0) + 1;
  }

  const topCategory =
    Object.entries(categoryCounter).sort((a, b) => b[1] - a[1])[0]?.[0] ||
    null;

  return {
    activeAlerts,
    totalToday,
    totalWeek,
    topCategory,
  };
}

const getDailyBriefing = async (req, res) => {
  try {
    const context = await getSafetyContext();

    const prompt = `
Kamu adalah KomplekGuard AI, asisten keamanan lingkungan komplek.

Buat briefing keamanan harian berdasarkan data berikut:

Alert aktif:
${JSON.stringify(context.activeAlerts, null, 2)}

Total alert hari ini: ${context.totalToday}
Total alert 7 hari terakhir: ${context.totalWeek}
Kategori paling sering: ${context.topCategory || '-'}

Balas hanya JSON valid:
{
  "summary": "...",
  "riskLevel": "RENDAH|SEDANG|TINGGI|KRITIS",
  "recommendation": "...",
  "dangerArea": "...",
  "topCategory": "..."
}

Aturan:
- Bahasa Indonesia.
- Singkat, jelas, dan menenangkan.
- Jangan membuat fakta palsu.
- Jika tidak ada alert aktif, tetap beri saran pencegahan.
`;

    const aiText = await callGroq([
      {
        role: 'system',
        content:
          'Kamu adalah AI keamanan lingkungan. Jawab hanya JSON valid.',
      },
      {
        role: 'user',
        content: prompt,
      },
    ]);

    const parsed = safeJsonParse(aiText);

    const briefingData = {
      summary:
        parsed?.summary ||
        'Lingkungan dalam pemantauan KomplekGuard AI.',
      riskLevel: parsed?.riskLevel || 'RENDAH',
      recommendation:
        parsed?.recommendation ||
        'Tetap waspada dan gunakan tombol alert jika terjadi kondisi darurat.',
      activeAlertCount: context.activeAlerts.length,
      totalAlertToday: context.totalToday,
      totalAlertWeek: context.totalWeek,
      topCategory: parsed?.topCategory || context.topCategory,
      dangerArea: parsed?.dangerArea || null,
      rawAiResponse: aiText,
    };

    const briefing = await prisma.dailySafetyBriefing.upsert({
      where: {
        date: new Date(new Date().toISOString().slice(0, 10)),
      },
      update: briefingData,
      create: {
        date: new Date(new Date().toISOString().slice(0, 10)),
        ...briefingData,
      },
    });

    return sendSuccess(res, 'AI Safety Daily Briefing berhasil dibuat', briefing);
  } catch (e) {
    return sendError(res, e.message, 500);
  }
};

const chatWithAi = async (req, res) => {
  try {
    const { message, sessionId } = req.body;

    if (!message) {
      return sendError(res, 'Message wajib diisi', 400);
    }

    let session = null;

    if (sessionId) {
      session = await prisma.aiChatSession.findFirst({
        where: {
          id: sessionId,
          userId: req.user.id,
        },
      });
    }

    if (!session) {
      session = await prisma.aiChatSession.create({
        data: {
          userId: req.user.id,
          title: 'Percakapan KomplekGuard AI',
          topic: 'SAFETY_ASSISTANT',
        },
      });
    }

    await prisma.aiChatMessage.create({
      data: {
        sessionId: session.id,
        userId: req.user.id,
        role: 'USER',
        message,
        intent: 'USER_QUESTION',
      },
    });

    const context = await getSafetyContext();

    const prompt = `
Kamu adalah KomplekGuard AI, asisten keamanan lingkungan warga.

Pertanyaan warga:
"${message}"

Konteks sistem:
- Alert aktif: ${JSON.stringify(context.activeAlerts, null, 2)}
- Total alert hari ini: ${context.totalToday}
- Total alert 7 hari terakhir: ${context.totalWeek}
- Kategori paling sering: ${context.topCategory || '-'}

Tugas:
Jawab pertanyaan warga dengan aman, singkat, dan praktis.

Aturan:
- Bahasa Indonesia.
- Jangan menyuruh warga melawan pelaku.
- Jika kondisi darurat, sarankan menjauh, minta bantuan warga sekitar, dan hubungi petugas terkait.
- Jika pertanyaan tentang risiko lingkungan, gunakan konteks alert.
- Jangan membuat fakta palsu.
`;

    const aiAnswer = await callGroq([
      {
        role: 'system',
        content:
          'Kamu adalah AI safety assistant untuk warga komplek. Jawab dengan bahasa Indonesia yang jelas dan aman.',
      },
      {
        role: 'user',
        content: prompt,
      },
    ]);

    const savedAiMessage = await prisma.aiChatMessage.create({
      data: {
        sessionId: session.id,
        userId: req.user.id,
        role: 'ASSISTANT',
        message: aiAnswer,
        rawAiResponse: aiAnswer,
        intent: 'SAFETY_ANSWER',
      },
    });

    return sendSuccess(res, 'AI berhasil menjawab', {
      sessionId: session.id,
      answer: aiAnswer,
      message: savedAiMessage,
    });
  } catch (e) {
    return sendError(res, e.message, 500);
  }
};

const getChatHistory = async (req, res) => {
  try {
    const sessions = await prisma.aiChatSession.findMany({
      where: {
        userId: req.user.id,
      },
      include: {
        messages: {
          orderBy: {
            createdAt: 'asc',
          },
        },
      },
      orderBy: {
        createdAt: 'desc',
      },
      take: 10,
    });

    return sendSuccess(res, 'Riwayat chat AI', sessions);
  } catch (e) {
    return sendError(res, e.message, 500);
  }
};

const createVoiceAlertDraft = async (req, res) => {
  try {
    const { transcript } = req.body;

    if (!transcript) {
      return sendError(res, 'Transcript suara wajib diisi', 400);
    }

    const prompt = `
Kamu adalah AI Emergency Assistant untuk aplikasi KomplekGuard AI.

Tugasmu mengubah laporan suara warga menjadi draft alert yang jelas.

Input suara warga:
"${transcript}"

Balas hanya JSON valid:
{
  "title": "...",
  "description": "...",
  "categorySuggestion": "...",
  "riskLevel": "RENDAH|SEDANG|TINGGI|KRITIS",
  "recommendedAction": "...",
  "panicReductionMessage": "..."
}

Aturan:
- Bahasa Indonesia.
- Jangan membuat fakta palsu.
- Jika laporan mengandung gas, api, kekerasan, pencurian, medis darurat, anak hilang, atau banjir, naikkan risiko.
- Buat judul pendek dan jelas.
- Buat deskripsi lebih rapi dari ucapan warga.
- Panic reduction message harus menenangkan.
`;

    const aiText = await callGroq([
      {
        role: 'system',
        content:
          'Kamu mengubah laporan suara warga menjadi draft alert. Jawab hanya JSON valid.',
      },
      {
        role: 'user',
        content: prompt,
      },
    ]);

    const parsed = safeJsonParse(aiText);

    const draft = await prisma.voiceAlertDraft.create({
      data: {
        userId: req.user.id,
        transcript,
        title: parsed?.title || 'Laporan Warga',
        description: parsed?.description || transcript,
        categorySuggestion: parsed?.categorySuggestion || null,
        riskLevel: parsed?.riskLevel || 'SEDANG',
        recommendedAction:
          parsed?.recommendedAction ||
          'Tetap tenang, jauhi sumber bahaya, dan minta bantuan warga sekitar.',
        panicReductionMessage:
          parsed?.panicReductionMessage ||
          'Alert kamu sedang diproses. Tetap tenang dan berada di tempat aman.',
        rawAiResponse: aiText,
      },
    });

    return sendSuccess(res, 'Draft alert dari suara berhasil dibuat', draft);
  } catch (e) {
    return sendError(res, e.message, 500);
  }
};

module.exports = {
  getDailyBriefing,
  chatWithAi,
  getChatHistory,
  createVoiceAlertDraft,
};