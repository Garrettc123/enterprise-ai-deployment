terraform {
  required_version = ">= 1.6.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }

  backend "s3" {
    bucket         = "enterprise-ai-terraform-state"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "enterprise-ai-terraform-locks"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = "production"
      Project     = "enterprise-ai-grid"
      ManagedBy   = "Terraform"
      Repository  = "github.com/Garrettc123/enterprise-ai-deployment"
    }
  }
}

locals {
  cluster_name = "enterprise-ai-grid"
  vpc_cidr     = "10.0.0.0/16"
  azs          = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

# VPC Module
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${local.cluster_name}-vpc"
  cidr = local.vpc_cidr

  azs              = local.azs
  private_subnets  = ["10.0.10.0/24", "10.0.11.0/24", "10.0.12.0/24"]
  public_subnets   = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  database_subnets = ["10.0.20.0/24", "10.0.21.0/24", "10.0.22.0/24"]

  enable_nat_gateway   = true
  single_nat_gateway   = false
  enable_dns_hostnames = true
  enable_dns_support   = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }
}

# EKS Module
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.16"

  cluster_name    = local.cluster_name
  cluster_version = "1.28"

  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  eks_managed_node_groups = {
    general = {
      name           = "general-node-group"
      min_size       = 3
      max_size       = 10
      desired_size   = 5
      instance_types = ["t3.2xlarge"]
      capacity_type  = "ON_DEMAND"
      
      labels = {
        workload-type = "general"
      }

      tags = {
        NodeGroup = "General"
      }
    }

    ml_workloads = {
      name           = "ml-node-group"
      min_size       = 2
      max_size       = 10
      desired_size   = 3
      instance_types = ["g4dn.2xlarge"]
      capacity_type  = "SPOT"
      
      labels = {
        workload-type = "ml"
      }

      taints = [
        {
          key    = "workload-type"
          value  = "ml"
          effect = "NoSchedule"
        }
      ]

      tags = {
        NodeGroup = "ML"
      }
    }
  }

  manage_aws_auth_configmap = true
}

# RDS PostgreSQL
resource "random_password" "db_password" {
  length  = 32
  special = true
}

module "rds" {
  source  = "terraform-aws-modules/rds/aws"
  version = "~> 6.0"

  identifier = "${local.cluster_name}-postgres"

  engine               = "postgres"
  engine_version       = "15.4"
  family               = "postgres15"
  major_engine_version = "15"
  instance_class       = "db.r6i.xlarge"

  allocated_storage     = 500
  max_allocated_storage = 1000
  storage_encrypted     = true
  storage_type          = "gp3"

  db_name  = "enterpriseai"
  username = "dbadmin"
  password = random_password.db_password.result
  port     = 5432

  multi_az               = true
  db_subnet_group_name   = module.vpc.database_subnet_group
  vpc_security_group_ids = [aws_security_group.rds.id]

  backup_retention_period = 35
  backup_window           = "03:00-04:00"
  maintenance_window      = "mon:04:00-mon:05:00"

  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]
  create_cloudwatch_log_group     = true

  skip_final_snapshot = false
  final_snapshot_identifier = "${local.cluster_name}-final-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"

  tags = {
    Name = "${local.cluster_name}-postgres"
  }
}

# ElastiCache Redis
module "elasticache" {
  source  = "terraform-aws-modules/elasticache/aws"
  version = "~> 1.0"

  cluster_id               = "${local.cluster_name}-redis"
  engine                   = "redis"
  engine_version           = "7.0"
  node_type                = "cache.r6g.large"
  num_cache_nodes          = 3
  parameter_group_family   = "redis7"
  port                     = 6379

  subnet_group_name    = module.vpc.elasticache_subnet_group_name
  security_group_ids   = [aws_security_group.redis.id]

  automatic_failover_enabled = true

  tags = {
    Name = "${local.cluster_name}-redis"
  }
}

# S3 Buckets
module "s3_data" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "~> 3.0"

  bucket = "${local.cluster_name}-data-${data.aws_caller_identity.current.account_id}"

  versioning = {
    enabled = true
  }

  lifecycle_rule = [
    {
      id      = "intelligent-tiering"
      enabled = true

      transition = [
        {
          days          = 30
          storage_class = "INTELLIGENT_TIERING"
        }
      ]
    }
  ]

  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        sse_algorithm = "AES256"
      }
    }
  }

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Security Groups
resource "aws_security_group" "rds" {
  name_prefix = "${local.cluster_name}-rds-"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = module.vpc.private_subnets_cidr_blocks
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.cluster_name}-rds-sg"
  }
}

resource "aws_security_group" "redis" {
  name_prefix = "${local.cluster_name}-redis-"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = module.vpc.private_subnets_cidr_blocks
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.cluster_name}-redis-sg"
  }
}

# Data Sources
data "aws_caller_identity" "current" {}
