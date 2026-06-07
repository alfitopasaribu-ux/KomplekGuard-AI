const prisma = require('../config/database');
const { callGroq } = require('../utils/groqClient');
const { sendSuccess, sendError } = require('../utils/response');

const SYSTEM_PROMPT = `Kamu adalah asisten AI untuk aplikasi keamanan lingkungan KomplekGuard AI.
Tugasmu:
1. Merangkum laporan warga dengan bahasa yang jelas dan singkat
2. Menentukan tingkat risiko: RENDAH, SEDANG, TINGGI, atau KRITIS
3. Memberikan panduan tindakan awal yang AMAN

PENTING:
- Jangan pernah menyuruh warga mengejar atau melawan pelaku
- Jangan menyuruh warga masuk ke area berbahaya
- Selalu sarankan menghubungi petugas resmi jika diperlukan
- Kamu hanya memberi panduan awal, BUKAN pengganti polisi, pemadam kebakaran, atau ambulans`;

const fullAnalysis = async (req, res) => {
  try {
    const { alertId, category, customCategory, description } = req.body;
    const categoryName = customCategory || category || 'Tidak diketahui';

    const userMessage = `
Jenis Alert: ${categoryName}
Deskripsi: ${description}

Berikan respons dalam format JSON berikut (hanya JSON, tanpa teks lain):
{
  "summary": "ringkasan kejadian dalam 2-3 kalimat",
  "riskLevel": "RENDAH|SEDANG|TINGGI|KRITIS",
  "recommendedAction": "panduan tindakan awal yang aman dalam 3-5 kalimat"
}`;

    const raw = await callGroq(SYSTEM_PROMPT, userMessage);
    let parsed;
    try {
      const clean = raw.replace(/```json|```/g, '').trim();
      parsed = JSON.parse(clean);
    } catch {
      parsed = { summary: raw, riskLevel: 'SEDANG', recommendedAction: 'Tetap tenang dan hubungi petugas resmi.' };
    }

    if (alertId) {
      await prisma.aIIncidentSummary.create({
        data: {
          alertId,
          summary: parsed.summary,
          recommendedAction: parsed.recommendedAction,
          riskLevel: parsed.riskLevel,
          rawAiResponse: raw,
        },
      });
      await prisma.alert.update({
        where: { id: alertId },
        data: { aiSummary: parsed.summary, riskLevel: parsed.riskLevel },
      });
    }

    return sendSuccess(res, 'Analisis AI berhasil', parsed);
  } catch (e) { return sendError(res, e.message, 500); }
};

module.exports = { fullAnalysis };