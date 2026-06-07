const router = require('express').Router();

const {
  getDailyBriefing,
  chatWithAi,
  getChatHistory,
  createVoiceAlertDraft,
} = require('../controllers/safetyAi.controller');

const { authMiddleware } = require('../middleware/auth.middleware');

router.get('/briefing', authMiddleware, getDailyBriefing);
router.post('/chat', authMiddleware, chatWithAi);
router.get('/chat/history', authMiddleware, getChatHistory);
router.post('/voice-alert-draft', authMiddleware, createVoiceAlertDraft);

module.exports = router;const router = require("express").Router();

// TODO: User will wire controller(s) and endpoints.

module.exports = router;

