# Project 4: Auto-Healing Managed Instance Group 🏥

An intermediate-level GCP project implementing self-healing infrastructure using Managed Instance Groups with automated health checks, instance recreation, and failure recovery.

## 🏗️ Architecture

```
                    ┌─────────────────────────┐
                    │   HTTP Load Balancer    │
                    │   (External Access)     │
                    └───────────┬─────────────┘
                                │
                ┌───────────────┴───────────────┐
                │    Backend Service            │
                │    (Health-Based Routing)     │
                └───────────────┬───────────────┘
                                │
          ┌─────────────────────┴─────────────────────┐
          │   Auto-Healing Managed Instance Group     │
          │                                            │
          │   ┌────────┐  ┌────────┐  ┌────────┐    │
          │   │ VM 1   │  │ VM 2   │  │ VM 3   │    │
          │   │ ✅ OK  │  │ ❌ FAIL│  │ ✅ OK  │    │
          │   └────────┘  └────────┘  └────────┘    │
          │                    │                      │
          │                    ▼                      │
          │            [Auto-Healing]                 │
          │                    │                      │
          │                    ▼                      │
          │             ┌────────────┐                │
          │             │  New VM 2' │                │
          │             │  ✅ READY  │                │
          │             └────────────┘                │
          └────────────────────────────────────────────┘

Health Check Monitoring:
┌─────────────────────────────────────────┐
│  Health Check (Every 10s)               │
│  - Check Interval: 10 seconds           │
│  - Timeout: 5 seconds                   │
│  - Unhealthy Threshold: 2 consecutive   │
│  - Initial Delay: 5 minutes             │
│                                         │
│  If Unhealthy → Recreate Instance       │
└─────────────────────────────────────────┘
```

## 🎯 Learning Objectives

- Configure managed instance groups (MIGs)
- Implement auto-healing policies
- Design effective health checks
- Handle instance failures gracefully
- Monitor instance health and recovery
- Implement load balancing with health routing
- Test failure scenarios and recovery
- Configure auto-scaling with healing
- Implement regional high availability
- Monitor and log healing events

## 📋 Prerequisites

- GCP Project with billing enabled
- Terraform >= 1.6 installed
- `gcloud` CLI configured
- GitHub repository
- GitHub Secrets configured (`GCP_SA_KEY`)
- Understanding of MIGs and health checks

## 🔧 Tech Stack

- **IaC**: Terraform
- **CI/CD**: GitHub Actions
- **Application**: Node.js + Express (with health endpoints)
- **Compute**: Managed Instance Group (3-5 instances)
- **Load Balancing**: HTTP Load Balancer
- **Health Checks**: HTTP-based with configurable thresholds
- **Monitoring**: Cloud Logging + Cloud Monitoring
- **IAM**: Custom Service Account

## 🚀 Quick Start

### 1. Clone Repository
```bash
git clone <your-repo-url>
cd project-04-auto-healing-mig
```

### 2. Configure Variables
```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit with your project details
```

### 3. Deploy Infrastructure
```bash
terraform init
terraform plan
terraform apply
```

### 4. Test Auto-Healing
```bash
# Get instance names
gcloud compute instances list --filter="name:webapp-"

# Simulate failure by stopping the app
gcloud compute ssh webapp-<instance> --zone=us-central1-a \
  --command="sudo systemctl stop webapp"

# Watch auto-healing in action
gcloud compute operations list --filter="operationType:compute.instances.repair"
```

### 5. Verify Recovery
```bash
# Check MIG status
gcloud compute instance-groups managed describe webapp-mig --zone=us-central1-a

# View healing events
gcloud compute instance-groups managed list-instances webapp-mig --zone=us-central1-a
```

## 📁 Project Structure

```
project-04-auto-healing-mig/
├── .github/
│   └── workflows/
│       ├── deploy.yml           # Deploy MIG infrastructure
│       ├── test-healing.yml     # Test auto-healing behavior
│       └── destroy.yml          # Destroy infrastructure
├── terraform/
│   ├── main.tf                  # Provider configuration
│   ├── variables.tf             # Input variables
│   ├── terraform.tfvars.example # Example values
│   ├── mig.tf                   # MIG and health check config
│   ├── load-balancer.tf         # Load balancer resources
│   └── outputs.tf               # Output values
├── scripts/
│   ├── startup.sh               # VM initialization
│   ├── app/
│   │   ├── server.js            # Node.js application
│   │   └── package.json         # Dependencies
│   ├── simulate-failure.sh      # Test failure scenarios
│   └── check-health.sh          # Health verification
├── tests/
│   └── test_auto_healing.sh     # Auto-healing tests
├── README.md
└── .gitignore
```

