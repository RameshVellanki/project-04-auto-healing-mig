#!/bin/bash
###############################################################################
# Simulate Failure for Auto-Healing Testing
# 
# Usage: ./simulate-failure.sh <failure-type>
# Types: stop-service, kill-process, break-health, stress-cpu
###############################################################################

FAILURE_TYPE=${1:-stop-service}

echo "Simulating failure type: $FAILURE_TYPE"

case $FAILURE_TYPE in
  stop-service)
    echo "Stopping webapp service..."
    sudo systemctl stop webapp
    echo "✅ Service stopped - health checks will fail"
    ;;
    
  kill-process)
    echo "Killing Node.js process..."
    sudo pkill -9 node
    echo "✅ Process killed - systemd will restart but might fail health checks temporarily"
    ;;
    
  break-health)
    echo "Breaking health endpoint..."
    curl -X POST http://localhost:8080/admin/break-health
    echo "✅ Health endpoint now returns 503 - auto-healing will trigger"
    ;;
    
  stress-cpu)
    echo "Starting CPU stress test (60 seconds)..."
    stress-ng --cpu 4 --timeout 60s &
    echo "✅ CPU stress started - may cause health check timeouts"
    ;;
    
  *)
    echo "Unknown failure type: $FAILURE_TYPE"
    echo "Available types: stop-service, kill-process, break-health, stress-cpu"
    exit 1
    ;;
esac

echo ""
echo "Monitor auto-healing with:"
echo "  gcloud compute instance-groups managed list-instances webapp-mig --zone=us-central1-a"
echo "  gcloud compute operations list --filter='operationType:compute.instances.repair'"
