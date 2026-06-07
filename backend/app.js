const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');

const authRoutes = require('./src/routes/auth.routes');
const categoryRoutes = require('./src/routes/category.routes');
const alertRoutes = require('./src/routes/alert.routes');
const responseRoutes = require('./src/routes/response.routes');
const aiRoutes = require('./src/routes/ai.routes');
const dashboardRoutes = require('./src/routes/dashboard.routes');
const emergencyContactRoutes = require('./src/routes/emergencyContact.routes');
const safetyAiRoutes = require('./src/routes/safetyAi.routes');

const errorMiddleware = require('./src/middleware/error.middleware');

const app = express();

app.use(
  helmet({
    crossOriginResourcePolicy: false,
    crossOriginEmbedderPolicy: false,
    contentSecurityPolicy: false,
  })
);

app.use(
  cors({
    origin: true,
    credentials: false,
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization'],
  })
);

app.use(morgan('dev'));
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

app.get('/', (req, res) => {
  res.json({
    success: true,
    message: 'KomplekGuard AI API is running',
  });
});

app.get('/api/health', (req, res) => {
  res.json({
    success: true,
    message: 'Backend healthy',
    timestamp: new Date().toISOString(),
  });
});

app.use('/api/auth', authRoutes);
app.use('/api/categories', categoryRoutes);
app.use('/api/alerts', alertRoutes);
app.use('/api/alerts', responseRoutes);
app.use('/api/ai', aiRoutes);
app.use('/api/dashboard', dashboardRoutes);
app.use('/api/emergency-contacts', emergencyContactRoutes);
app.use('/api/safety-ai', safetyAiRoutes);

app.use(errorMiddleware);

module.exports = app;
