const prisma = require('../config/database');

const getProfile = async (req, res) => {
  try {
    const user = await prisma.user.findUnique({
      where: { id: req.user.id },
      select: { id: true, name: true, email: true, phone: true, address: true, image: true },
    });
    if (!user) return res.status(404).json({ success: false, message: 'User tidak ditemukan' });
    res.json({ success: true, data: user });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
};

const updateProfile = async (req, res) => {
  try {
    const { name, phone, address, image } = req.body;
    if (image && image.length > 4000000) {
      return res.status(413).json({ success: false, message: 'Ukuran foto terlalu besar. Maksimal 3MB.' });
    }
    const updateData = {};
    if (name !== undefined) updateData.name = name;
    if (phone !== undefined) updateData.phone = phone;
    if (address !== undefined) updateData.address = address;
    if (image !== undefined) updateData.image = image;
    const user = await prisma.user.update({
      where: { id: req.user.id },
      data: updateData,
      select: { id: true, name: true, email: true, phone: true, address: true, image: true },
    });
    res.json({ success: true, data: user });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
};

module.exports = { getProfile, updateProfile };
