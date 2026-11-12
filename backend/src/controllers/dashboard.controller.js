const prisma = require('../config/database');
const { sendSuccess, sendError } = require('../utils/response');
const { findVerificationMap, verificationFor, residentAlertView } = require('../utils/guardianVerify');

const getDashboard = async (req, res) => {
  try {
    const [totalAlerts, activeAlerts, resolvedAlerts, totalUsers] = await Promise.all([
      prisma.alert.count(),
      prisma.alert.count({ where: { status: 'AKTIF' } }),
      prisma.alert.count({ where: { status: 'SELESAI' } }),
      prisma.user.count({ where: { role: 'WARGA' } }),
    ]);
    const recentAlerts = await prisma.alert.findMany({ take: 5, orderBy: { createdAt: 'desc' }, include: { category: true, user: { select: { id: true, name: true } } } });
    const reviews = await findVerificationMap(prisma, recentAlerts.map(a => a.id));
    const safeAlerts = recentAlerts.map(a =>
      residentAlertView(a, req.user, verificationFor(a.id, reviews)));
    return sendSuccess(res, 'Data dashboard', {
      totalAlerts, activeAlerts, resolvedAlerts, totalUsers, recentAlerts: safeAlerts,
    });
  } catch (e) { return sendError(res, e.message, 500); }
};

module.exports = { getDashboard };