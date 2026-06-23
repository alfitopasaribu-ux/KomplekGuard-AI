const prisma = require('../config/database');

const getProfile = async (req, res) => {
  try {
    const user = await prisma.user.findUnique({
      where: { id: req.user.id },
      select: { id: true, name: true, email: true, phone: true, address: true, image: true },
    });
    res.json({ success: true, data: user });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
};

const updateProfile = async (req, res) => {
  try {
    const { name, phone, address, image } = req.body;
    const user = await prisma.user.update({
      where: { id: req.user.id },
      data: { name, phone, address, image },
      select: { id: true, name: true, email: true, phone: true, address: true, image: true },
    });
    res.json({ success: true, data: user });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
};

module.exports = { getProfile, updateProfile };


