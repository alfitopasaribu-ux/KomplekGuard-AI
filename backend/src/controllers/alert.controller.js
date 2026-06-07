const prisma = require('../config/database');
const { sendSuccess, sendError } = require('../utils/response');

const getAlerts = async (req, res) => {
  try {
    const alerts = await prisma.alert.findMany({ include: { user: { select: { id: true, name: true } }, category: true }, orderBy: { createdAt: 'desc' } });
    return sendSuccess(res, 'Daftar alert', alerts);
  } catch (e) { return sendError(res, e.message, 500); }
};

const getActiveAlerts = async (req, res) => {
  try {
    const alerts = await prisma.alert.findMany({ where: { status: 'AKTIF' }, include: { user: { select: { id: true, name: true } }, category: true }, orderBy: { createdAt: 'desc' } });
    return sendSuccess(res, 'Alert aktif', alerts);
  } catch (e) { return sendError(res, e.message, 500); }
};

const getAlertHistory = async (req, res) => {
  try {
    const alerts = await prisma.alert.findMany({ where: { status: { in: ['SELESAI', 'DIBATALKAN'] } }, include: { user: { select: { id: true, name: true } }, category: true }, orderBy: { createdAt: 'desc' } });
    return sendSuccess(res, 'Riwayat alert', alerts);
  } catch (e) { return sendError(res, e.message, 500); }
};

const createAlert = async (req, res) => {
  try {
    const { categoryId, customCategory, title, description, latitude, longitude, address, photoUrl } = req.body;
    if (!title || !description || !latitude || !longitude) return sendError(res, 'Data tidak lengkap');
    const alert = await prisma.alert.create({
      data: { userId: req.user.id, categoryId, customCategory, title, description, latitude, longitude, address, photoUrl },
    });
    return sendSuccess(res, 'Alert berhasil dibuat', alert, 201);
  } catch (e) { return sendError(res, e.message, 500); }
};

const getAlertById = async (req, res) => {
  try {
    const alert = await prisma.alert.findUnique({ where: { id: req.params.id }, include: { user: { select: { id: true, name: true } }, category: true, responses: { include: { user: { select: { id: true, name: true } } } }, aiSummaries: true } });
    if (!alert) return sendError(res, 'Alert tidak ditemukan', 404);
    return sendSuccess(res, 'Detail alert', alert);
  } catch (e) { return sendError(res, e.message, 500); }
};

const updateAlertStatus = async (req, res) => {
  try {
    const { status, note } = req.body;
    const alert = await prisma.alert.findUnique({ where: { id: req.params.id } });
    if (!alert) return sendError(res, 'Alert tidak ditemukan', 404);
    const updated = await prisma.alert.update({
      where: { id: req.params.id },
      data: { status, resolvedAt: ['SELESAI', 'DIBATALKAN'].includes(status) ? new Date() : null },
    });
    await prisma.alertUpdate.create({ data: { alertId: alert.id, userId: req.user.id, oldStatus: alert.status, newStatus: status, note } });
    return sendSuccess(res, 'Status alert diperbarui', updated);
  } catch (e) { return sendError(res, e.message, 500); }
};

const deleteAlert = async (req, res) => {
  try {
    await prisma.alert.delete({ where: { id: req.params.id } });
    return sendSuccess(res, 'Alert dihapus');
  } catch (e) { return sendError(res, e.message, 500); }
};

module.exports = { getAlerts, getActiveAlerts, getAlertHistory, createAlert, getAlertById, updateAlertStatus, deleteAlert };