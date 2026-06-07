const prisma = require('../config/database');
const { sendSuccess, sendError } = require('../utils/response');

function isOwner(req, alert) {
  return alert.userId === req.user.id;
}

const alertInclude = {
  user: {
    select: {
      id: true,
      name: true,
      email: true,
      phone: true,
      role: true,
      address: true,
      latitude: true,
      longitude: true,
    },
  },
  category: true,
  neighborhood: true,
  responses: {
    orderBy: {
      createdAt: 'desc',
    },
    include: {
      user: {
        select: {
          id: true,
          name: true,
          phone: true,
          role: true,
          address: true,
        },
      },
    },
  },
  aiSummaries: {
    orderBy: {
      createdAt: 'desc',
    },
  },
};

const getAlerts = async (req, res) => {
  try {
    const alerts = await prisma.alert.findMany({
      include: alertInclude,
      orderBy: {
        createdAt: 'desc',
      },
    });

    return sendSuccess(res, 'Daftar alert', alerts);
  } catch (e) {
    return sendError(res, e.message, 500);
  }
};

const getActiveAlerts = async (req, res) => {
  try {
    const alerts = await prisma.alert.findMany({
      where: {
        status: {
          in: ['AKTIF', 'DIPROSES'],
        },
      },
      include: alertInclude,
      orderBy: {
        createdAt: 'desc',
      },
    });

    return sendSuccess(res, 'Alert aktif', alerts);
  } catch (e) {
    return sendError(res, e.message, 500);
  }
};

const getAlertHistory = async (req, res) => {
  try {
    const alerts = await prisma.alert.findMany({
      where: {
        status: {
          in: ['SELESAI', 'DIBATALKAN'],
        },
      },
      include: alertInclude,
      orderBy: {
        createdAt: 'desc',
      },
    });

    return sendSuccess(res, 'Riwayat alert', alerts);
  } catch (e) {
    return sendError(res, e.message, 500);
  }
};

const createAlert = async (req, res) => {
  try {
    const {
      categoryId,
      customCategory,
      title,
      description,
      latitude,
      longitude,
      address,
      photoUrl,
    } = req.body;

    if (!title || !description || latitude == null || longitude == null) {
      return sendError(
        res,
        'Judul, deskripsi, latitude, dan longitude wajib diisi',
        400
      );
    }

    const user = await prisma.user.findUnique({
      where: {
        id: req.user.id,
      },
    });

    if (!user) {
      return sendError(res, 'User tidak ditemukan', 404);
    }

    const alert = await prisma.alert.create({
      data: {
        userId: req.user.id,
        categoryId: categoryId || null,
        neighborhoodId: user.neighborhoodId || null,
        customCategory: customCategory || null,
        title,
        description,
        latitude: Number(latitude),
        longitude: Number(longitude),
        address: address || user.address || null,
        photoUrl: photoUrl || null,
        status: 'AKTIF',
      },
      include: alertInclude,
    });

    await prisma.activityLog.create({
      data: {
        userId: req.user.id,
        action: 'CREATE_ALERT',
        description: `Membuat alert: ${title}`,
      },
    });

    return sendSuccess(res, 'Alert berhasil dibuat', alert, 201);
  } catch (e) {
    return sendError(res, e.message, 500);
  }
};

const getAlertById = async (req, res) => {
  try {
    const alert = await prisma.alert.findUnique({
      where: {
        id: req.params.id,
      },
      include: alertInclude,
    });

    if (!alert) {
      return sendError(res, 'Alert tidak ditemukan', 404);
    }

    return sendSuccess(res, 'Detail alert', alert);
  } catch (e) {
    return sendError(res, e.message, 500);
  }
};

const updateAlertStatus = async (req, res) => {
  try {
    const { status, note } = req.body;

    const allowedStatus = ['AKTIF', 'DIPROSES', 'SELESAI', 'DIBATALKAN'];

    if (!allowedStatus.includes(status)) {
      return sendError(res, 'Status alert tidak valid', 400);
    }

    const alert = await prisma.alert.findUnique({
      where: {
        id: req.params.id,
      },
    });

    if (!alert) {
      return sendError(res, 'Alert tidak ditemukan', 404);
    }

    if (!isOwner(req, alert)) {
      return sendError(
        res,
        'Akses ditolak. Hanya pelapor yang dapat mengubah status alert ini.',
        403
      );
    }

    const updated = await prisma.alert.update({
      where: {
        id: req.params.id,
      },
      data: {
        status,
        resolvedAt:
          status === 'SELESAI' || status === 'DIBATALKAN'
            ? new Date()
            : null,
      },
      include: alertInclude,
    });

    await prisma.alertUpdate.create({
      data: {
        alertId: alert.id,
        userId: req.user.id,
        oldStatus: alert.status,
        newStatus: status,
        note: note || null,
      },
    });

    await prisma.activityLog.create({
      data: {
        userId: req.user.id,
        action: 'UPDATE_ALERT_STATUS',
        description: `Mengubah status alert "${alert.title}" dari ${alert.status} menjadi ${status}`,
      },
    });

    return sendSuccess(res, 'Status alert berhasil diperbarui', updated);
  } catch (e) {
    return sendError(res, e.message, 500);
  }
};

const deleteAlert = async (req, res) => {
  try {
    const alert = await prisma.alert.findUnique({
      where: {
        id: req.params.id,
      },
    });

    if (!alert) {
      return sendError(res, 'Alert tidak ditemukan', 404);
    }

    if (!isOwner(req, alert)) {
      return sendError(
        res,
        'Akses ditolak. Hanya pelapor yang dapat menghapus alert ini.',
        403
      );
    }

    await prisma.$transaction(async (tx) => {
      await tx.notification.deleteMany({
        where: {
          alertId: alert.id,
        },
      });

      await tx.alertResponse.deleteMany({
        where: {
          alertId: alert.id,
        },
      });

      await tx.alertUpdate.deleteMany({
        where: {
          alertId: alert.id,
        },
      });

      await tx.aIIncidentSummary.deleteMany({
        where: {
          alertId: alert.id,
        },
      });

      await tx.alert.delete({
        where: {
          id: alert.id,
        },
      });

      await tx.activityLog.create({
        data: {
          userId: req.user.id,
          action: 'DELETE_ALERT',
          description: `Menghapus alert: ${alert.title}`,
        },
      });
    });

    return sendSuccess(res, 'Alert berhasil dihapus');
  } catch (e) {
    return sendError(res, e.message, 500);
  }
};

module.exports = {
  getAlerts,
  getActiveAlerts,
  getAlertHistory,
  createAlert,
  getAlertById,
  updateAlertStatus,
  deleteAlert,
};
