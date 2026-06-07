const router = require('express').Router();
const { getDashboard } = require('../controllers/dashboard.controller');
const { authMiddleware } = require('../middleware/auth.middleware');

router.get('/', authMiddleware, getDashboard);

module.exports = router;