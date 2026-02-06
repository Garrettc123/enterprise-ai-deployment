# Enterprise AI Grid - Complete Deployment

🚀 **Production-ready deployment infrastructure for Enterprise AI Grid**

## 📋 Overview

Complete infrastructure-as-code deployment for a scalable Enterprise AI platform with:

- **AWS Infrastructure**: VPC, EKS, RDS, ElastiCache, S3
- **Kubernetes**: Multi-service orchestration with auto-scaling
- **CI/CD**: GitHub Actions pipelines for automated deployments
- **Monitoring**: Prometheus, Grafana, CloudWatch integration
- **Security**: IAM policies, secrets management, network policies

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      AWS Cloud (us-east-1)                  │
│  ┌───────────────────────────────────────────────────────┐  │
│  │                    VPC (10.0.0.0/16)                  │  │
│  │  ┌──────────────────────────────────────────────────┐ │  │
│  │  │          EKS Cluster (Kubernetes 1.28)           │ │  │
│  │  │  ┌────────────┐  ┌────────────┐  ┌────────────┐  │ │  │
│  │  │  │ API Gateway│  │ Processor  │  │ML Inference│  │ │  │
│  │  │  │   (x5)     │  │   (x3)     │  │   (x10)    │  │ │  │
│  │  │  └────────────┘  └────────────┘  └────────────┘  │ │  │
│  │  └──────────────────────────────────────────────────┘ │  │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────────────────┐ │  │
│  │  │   RDS    │  │   Redis  │  │      S3 Buckets      │ │  │
│  │  │PostgreSQL│  │  Cluster │  │  (Data/Logs/Models)  │ │  │
│  │  └──────────┘  └──────────┘  └──────────────────────┘ │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

## 🚀 Quick Start

### Prerequisites

1. **AWS Account** with admin access
2. **GitHub Account** with repository access
3. **Local Tools**:
   ```bash
   # Install required tools
   brew install terraform aws-cli kubectl helm
   
   # Verify installations
   terraform --version  # >= 1.6.0
   aws --version        # >= 2.0
   kubectl version      # >= 1.28
   ```

### 1. Configure AWS Credentials

```bash
# Configure AWS CLI
aws configure
AWS Access Key ID: YOUR_ACCESS_KEY
AWS Secret Access Key: YOUR_SECRET_KEY
Default region: us-east-1
Default output format: json

# Verify access
aws sts get-caller-identity
```

### 2. Configure GitHub Secrets

Add these secrets to your GitHub repository:

**Settings → Secrets → Actions → New repository secret**

- `AWS_ACCESS_KEY_ID`: Your AWS access key
- `AWS_SECRET_ACCESS_KEY`: Your AWS secret key
- `DATABASE_PASSWORD`: Strong password for RDS
- `REDIS_PASSWORD`: Strong password for Redis

### 3. Initialize Backend

```bash
# Create S3 bucket for Terraform state
aws s3 mb s3://enterprise-ai-terraform-state --region us-east-1

# Create DynamoDB table for state locking
aws dynamodb create-table \
  --table-name enterprise-ai-terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

### 4. Deploy Everything

```bash
# Clone repository
git clone https://github.com/Garrettc123/enterprise-ai-deployment.git
cd enterprise-ai-deployment

# Push to trigger deployment
git add .
git commit -m "Initial deployment"
git push origin main
```

**GitHub Actions will automatically:**
1. ✅ Validate all configurations
2. 🔒 Run security scans
3. 🐳 Build and push Docker images
4. 🏗️ Deploy AWS infrastructure via Terraform
5. ☸️ Deploy services to Kubernetes
6. 📊 Set up monitoring stack
7. ✅ Run health checks

## 📁 Repository Structure

```
.
├── .github/
│   └── workflows/
│       ├── deploy.yml          # Main deployment pipeline
│       └── destroy.yml         # Infrastructure teardown
├── terraform/
│   ├── modules/
│   │   ├── vpc/
│   │   ├── eks/
│   │   ├── rds/
│   │   └── elasticache/
│   └── environments/
│       └── production/
├── kubernetes/
│   ├── base/
│   │   ├── namespace.yaml
│   │   └── configmap.yaml
│   ├── apps/
│   │   ├── api-gateway.yaml
│   │   ├── processor.yaml
│   │   └── ml-inference.yaml
│   └── monitoring/
│       ├── prometheus.yaml
│       └── grafana.yaml
├── services/
│   ├── api-gateway/
│   ├── processor/
│   └── ml-inference/
└── scripts/
    ├── deploy.sh
    └── health-check.sh
