const { PrismaClient } = require("@prisma/client");

const prisma = new PrismaClient();

function getUserId(req) {
  return req.user?.id || req.user?.userId || req.userId;
}

function success(res, message, data = null) {
  return res.json({
    success: true,
    message,
    data,
  });
}

function failed(res, message, status = 500) {
  return res.status(status).json({
    success: false,
    message,
  });
}

exports.respondToAlert = async (req, res) => {
  try {
    const userId = getUserId(req);
    const { id } = req.params;
    const { responseStatus, note, latitude, longitude } = req.body;

    if (!userId) {
      return failed(res, "User tidak valid. Silakan login ulang.", 401);
    }

    if (!responseStatus) {
      return failed(res, "Status respons wajib diisi.", 400);
    }

    const alert = await prisma.alert.findUnique({
      where: { id },
      select: { id: true, userId: true, title: true },
    });

    if (!alert) {
      return failed(res, "Alert tidak ditemukan.", 404);
    }

    const responder = await prisma.user.findUnique({
      where: { id: userId },
    });

    const response = await prisma.alertResponse.create({
      data: {
        alertId: id,
        userId,
        responseStatus,
        note: note || null,
        latitude: latitude ? Number(latitude) : null,
        longitude: longitude ? Number(longitude) : null,
      },
      include: {
        user: {
          select: {
            id: true,
            name: true,
            role: true,
          },
        },
      },
    });

    if (alert.userId !== userId) {
      await prisma.notification.create({
        data: {
          userId: alert.userId,
          alertId: id,
          title: "Ada warga merespons alert kamu",
          message: `${responder?.name || "Seorang warga"} merespons alert "${
            alert.title
          }" dengan status ${responseStatus.replaceAll("_", " ")}.`,
          type: "ALERT_RESPONSE",
        },
      });
    }

    await prisma.activityLog.create({
      data: {
        userId,
        action: "RESPOND_ALERT",
        description: `Merespons alert "${alert.title}" dengan status ${responseStatus}`,
      },
    });

    return success(res, "Respons berhasil dikirim.", {
      id: response.id,
      alertId: response.alertId,
      userId: response.userId,
      responseStatus: response.responseStatus,
      note: response.note,
      createdAt: response.createdAt,
      user: response.user,
    });
  } catch (error) {
    return failed(res, error.message);
  }
};

exports.getAlertResponses = async (req, res) => {
  try {
    const { id } = req.params;

    const incident = await prisma.alert.findUnique({ where: { id }, select: { id: true } });
    if (!incident) return failed(res, "Alert tidak ditemukan.", 404);
    const responses = await prisma.alertResponse.findMany({
      where: {
        alertId: id,
      },
      orderBy: {
        createdAt: "desc",
      },
      include: {
        user: {
          select: {
            id: true,
            name: true,
            role: true,
          },
        },
      },
    });

    return success(res, "Daftar respons berhasil diambil.", responses.map(r => ({
      id: r.id, alertId: r.alertId, userId: r.userId,
      responseStatus: r.responseStatus, note: r.note,
      createdAt: r.createdAt, user: r.user,
    })));
  } catch (error) {
    return failed(res, error.message);
  }
};