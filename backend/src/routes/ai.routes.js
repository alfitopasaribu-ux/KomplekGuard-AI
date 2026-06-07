const router = require('express').Router();
const { fullAnalysis } = require('../controllers/ai.controller');
const { authMiddleware } = require('../middleware/auth.middleware');

router.post('/full-analysis', authMiddleware, fullAnalysis);

module.exports = router;