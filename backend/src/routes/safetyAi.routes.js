const express = require('express');

const {
  getDailyBriefing,
  chatWithAi,
  getChatHistory,
  createVoiceAlertDraft,
} = require('../controllers/safetyAi.controller');

const { authMiddleware } = require('../middleware/auth.middleware');

const router = express.Router();

router.get('/briefing', authMiddleware, getDailyBriefing);
router.post('/chat', authMiddleware, chatWithAi);
router.get('/chat/history', authMiddleware, getChatHistory);
router.post('/voice-alert-draft', authMiddleware, createVoiceAlertDraft);

module.exports = router;
