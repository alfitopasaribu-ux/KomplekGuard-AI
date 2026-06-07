const prisma = require('../config/database');
const { sendSuccess, sendError } = require('../utils/response');

const respondToAlert = async (req, res) => {
  try {
    const { responseStatus, note, latitude, longitude } = req.body;
    const response = await prisma.alertResponse.create({
      data: { alertId: req.params.id, userId: req.user.id, responseStatus, note, latitude, longitude },
    });
    return sendSuccess(res, 'Respons berhasil dikirim', response, 201);
  } catch (e) { return sendError(res, e.message, 500); }
};

const getAlertResponses = async (req, res) => {
  try {
    const responses = await prisma.alertResponse.findMany({
      where: { alertId: req.params.id },
      include: { user: { select: { id: true, name: true } } },
      orderBy: { createdAt: 'desc' },
    });
    return sendSuccess(res, 'Respons alert', responses);
  } catch (e) { return sendError(res, e.message, 500); }
};

module.exports = { respondToAlert, getAlertResponses };