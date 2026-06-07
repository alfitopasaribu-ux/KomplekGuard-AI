const prisma = require('../config/database');
const { sendSuccess, sendError } = require('../utils/response');

const getDashboard = async (req, res) => {
  try {
    const [totalAlerts, activeAlerts, resolvedAlerts, totalUsers] = await Promise.all([
      prisma.alert.count(),
      prisma.alert.count({ where: { status: 'AKTIF' } }),
      prisma.alert.count({ where: { status: 'SELESAI' } }),
      prisma.user.count({ where: { role: 'WARGA' } }),
    ]);
    const recentAlerts = await prisma.alert.findMany({ take: 5, orderBy: { createdAt: 'desc' }, include: { category: true, user: { select: { id: true, name: true } } } });
    return sendSuccess(res, 'Data dashboard', { totalAlerts, activeAlerts, resolvedAlerts, totalUsers, recentAlerts });
  } catch (e) { return sendError(res, e.message, 500); }
};

module.exports = { getDashboard };