const router = require('express').Router();
const { getAlerts, getActiveAlerts, getAlertHistory, createAlert, getAlertById, updateAlertStatus, deleteAlert } = require('../controllers/alert.controller');
const { authMiddleware, adminOnly } = require('../middleware/auth.middleware');

router.get('/', authMiddleware, getAlerts);
router.get('/active', authMiddleware, getActiveAlerts);
router.get('/history', authMiddleware, getAlertHistory);
router.post('/', authMiddleware, createAlert);
router.get('/:id', authMiddleware, getAlertById);
router.put('/:id/status', authMiddleware, adminOnly, updateAlertStatus);
router.delete('/:id', authMiddleware, adminOnly, deleteAlert);

module.exports = router;