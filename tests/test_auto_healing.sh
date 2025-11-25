#!/bin/bash
###############################################################################
# Test Auto-Healing Behavior
# 
# This script tests the auto-healing functionality of the MIG
###############################################################################

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }
log_info() { echo -e "${YELLOW}ℹ️  $1${NC}"; }

TERRAFORM_DIR="../terraform"
MIG_ZONE="us-central1-a"

# Get Terraform outputs
cd "$TERRAFORM_DIR" || exit 1
LB_IP=$(terraform output -raw lb_ip_address 2>/dev/null)
MIG_NAME=$(terraform output -raw mig_name 2>/dev/null)
cd - > /dev/null

if [ -z "$LB_IP" ] || [ -z "$MIG_NAME" ]; then
    log_error "Failed to get Terraform outputs"
    exit 1
fi

log_info "Testing Auto-Healing MIG"
echo "Load Balancer: $LB_IP"
echo "MIG Name: $MIG_NAME"
echo "Zone: $MIG_ZONE"
echo ""

# Test 1: Verify MIG is running
log_info "Test 1: Verify MIG is running..."
INSTANCE_COUNT=$(gcloud compute instance-groups managed list-instances "$MIG_NAME" \
    --zone="$MIG_ZONE" \
    --format="value(name)" | wc -l)

if [ "$INSTANCE_COUNT" -ge 3 ]; then
    log_success "MIG has $INSTANCE_COUNT instances running"
else
    log_error "Expected at least 3 instances, found $INSTANCE_COUNT"
    exit 1
fi
echo ""

# Test 2: Check load balancer health
log_info "Test 2: Check load balancer access..."
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "http://$LB_IP/api/health")

if [ "$HTTP_STATUS" -eq 200 ]; then
    log_success "Load balancer is healthy (HTTP $HTTP_STATUS)"
else
    log_error "Load balancer returned HTTP $HTTP_STATUS"
    exit 1
fi
echo ""

# Test 3: Get a healthy instance
log_info "Test 3: Select instance for failure test..."
INSTANCE_NAME=$(gcloud compute instance-groups managed list-instances "$MIG_NAME" \
    --zone="$MIG_ZONE" \
    --filter="status:RUNNING" \
    --format="value(instance)" \
    --limit=1 | xargs basename)

if [ -z "$INSTANCE_NAME" ]; then
    log_error "No running instances found"
    exit 1
fi

log_success "Selected instance: $INSTANCE_NAME"
echo ""

# Test 4: Record initial state
log_info "Test 4: Record initial MIG state..."
INITIAL_INSTANCES=$(gcloud compute instance-groups managed list-instances "$MIG_NAME" \
    --zone="$MIG_ZONE" \
    --format="value(instance)" | xargs -n1 basename | sort)

echo "Initial instances:"
echo "$INITIAL_INSTANCES"
echo ""

# Test 5: Simulate failure
log_info "Test 5: Simulating failure on $INSTANCE_NAME..."
log_info "Stopping webapp service to trigger health check failure..."

gcloud compute ssh "$INSTANCE_NAME" \
    --zone="$MIG_ZONE" \
    --command="sudo systemctl stop webapp" \
    2>/dev/null || log_info "SSH command executed (may show disconnect message)"

log_success "Failure simulated - webapp service stopped"
echo ""

# Test 6: Wait for health check failures
log_info "Test 6: Waiting for health checks to detect failure..."
log_info "This may take 30-60 seconds (2-3 failed health checks)..."

sleep 30

# Check if instance is still there but unhealthy
INSTANCE_STATUS=$(gcloud compute instances describe "$INSTANCE_NAME" \
    --zone="$MIG_ZONE" \
    --format="value(status)" 2>/dev/null || echo "NOT_FOUND")

if [ "$INSTANCE_STATUS" != "NOT_FOUND" ]; then
    log_info "Instance still exists with status: $INSTANCE_STATUS"
else
    log_success "Instance already being replaced"
