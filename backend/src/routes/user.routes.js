const express = require('express');
const router = express.Router();
const { getProfile, updateProfile } = require('../controllers/user.controller');
const { authMiddleware } = require('../middleware/auth.middleware');

router.get('/profile', authMiddleware, getProfile);
router.put('/profile', authMiddleware, updateProfile);

module.exports = router;


