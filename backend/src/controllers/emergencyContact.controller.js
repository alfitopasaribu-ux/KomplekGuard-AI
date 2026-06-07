const prisma = require('../config/database');
const { sendSuccess, sendError } = require('../utils/response');

const getContacts = async (req, res) => {
  try {
    const contacts = await prisma.emergencyContact.findMany({ orderBy: { name: 'asc' } });
    return sendSuccess(res, 'Kontak darurat', contacts);
  } catch (e) { return sendError(res, e.message, 500); }
};

const createContact = async (req, res) => {
  try {
    const contact = await prisma.emergencyContact.create({ data: req.body });
    return sendSuccess(res, 'Kontak dibuat', contact, 201);
  } catch (e) { return sendError(res, e.message, 500); }
};

const updateContact = async (req, res) => {
  try {
    const contact = await prisma.emergencyContact.update({ where: { id: req.params.id }, data: req.body });
    return sendSuccess(res, 'Kontak diperbarui', contact);
  } catch (e) { return sendError(res, e.message, 500); }
};

const deleteContact = async (req, res) => {
  try {
    await prisma.emergencyContact.delete({ where: { id: req.params.id } });
    return sendSuccess(res, 'Kontak dihapus');
  } catch (e) { return sendError(res, e.message, 500); }
};

module.exports = { getContacts, createContact, updateContact, deleteContact };