```

## 🔧 Manual Deployment

If you prefer manual control:

### Deploy Infrastructure

```bash
cd terraform/environments/production

# Initialize Terraform
terraform init

# Review planned changes
terraform plan -out=tfplan

# Apply infrastructure
terraform apply tfplan

# Save outputs
terraform output -json > outputs.json
```

### Deploy to Kubernetes

```bash
# Update kubeconfig
aws eks update-kubeconfig --name enterprise-ai-grid --region us-east-1

# Deploy base resources
kubectl apply -f kubernetes/base/

# Deploy applications
kubectl apply -f kubernetes/apps/

# Deploy monitoring
kubectl apply -f kubernetes/monitoring/

# Check status
kubectl get pods -n enterprise-ai-grid
```

## 📊 Monitoring & Observability

### Access Grafana Dashboard

```bash
# Port forward Grafana
kubectl port-forward svc/grafana 3000:3000 -n monitoring

# Open browser
open http://localhost:3000
# Login: admin / <GRAFANA_PASSWORD>
```

### Key Metrics

- **API Gateway**: Request rate, latency, error rate
- **Processor**: Job queue depth, processing time
- **ML Inference**: Model latency, GPU utilization
- **Infrastructure**: CPU, memory, network, disk

## 🔒 Security

- ✅ All services run as non-root users
- ✅ Network policies restrict pod-to-pod communication
- ✅ Secrets stored in AWS Secrets Manager
- ✅ TLS encryption for all external endpoints
- ✅ IAM roles with least-privilege access
- ✅ Regular security scanning via Trivy

## 💰 Cost Optimization

**Estimated Monthly Costs** (us-east-1):

| Service | Configuration | Monthly Cost |
|---------|--------------|-------------|
| EKS Control Plane | 1 cluster | $73 |
| EC2 (Worker Nodes) | 5x t3.2xlarge | $750 |
| RDS PostgreSQL | db.r6i.4xlarge Multi-AZ | $1,500 |
| ElastiCache Redis | 3-node cluster | $300 |
| Data Transfer | 1TB outbound | $90 |
| S3 Storage | 500GB | $12 |
| **Total** | | **~$2,725/mo** |

### Reduce Costs:

- Use Spot instances for non-critical workloads
- Right-size RDS instance based on actual load
- Enable S3 Intelligent-Tiering
- Use Reserved Instances for predictable workloads

## 🔄 Scaling

### Horizontal Pod Autoscaling

```bash
# Scale based on CPU
kubectl autoscale deployment api-gateway \
  --cpu-percent=70 \
  --min=5 \
  --max=20 \
  -n enterprise-ai-grid
```

### Cluster Autoscaling

EKS Cluster Autoscaler automatically adjusts node count based on pod resource requests.

## 🧪 Testing

```bash
# Run health checks
./scripts/health-check.sh

# Load testing
k6 run tests/load-test.js

# Security scanning
./scripts/security-scan.sh
```

## 🆘 Troubleshooting

### Common Issues

**Pods not starting:**
```bash
kubectl describe pod <pod-name> -n enterprise-ai-grid
kubectl logs <pod-name> -n enterprise-ai-grid
```

**Terraform state locked:**
```bash
# Force unlock (use with caution)
terraform force-unlock <LOCK_ID>
```

**EKS authentication errors:**
```bash
# Refresh kubeconfig
aws eks update-kubeconfig --name enterprise-ai-grid --region us-east-1
```

## 🗑️ Cleanup

To destroy all resources:

1. Go to GitHub Actions
2. Select "Destroy Infrastructure" workflow
3. Click "Run workflow"
4. Type `DESTROY` to confirm

**Or manually:**

```bash
cd terraform/environments/production
terraform destroy -auto-approve
```

## 📚 Documentation

- [Terraform Modules](./terraform/README.md)
- [Kubernetes Configuration](./kubernetes/README.md)
- [Service Architecture](./services/README.md)
- [CI/CD Pipeline](./docs/CICD.md)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## 📝 License

MIT License - See [LICENSE](LICENSE) for details

## 🆘 Support

- **Issues**: [GitHub Issues](https://github.com/Garrettc123/enterprise-ai-deployment/issues)
- **Documentation**: [Wiki](https://github.com/Garrettc123/enterprise-ai-deployment/wiki)

---

**Built by [Garcar Enterprise](https://github.com/Garrettc123)** 🚀
