const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const prisma = require('../config/database');
const { sendSuccess, sendError } = require('../utils/response');

const register = async (req, res) => {
  try {
    const { name, email, password, phone, address, latitude, longitude } = req.body;
    if (!name || !email || !password) return sendError(res, 'Nama, email, dan password wajib diisi');
    const exists = await prisma.user.findUnique({ where: { email } });
    if (exists) return sendError(res, 'Email sudah terdaftar');
    const passwordHash = await bcrypt.hash(password, 10);
    const user = await prisma.user.create({
      data: { name, email, passwordHash, phone, address, latitude, longitude },
    });
    const token = jwt.sign({ id: user.id, email: user.email, role: user.role }, process.env.JWT_SECRET, { expiresIn: '7d' });
    return sendSuccess(res, 'Registrasi berhasil', { token, user: { id: user.id, name: user.name, email: user.email, role: user.role } }, 201);
  } catch (e) {
    return sendError(res, e.message, 500);
  }
};

const login = async (req, res) => {
  try {
    const { email, password } = req.body;
    if (!email || !password) return sendError(res, 'Email dan password wajib diisi');
    const user = await prisma.user.findUnique({ where: { email } });
    if (!user || !user.isActive) return sendError(res, 'Email atau password salah', 401);
    const match = await bcrypt.compare(password, user.passwordHash);
    if (!match) return sendError(res, 'Email atau password salah', 401);
    const token = jwt.sign({ id: user.id, email: user.email, role: user.role }, process.env.JWT_SECRET, { expiresIn: '7d' });
    return sendSuccess(res, 'Login berhasil', { token, user: { id: user.id, name: user.name, email: user.email, role: user.role } });
  } catch (e) {
    return sendError(res, e.message, 500);
  }
};

const me = async (req, res) => {
  try {
    const user = await prisma.user.findUnique({ where: { id: req.user.id }, select: { id: true, name: true, email: true, phone: true, role: true, address: true, latitude: true, longitude: true, createdAt: true } });
    return sendSuccess(res, 'Data user', user);
  } catch (e) {
    return sendError(res, e.message, 500);
  }
};

module.exports = { register, login, me };