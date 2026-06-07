const router = require("express").Router();

const {
  getCategories,
  createCategory,
} = require("../controllers/category.controller");

const {
  authMiddleware,
  adminOnly,
} = require("../middleware/auth.middleware");

router.get("/", getCategories);
router.post("/", authMiddleware, adminOnly, createCategory);

module.exports = router;

