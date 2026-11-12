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
    if (typeof alertId !== 'string' || !alertId.trim()) {
      return sendError(res, 'ID laporan wajib diisi untuk analisis.', 400);
    }
    const alert = await prisma.alert.findUnique({
      where: { id: alertId },
      select: { id: true, userId: true, categoryId: true, customCategory: true,
        description: true, aiSummary: true, riskLevel: true,
        category: { select: { name: true } } },
    });
    if (!alert) return sendError(res, 'Laporan tidak ditemukan.', 404);
    if (alert.userId !== req.user.id) {
      return sendError(res, 'Hanya pelapor dapat meminta analisis AI untuk laporan ini.', 403);
    }
    // Existing analysis is reused; repeat taps do not consume more Groq tokens.
    if (alert.aiSummary && alert.riskLevel) {
      const existing = await prisma.aIIncidentSummary.findFirst({
        where: { alertId }, orderBy: { createdAt: 'desc' },
        select: { recommendedAction: true },
      });
      return sendSuccess(res, 'Analisis AI telah tersedia (cache).', {
        summary: alert.aiSummary, riskLevel: alert.riskLevel,
        recommendedAction: existing?.recommendedAction || 'Ikuti arahan petugas resmi.',
        fromCache: true,
      });
    }
    const categoryName = alert.customCategory || alert.category?.name || 'Tidak diketahui';

    const userMessage = `
Jenis Alert: ${categoryName}
Deskripsi: ${alert.description.slice(0, 1500)}

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