fi
echo ""

# Test 7: Wait for auto-healing
log_info "Test 7: Waiting for auto-healing to trigger..."
log_info "MIG will recreate the unhealthy instance..."
log_info "This may take 2-3 minutes..."

MAX_WAIT=300
ELAPSED=0
RECREATED=false

while [ $ELAPSED -lt $MAX_WAIT ]; do
    CURRENT_INSTANCES=$(gcloud compute instance-groups managed list-instances "$MIG_NAME" \
        --zone="$MIG_ZONE" \
        --format="value(instance)" | xargs -n1 basename | sort)
    
    # Check if instances have changed
    if [ "$INITIAL_INSTANCES" != "$CURRENT_INSTANCES" ]; then
        RECREATED=true
        log_success "Instance recreation detected!"
        echo ""
        echo "New instances:"
        echo "$CURRENT_INSTANCES"
        break
    fi
    
    # Check for repair operations
    REPAIR_OPS=$(gcloud compute operations list \
        --filter="operationType:compute.instances.repair AND status:DONE" \
        --format="value(targetLink)" \
        --limit=5 | grep -c "$INSTANCE_NAME" || echo "0")
    
    if [ "$REPAIR_OPS" -gt 0 ]; then
        log_success "Repair operation found for $INSTANCE_NAME"
        RECREATED=true
        break
    fi
    
    echo -n "."
    sleep 10
    ELAPSED=$((ELAPSED + 10))
done

echo ""

if [ "$RECREATED" = true ]; then
    log_success "Auto-healing successfully recreated the instance!"
else
    log_error "Auto-healing did not complete within timeout"
    log_info "Check manually: gcloud compute operations list --filter='operationType:compute.instances.repair'"
    exit 1
fi
echo ""

# Test 8: Wait for new instance to become healthy
log_info "Test 8: Waiting for new instance to become healthy..."
log_info "Waiting for initial delay period and health checks (5-6 minutes)..."

sleep 60

MAX_WAIT=360
ELAPSED=0
ALL_HEALTHY=false

while [ $ELAPSED -lt $MAX_WAIT ]; do
    RUNNING_COUNT=$(gcloud compute instance-groups managed list-instances "$MIG_NAME" \
        --zone="$MIG_ZONE" \
        --filter="status:RUNNING" \
        --format="value(instance)" | wc -l)
    
    if [ "$RUNNING_COUNT" -ge 3 ]; then
        log_success "All instances are running ($RUNNING_COUNT)"
        ALL_HEALTHY=true
        break
    fi
    
    echo -n "."
    sleep 15
    ELAPSED=$((ELAPSED + 15))
done

echo ""

if [ "$ALL_HEALTHY" = true ]; then
    log_success "All instances recovered and healthy!"
else
    log_error "Not all instances became healthy within timeout"
    exit 1
fi
echo ""

# Test 9: Verify load balancer still works
log_info "Test 9: Verify load balancer after auto-healing..."
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "http://$LB_IP/api/health")

if [ "$HTTP_STATUS" -eq 200 ]; then
    log_success "Load balancer is still healthy after auto-healing (HTTP $HTTP_STATUS)"
else
    log_error "Load balancer returned HTTP $HTTP_STATUS after auto-healing"
    exit 1
fi
echo ""

# Final summary
echo "========================================"
log_success "Auto-Healing Test Complete! 🎉"
echo "========================================"
echo ""
echo "Summary:"
echo "- Initial instances: $(echo "$INITIAL_INSTANCES" | wc -l)"
echo "- Failed instance: $INSTANCE_NAME"
echo "- Auto-healing triggered: ✅"
echo "- Instance recreated: ✅"
echo "- Service restored: ✅"
echo ""
echo "View operations:"
echo "  gcloud compute operations list --filter='operationType:compute.instances.repair'"
echo ""
echo "View MIG status:"
echo "  gcloud compute instance-groups managed describe $MIG_NAME --zone=$MIG_ZONE"
