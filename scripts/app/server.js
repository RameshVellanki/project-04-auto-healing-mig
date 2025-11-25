const express = require('express');
const os = require('os');

const app = express();
const port = process.env.PORT || 8080;

// Simulate health status (can be broken for testing)
let isHealthy = true;
let healthCheckCount = 0;
const startTime = Date.now();

// Middleware
app.use(express.json());

// Logging middleware
app.use((req, res, next) => {
  console.log(`[${new Date().toISOString()}] ${req.method} ${req.path} - ${req.ip}`);
  next();
});

// Root endpoint
app.get('/', (req, res) => {
  const uptime = Math.floor((Date.now() - startTime) / 1000);
  res.send(`
    <!DOCTYPE html>
    <html>
    <head>
      <title>Auto-Healing MIG Demo</title>
      <style>
        body {
          font-family: Arial, sans-serif;
          max-width: 900px;
          margin: 50px auto;
          padding: 20px;
          background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
          color: white;
        }
        .container {
          background: rgba(255, 255, 255, 0.1);
          padding: 30px;
          border-radius: 15px;
          backdrop-filter: blur(10px);
        }
        .status {
          display: inline-block;
          padding: 10px 20px;
          border-radius: 20px;
          background: ${isHealthy ? '#00FF00' : '#FF0000'};
          color: #000;
          font-weight: bold;
          font-size: 1.2em;
        }
        .info-box {
          background: rgba(255, 255, 255, 0.2);
          padding: 20px;
          border-radius: 10px;
          margin: 20px 0;
        }
        code {
          background: rgba(0, 0, 0, 0.3);
          padding: 3px 8px;
          border-radius: 4px;
        }
        .endpoint {
          margin: 8px 0;
          font-family: 'Courier New', monospace;
        }
      </style>
    </head>
    <body>
      <div class="container">
        <h1>🏥 Auto-Healing MIG Demo</h1>
        <div class="status">${isHealthy ? '✅ HEALTHY' : '❌ UNHEALTHY'}</div>
        
        <div class="info-box">
          <h2>Instance Information</h2>
          <p><strong>Hostname:</strong> <code>${os.hostname()}</code></p>
          <p><strong>Platform:</strong> <code>${os.platform()} ${os.arch()}</code></p>
          <p><strong>Node.js:</strong> <code>${process.version}</code></p>
          <p><strong>Uptime:</strong> <code>${uptime}s</code></p>
          <p><strong>Health Checks:</strong> <code>${healthCheckCount}</code></p>
          <p><strong>Memory:</strong> <code>${Math.round(os.freemem() / 1024 / 1024)}MB free / ${Math.round(os.totalmem() / 1024 / 1024)}MB total</code></p>
        </div>

        <div class="info-box">
          <h2>API Endpoints</h2>
          <div class="endpoint">GET /api/health - Health check endpoint</div>
          <div class="endpoint">GET /api/info - Instance information</div>
          <div class="endpoint">POST /admin/break-health - Simulate failure</div>
          <div class="endpoint">POST /admin/restore-health - Restore health</div>
          <div class="endpoint">GET /api/stress - CPU stress test</div>
        </div>

        <div class="info-box">
          <h2>Auto-Healing Features</h2>
          <ul>
            <li>✅ Automatic health monitoring</li>
            <li>✅ Instance recreation on failure</li>
            <li>✅ Load balancer integration</li>
            <li>✅ Zero-downtime recovery</li>
            <li>✅ Configurable health thresholds</li>
          </ul>
        </div>
      </div>
    </body>
    </html>
  `);
});

// Health check endpoint (for load balancer)
app.get('/api/health', (req, res) => {
  healthCheckCount++;
  
  if (isHealthy) {
    res.status(200).json({
      status: 'healthy',
      timestamp: new Date().toISOString(),
      hostname: os.hostname(),
      uptime: process.uptime(),
      checks: healthCheckCount
    });
  } else {
    res.status(503).json({
      status: 'unhealthy',
      timestamp: new Date().toISOString(),
      hostname: os.hostname(),
      message: 'Service is unhealthy - auto-healing should trigger'
    });
  }
});

// Instance info endpoint
app.get('/api/info', (req, res) => {
  res.json({
    hostname: os.hostname(),
    platform: os.platform(),
    arch: os.arch(),
    nodeVersion: process.version,
    uptime: process.uptime(),
    healthStatus: isHealthy,
    healthCheckCount: healthCheckCount,
    memory: {
      total: os.totalmem(),
      free: os.freemem(),
      used: os.totalmem() - os.freemem()
    },
    cpu: os.cpus(),
    loadAverage: os.loadavg(),
    timestamp: new Date().toISOString()
  });
});

// Admin endpoint: Break health (for testing auto-healing)
app.post('/admin/break-health', (req, res) => {
  isHealthy = false;
  console.log('⚠️  Health status set to UNHEALTHY - auto-healing will trigger');
  res.json({
    message: 'Health status set to unhealthy',
    note: 'Health checks will fail and auto-healing should recreate this instance',
    timestamp: new Date().toISOString()
  });
});

// Admin endpoint: Restore health
app.post('/admin/restore-health', (req, res) => {
  isHealthy = true;
  console.log('✅ Health status restored to HEALTHY');
  res.json({
    message: 'Health status restored',
    timestamp: new Date().toISOString()
  });
});

// Stress endpoint (for testing)
app.get('/api/stress', (req, res) => {
  const duration = parseInt(req.query.duration) || 5000;
  const start = Date.now();
  
  // CPU-intensive work
  while (Date.now() - start < duration) {
    Math.sqrt(Math.random());
  }
  
  res.json({
    message: 'Stress test completed',
    duration: duration,
    hostname: os.hostname(),
    timestamp: new Date().toISOString()
  });
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({
    error: 'Not Found',
    path: req.path,
    timestamp: new Date().toISOString()
  });
});

// Error handler
app.use((err, req, res, next) => {
  console.error('Error:', err);
  res.status(500).json({
    error: 'Internal Server Error',
    message: err.message,
    timestamp: new Date().toISOString()
  });
});

// Start server
const server = app.listen(port, '0.0.0.0', () => {
  console.log('='.repeat(60));
  console.log('🏥 Auto-Healing MIG Application Started');
  console.log('='.repeat(60));
  console.log(`Port: ${port}`);
  console.log(`Hostname: ${os.hostname()}`);
  console.log(`Node.js: ${process.version}`);
  console.log(`Health Status: ${isHealthy ? 'HEALTHY ✅' : 'UNHEALTHY ❌'}`);
  console.log('='.repeat(60));
  console.log(`Health endpoint: http://localhost:${port}/api/health`);
  console.log('='.repeat(60));
});

// Graceful shutdown
const shutdown = (signal) => {
  console.log(`\n${signal} received, shutting down gracefully...`);
  server.close(() => {
    console.log('Server closed');
    process.exit(0);
  });
  
  setTimeout(() => {
    console.error('Forced shutdown');
    process.exit(1);
  }, 10000);
};

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));
