const router = require('express').Router();
const { getContacts, createContact, updateContact, deleteContact } = require('../controllers/emergencyContact.controller');
const { authMiddleware, adminOnly } = require('../middleware/auth.middleware');

router.get('/', authMiddleware, getContacts);
router.post('/', authMiddleware, adminOnly, createContact);
router.put('/:id', authMiddleware, adminOnly, updateContact);
router.delete('/:id', authMiddleware, adminOnly, deleteContact);

module.exports = router;