## 🏥 Auto-Healing Configuration

### Health Check Settings

```hcl
health_check_interval_sec  = 10    # Check every 10 seconds
health_check_timeout_sec   = 5     # 5 second timeout
healthy_threshold          = 2     # 2 consecutive successes = healthy
unhealthy_threshold        = 2     # 2 consecutive failures = unhealthy
initial_delay_sec          = 300   # Wait 5 minutes after instance start
```

### Auto-Healing Policy

**When Instance Fails:**
1. Health check detects failure (2 consecutive failures)
2. MIG marks instance as unhealthy
3. MIG automatically recreates the instance
4. New instance boots and runs startup script
5. Initial delay period (5 minutes)
6. Health checks resume
7. Instance marked healthy after 2 successful checks
8. Instance receives traffic from load balancer

### Failure Detection

**Application-Level Failures:**
- Application crashes
- Service stops responding
- HTTP errors (500s)
- Timeout on health endpoint

**Instance-Level Failures:**
- VM crash or reboot
- Network connectivity issues
- Resource exhaustion (memory/CPU)

**System-Level Failures:**
- Host maintenance
- Hardware failures
- Zone outages (with regional MIGs)

## 🧪 Testing Auto-Healing

### Test 1: Stop Application Service
```bash
# Stop the webapp service
gcloud compute ssh webapp-xxxx --zone=us-central1-a \
  --command="sudo systemctl stop webapp"

# Watch for auto-healing
watch -n 5 'gcloud compute instance-groups managed list-instances webapp-mig --zone=us-central1-a'
```

### Test 2: Simulate Application Crash
```bash
# Kill the application process
gcloud compute ssh webapp-xxxx --zone=us-central1-a \
  --command="sudo pkill -9 node"

# Health checks will fail and trigger recreation
```

### Test 3: Overload Instance
```bash
# Create CPU stress
gcloud compute ssh webapp-xxxx --zone=us-central1-a \
  --command="stress-ng --cpu 4 --timeout 600s"

# May trigger health check failures
```

### Test 4: Break Health Endpoint
```bash
# Use the failure simulation script
curl http://<INSTANCE_IP>:8080/admin/break-health

# Health checks will fail immediately
# Auto-healing will recreate instance
```

### Test 5: Delete Instance Manually
```bash
# MIG will automatically recreate
gcloud compute instances delete webapp-xxxx --zone=us-central1-a --quiet
```

## 📊 Monitoring Auto-Healing

### View Healing Events in Console
1. Go to Compute Engine > Instance Groups
2. Select your MIG
3. Click "Details" tab
4. View "Current actions" and "Recent errors"

### Command Line Monitoring
```bash
# View MIG status
gcloud compute instance-groups managed describe webapp-mig --zone=us-central1-a

# List all instances with status
gcloud compute instance-groups managed list-instances webapp-mig --zone=us-central1-a

# View recent operations
gcloud compute operations list --filter="operationType:compute.instances.repair" --limit=20

# View health check status
gcloud compute backend-services get-health webapp-backend-service --global
```

### Cloud Logging Queries

**View Auto-Healing Events:**
```
resource.type="gce_instance"
protoPayload.methodName="v1.compute.instances.repair"
```

**View Health Check Failures:**
```
resource.type="gce_instance"
jsonPayload.message=~"health check failed"
```

**View Instance Recreations:**
```
resource.type="gce_instance_group_manager"
protoPayload.methodName="v1.compute.instanceGroupManagers.recreateInstances"
```

### Metrics to Monitor

**MIG Metrics:**
- `compute.googleapis.com/instance_group/size` - Current instance count
- `compute.googleapis.com/instance_group/predicted_capacity` - Expected capacity
- `loadbalancing.googleapis.com/https/backend_request_count` - Traffic distribution

**Instance Metrics:**
- `compute.googleapis.com/instance/cpu/utilization` - CPU usage
- `compute.googleapis.com/instance/network/received_bytes_count` - Network traffic
- `agent.googleapis.com/memory/percent_used` - Memory usage

**Health Check Metrics:**
- `loadbalancing.googleapis.com/https/backend_latencies` - Response times
- Backend health status (healthy/unhealthy count)

