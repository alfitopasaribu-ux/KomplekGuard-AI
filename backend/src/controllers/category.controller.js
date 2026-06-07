const prisma = require('../config/database');
const { sendSuccess, sendError } = require('../utils/response');

const getCategories = async (req, res) => {
  try {
    const categories = await prisma.alertCategory.findMany({ orderBy: [{ type: 'asc' }, { priorityLevel: 'desc' }] });
    return sendSuccess(res, 'Kategori alert', categories);
  } catch (e) { return sendError(res, e.message, 500); }
};

const createCategory = async (req, res) => {
  try {
    const { name, type, icon, color, priorityLevel } = req.body;
    const category = await prisma.alertCategory.create({ data: { name, type, icon, color, priorityLevel } });
    return sendSuccess(res, 'Kategori dibuat', category, 201);
  } catch (e) { return sendError(res, e.message, 500); }
};

module.exports = { getCategories, createCategory };