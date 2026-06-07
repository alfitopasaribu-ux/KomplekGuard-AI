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
  aiSummaries: {
    orderBy: {
      createdAt: "desc",
    },
  },
  responses: {
    orderBy: {
      createdAt: "desc",
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
};

exports.createAlert = async (req, res) => {
  try {
    const userId = getUserId(req);

    if (!userId) {
      return failed(res, "User tidak valid. Silakan login ulang.", 401);
    }

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
      return failed(
        res,
        "Judul, deskripsi, latitude, dan longitude wajib diisi.",
        400
      );
    }

    const user = await prisma.user.findUnique({
      where: { id: userId },
    });

    if (!user) {
      return failed(res, "User tidak ditemukan.", 404);
    }

    let category = null;

    if (categoryId) {
      category = await prisma.alertCategory.findUnique({
        where: { id: categoryId },
      });

      if (!category) {
        return failed(res, "Kategori alert tidak ditemukan.", 404);
      }

      if (category.name === "Lainnya" && !customCategory) {
        return failed(
          res,
          "Jenis alert lainnya wajib diisi jika memilih kategori Lainnya.",
          400
        );
      }
    }

    const alert = await prisma.alert.create({
      data: {
        userId,
        categoryId: categoryId || null,
        neighborhoodId: user.neighborhoodId || null,
        customCategory: customCategory || null,
        title,
        description,
        latitude: Number(latitude),
        longitude: Number(longitude),
        address: address || user.address || null,
        photoUrl: photoUrl || null,
        status: "AKTIF",
      },
      include: alertInclude,
    });

    await prisma.activityLog.create({
      data: {
        userId,
        action: "CREATE_ALERT",
        description: `Membuat alert: ${title}`,
      },
    });

    return success(res, "Alert berhasil dibuat.", alert);
  } catch (error) {
    return failed(res, error.message);
  }
};

exports.getAlerts = async (req, res) => {
  try {
    const alerts = await prisma.alert.findMany({
      orderBy: {
        createdAt: "desc",
      },
      include: alertInclude,
    });

    return success(res, "Daftar alert berhasil diambil.", alerts);
  } catch (error) {
    return failed(res, error.message);
  }
};

exports.getActiveAlerts = async (req, res) => {
  try {
    const alerts = await prisma.alert.findMany({
      where: {
        status: {
          in: ["AKTIF", "DIPROSES"],
        },
      },
      orderBy: {
        createdAt: "desc",
      },
      include: alertInclude,
    });

    return success(res, "Daftar alert aktif berhasil diambil.", alerts);
  } catch (error) {
    return failed(res, error.message);
  }
};

exports.getAlertHistory = async (req, res) => {
  try {
    const alerts = await prisma.alert.findMany({
      where: {
        status: {
          in: ["SELESAI", "DIBATALKAN"],
        },
      },
      orderBy: {
        createdAt: "desc",
      },
      include: alertInclude,
    });

    return success(res, "Riwayat alert berhasil diambil.", alerts);
  } catch (error) {
    return failed(res, error.message);
  }
};

exports.getAlertById = async (req, res) => {
  try {
    const { id } = req.params;

    const alert = await prisma.alert.findUnique({
      where: { id },
      include: alertInclude,
    });

    if (!alert) {
      return failed(res, "Alert tidak ditemukan.", 404);
    }

    return success(res, "Detail alert berhasil diambil.", alert);
  } catch (error) {
    return failed(res, error.message);
  }
};

exports.updateAlertStatus = async (req, res) => {
  try {
    const userId = getUserId(req);
    const { id } = req.params;
    const { status, note } = req.body;

    const allowedStatus = ["AKTIF", "DIPROSES", "SELESAI", "DIBATALKAN"];

    if (!allowedStatus.includes(status)) {
      return failed(res, "Status alert tidak valid.", 400);
    }

    const oldAlert = await prisma.alert.findUnique({
      where: { id },
    });

    if (!oldAlert) {
      return failed(res, "Alert tidak ditemukan.", 404);
    }

    const alert = await prisma.alert.update({
      where: { id },
      data: {
        status,
        resolvedAt:
          status === "SELESAI" || status === "DIBATALKAN"
            ? new Date()
            : null,
      },
      include: alertInclude,
    });

    await prisma.alertUpdate.create({
      data: {
        alertId: id,
        userId,
        oldStatus: oldAlert.status,
        newStatus: status,
        note: note || null,
      },
    });

    await prisma.activityLog.create({
      data: {
        userId,
        action: "UPDATE_ALERT_STATUS",
        description: `Mengubah status alert dari ${oldAlert.status} menjadi ${status}`,
      },
    });

    return success(res, "Status alert berhasil diperbarui.", alert);
  } catch (error) {
    return failed(res, error.message);
  }
};

exports.deleteAlert = async (req, res) => {
  try {
    const { id } = req.params;

    await prisma.alert.delete({
      where: { id },
    });

    return success(res, "Alert berhasil dihapus.");
  } catch (error) {
    return failed(res, error.message);
  }
};