const router = require('express').Router();

const {
  getAlerts,
  getActiveAlerts,
  getAlertHistory,
  createAlert,
  getAlertById,
  updateAlertStatus,
  deleteAlert,
} = require('../controllers/alert.controller');

const { authMiddleware } = require('../middleware/auth.middleware');

router.get('/', authMiddleware, getAlerts);
router.get('/active', authMiddleware, getActiveAlerts);
router.get('/history', authMiddleware, getAlertHistory);
router.post('/', authMiddleware, createAlert);
router.get('/:id', authMiddleware, getAlertById);

// UPDATE dan DELETE tetap ada,
// tapi controller memastikan hanya pelapor yang bisa menjalankan.
router.put('/:id/status', authMiddleware, updateAlertStatus);
router.delete('/:id', authMiddleware, deleteAlert);

module.exports = router;
