#!/bin/bash
###############################################################################
# Startup Script for Auto-Healing MIG Demo
# 
# Installs and configures Node.js application with health checks
###############################################################################

set -e

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

log "Starting auto-healing MIG setup..."

# Update system
log "Updating system packages..."
apt-get update
apt-get upgrade -y

# Install Node.js 18.x
log "Installing Node.js..."
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt-get install -y nodejs

# Install stress-ng for testing
log "Installing stress-ng..."
apt-get install -y stress-ng

# Create application directory
log "Creating application directory..."
mkdir -p /opt/webapp
cd /opt/webapp

# Create package.json
cat > package.json <<'EOF'
{
  "name": "auto-healing-webapp",
  "version": "1.0.0",
  "description": "Web application for auto-healing MIG demonstration",
  "main": "server.js",
  "scripts": {
    "start": "node server.js"
  },
  "dependencies": {
    "express": "^4.18.2"
  }
}
EOF

# Create server.js (inline from separate file would be better, but embedding here for simplicity)
log "Creating application server..."
cat > server.js <<'NODEJS_EOF'
const express = require('express');
const os = require('os');

const app = express();
const port = process.env.PORT || 8080;

let isHealthy = true;
let healthCheckCount = 0;
const startTime = Date.now();

app.use(express.json());

app.use((req, res, next) => {
  console.log(`[${new Date().toISOString()}] ${req.method} ${req.path}`);
  next();
});

app.get('/', (req, res) => {
  const uptime = Math.floor((Date.now() - startTime) / 1000);
  res.send(`
    <h1>🏥 Auto-Healing MIG Demo</h1>
    <p>Status: ${isHealthy ? '✅ HEALTHY' : '❌ UNHEALTHY'}</p>
    <p>Hostname: ${os.hostname()}</p>
    <p>Uptime: ${uptime}s</p>
    <p>Health Checks: ${healthCheckCount}</p>
    <h2>Endpoints:</h2>
    <ul>
      <li>GET /api/health - Health check</li>
      <li>GET /api/info - Instance info</li>
      <li>POST /admin/break-health - Simulate failure</li>
      <li>POST /admin/restore-health - Restore health</li>
    </ul>
  `);
});

app.get('/api/health', (req, res) => {
  healthCheckCount++;
  if (isHealthy) {
    res.status(200).json({ status: 'healthy', hostname: os.hostname(), checks: healthCheckCount });
  } else {
    res.status(503).json({ status: 'unhealthy', hostname: os.hostname() });
  }
});

app.get('/api/info', (req, res) => {
  res.json({
    hostname: os.hostname(),
    platform: os.platform(),
    nodeVersion: process.version,
    uptime: process.uptime(),
    healthStatus: isHealthy,
    healthCheckCount: healthCheckCount
  });
});

app.post('/admin/break-health', (req, res) => {
  isHealthy = false;
  console.log('⚠️ Health set to UNHEALTHY');
  res.json({ message: 'Health broken', note: 'Auto-healing will trigger' });
});

app.post('/admin/restore-health', (req, res) => {
  isHealthy = true;
  console.log('✅ Health restored');
  res.json({ message: 'Health restored' });
});

app.listen(port, '0.0.0.0', () => {
  console.log(`🏥 Auto-Healing MIG app running on port ${port}`);
  console.log(`Hostname: ${os.hostname()}`);
});
NODEJS_EOF

# Install dependencies
log "Installing Node.js dependencies..."
npm install --production

# Create systemd service
log "Creating systemd service..."
cat > /etc/systemd/system/webapp.service <<'EOF'
[Unit]
Description=Auto-Healing MIG Web Application
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/webapp
Environment="NODE_ENV=production"
Environment="PORT=8080"
ExecStart=/usr/bin/node /opt/webapp/server.js
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# Enable and start service
log "Starting webapp service..."
systemctl daemon-reload
systemctl enable webapp.service
systemctl start webapp.service

# Wait for service to start
sleep 3

# Verify service is running
if systemctl is-active --quiet webapp; then
    log "✅ Webapp service is running"
else
    log "❌ ERROR: Webapp service failed to start"
    journalctl -u webapp -n 50
    exit 1
fi

log "==============================================="
log "Auto-Healing MIG Setup Complete!"
log "==============================================="
log "Node.js version: $(node --version)"
log "Service status: $(systemctl is-active webapp)"
log "Application port: 8080"
log "Health endpoint: http://localhost:8080/api/health"
log "==============================================="

exit 0