## 💰 Cost Estimate

**Monthly Cost (US Central1):**
- MIG (3x e2-micro): ~$22.50/month
- Load Balancer: ~$18/month
- Health Checks: Included
- **Total**: ~$40.50/month

**Auto-Healing Cost Impact:**
- Instance recreation: No additional charge
- Slightly higher if instances recreated frequently
- Consider setting max recreation rate limits

## 🛡️ Auto-Healing Best Practices

### 1. Set Appropriate Initial Delay
```hcl
initial_delay_sec = 300  # 5 minutes for app startup
```
- Too short: Instances marked unhealthy during startup
- Too long: Slow failure detection
- Recommendation: 2-5 minutes for most apps

### 2. Configure Sensible Thresholds
```hcl
unhealthy_threshold = 2  # 2 consecutive failures
healthy_threshold   = 2  # 2 consecutive successes
```
- Avoid single check failures triggering recreation
- Balance between false positives and detection speed

### 3. Implement Comprehensive Health Checks
- Check application health, not just HTTP 200
- Verify database connectivity
- Check critical dependencies
- Return detailed health status

### 4. Set Recreation Limits
```hcl
max_unavailable_fixed = 1  # Recreate 1 at a time
```
- Prevents cascading failures
- Maintains service availability
- Controls rate of change

### 5. Monitor and Alert
- Alert on high recreation rates
- Track time-to-recovery metrics
- Monitor health check success rates
- Set up incident response procedures

## 🐛 Troubleshooting

### Instances Keep Getting Recreated
```bash
# Check health check configuration
gcloud compute health-checks describe http-health-check

# Test health endpoint manually
curl http://<INSTANCE_IP>:8080/api/health

# Check application logs
gcloud compute ssh webapp-xxxx --command="journalctl -u webapp -n 100"

# Increase initial delay if needed
```

### Health Checks Always Fail
```bash
# Verify firewall rules
gcloud compute firewall-rules list --filter="name:allow-health-check"

# Check application is running
gcloud compute ssh webapp-xxxx --command="systemctl status webapp"

# Test from health check IP ranges
# 35.191.0.0/16, 130.211.0.0/22
```

### Auto-Healing Not Triggering
```bash
# Verify auto-healing policy is enabled
gcloud compute instance-groups managed describe webapp-mig --zone=us-central1-a

# Check if initial delay has passed
# (5 minutes after instance start)

# Verify health check is configured
```

### Too Many Instances Being Recreated
```bash
# Check for cascading failures
# Review application logs for errors
# Verify resource limits (CPU/memory)
# Check for external dependency failures
```

## 🧹 Cleanup

```bash
cd terraform
terraform destroy
```

**Deleted Resources:**
- Managed instance group
- All VM instances
- Load balancer components
- Health checks
- Firewall rules
- Service account

## 🎓 Learning Outcomes

After completing this project, you'll understand:
- ✅ Managed instance group configuration
- ✅ Auto-healing policy implementation
- ✅ Health check design and configuration
- ✅ Failure detection and recovery
- ✅ Load balancer health routing
- ✅ Instance lifecycle management
- ✅ Monitoring and observability
- ✅ High availability patterns
- ✅ Failure simulation and testing
- ✅ Production resilience practices

## 📚 Next Steps

**Project Progression:**
1. ✅ **Project 1**: Simple Web Server (completed)
2. ✅ **Project 2**: Multi-VM Application Stack (completed)
3. ✅ **Project 3**: Blue-Green Deployment (completed)
4. ✅ **Project 4**: Auto-Healing MIG (current)
5. 🔜 **Project 5**: Scheduled VM Management
6. 🔜 **Project 6**: Custom Image Pipeline with Packer

**Enhancement Ideas:**
- Implement regional MIG for multi-zone resilience
- Add auto-scaling with healing
- Implement custom health check scripts
- Add Slack/email notifications for healing events
- Implement canary deployments with auto-rollback
- Add chaos engineering tests
- Implement blue-green with auto-healing

## 🔗 Related Projects

- **Project 3**: Blue-Green Deployment (zero-downtime updates)
- **Project 5**: Scheduled VM Management (cost optimization)
- **Project 11**: Self-Healing Chaos Engineering (advanced testing)

## 🤝 Contributing

Contributions welcome! Please open issues or pull requests.

## 📄 License

MIT License - free for learning purposes.

---

**Build Resilient Infrastructure! 🏥💪**
