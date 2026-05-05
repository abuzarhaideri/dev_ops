const express = require('express');
const cors = require('cors');
const productRoutes = require('./routes/productRoutes');

const path = require('path');
const app = express();

// CORS Configuration - Allow frontend origins
const allowedOrigins = [
  'http://localhost:5173',
  'http://localhost:3000',
  process.env.FRONTEND_URL
].filter(Boolean);

app.use(cors({
  origin: function (origin, callback) {
    // Allow requests with no origin (like mobile apps or Postman)
    if (!origin) return callback(null, true);

    if (allowedOrigins.includes(origin) || origin.endsWith('.vercel.app')) {
      callback(null, true);
    } else {
      callback(new Error('Not allowed by CORS'));
    }
  },
  credentials: true
}));

const fs = require('fs');
const path = require('path');

app.use(express.json());

// Define paths
const publicPath = path.resolve(__dirname, '..', 'public');
const indexPath = path.join(publicPath, 'index.html');

// Serve static frontend files
app.use(express.static(publicPath));

// Routes
app.use('/api/products', productRoutes);

// Health Check Route
app.get('/api/health', (req, res) => {
  res.json({
    status: 'ok',
    message: 'ShopSmart Backend is running',
    timestamp: new Date().toISOString()
  });
});

// Root Route Fallback
app.get('/', (req, res) => {
  if (fs.existsSync(indexPath)) {
    res.sendFile(indexPath);
  } else {
    res.send('ShopSmart Backend Service');
  }
});

// Catch-all route to serve the frontend (for SPA routing)
// Only serve index.html if the request doesn't look like a static asset
app.get('*', (req, res) => {
  if (req.url.startsWith('/api')) {
    return res.status(404).json({ error: 'API route not found' });
  }

  if (fs.existsSync(indexPath)) {
    res.sendFile(indexPath);
  } else {
    res.status(404).send('Not Found');
  }
});

module.exports = app;
