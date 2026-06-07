const router = require('express').Router();
const { respondToAlert, getAlertResponses } = require('../controllers/response.controller');
const { authMiddleware } = require('../middleware/auth.middleware');

router.post('/:id/respond', authMiddleware, respondToAlert);
router.get('/:id/responses', authMiddleware, getAlertResponses);

module.exports = router;