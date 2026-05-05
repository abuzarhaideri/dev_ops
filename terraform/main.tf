# =============================================================================
# ShopSmart — AWS Infrastructure (ECS Fargate)
# Designed for AWS Academy Lab accounts (uses LabRole)
# =============================================================================

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# -----------------------------------------------------------------------------
# Data Sources — Default VPC & Subnets
# -----------------------------------------------------------------------------

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

data "aws_caller_identity" "current" {}

# -----------------------------------------------------------------------------
# S3 Bucket (Rubric Requirement)
#   - Unique name, versioning, encryption, no public access
# -----------------------------------------------------------------------------

resource "aws_s3_bucket" "artifacts" {
  bucket        = "${var.app_name}-artifacts-${data.aws_caller_identity.current.account_id}"
  force_destroy = true

  tags = {
    Name        = "${var.app_name}-artifacts"
    Environment = "production"
    ManagedBy   = "terraform"
  }
}

resource "aws_s3_bucket_versioning" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# -----------------------------------------------------------------------------
# ECR Repository — Docker image storage
# -----------------------------------------------------------------------------

resource "aws_ecr_repository" "app" {
  name                 = "${var.app_name}-backend"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name      = "${var.app_name}-backend"
    ManagedBy = "terraform"
  }
}

# -----------------------------------------------------------------------------
# ECS Cluster
# -----------------------------------------------------------------------------

resource "aws_ecs_cluster" "main" {
  name = "${var.app_name}-cluster"

  setting {
    name  = "containerInsights"
    value = "disabled"
  }

  tags = {
    Name      = "${var.app_name}-cluster"
    ManagedBy = "terraform"
  }
}

# -----------------------------------------------------------------------------
# CloudWatch Log Group — Container logs
# -----------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/${var.app_name}-backend"
  retention_in_days = 7

  tags = {
    Name      = "${var.app_name}-logs"
    ManagedBy = "terraform"
  }
}

# -----------------------------------------------------------------------------
# Security Group — Allow inbound on container port
# -----------------------------------------------------------------------------

resource "aws_security_group" "ecs" {
  name        = "${var.app_name}-ecs-sg"
  description = "Allow inbound traffic to ECS tasks"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "Allow inbound on container port"
    from_port   = var.container_port
    to_port     = var.container_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name      = "${var.app_name}-ecs-sg"
    ManagedBy = "terraform"
  }
}

# -----------------------------------------------------------------------------
# ECS Task Definition — Fargate
# -----------------------------------------------------------------------------

resource "aws_ecs_task_definition" "app" {
  family                   = "${var.app_name}-backend"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = var.lab_role_arn
  task_role_arn            = var.lab_role_arn

  container_definitions = jsonencode([
    {
      name      = "${var.app_name}-backend"
      image     = var.ecr_image != "" ? var.ecr_image : "${aws_ecr_repository.app.repository_url}:latest"
      essential = true

      portMappings = [
        {
          containerPort = var.container_port
          hostPort      = var.container_port
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "PORT"
          value = tostring(var.container_port)
        },
        {
          name  = "DATABASE_URL"
          value = "file:./prisma/dev.db"
        },
        {
          name  = "NODE_ENV"
          value = "production"
        }
      ]

      healthCheck = {
        command     = ["CMD-SHELL", "wget --no-verbose --tries=1 --spider http://localhost:${var.container_port}/api/health || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 10
      }

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.app.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])

  tags = {
    Name      = "${var.app_name}-task"
    ManagedBy = "terraform"
  }
}

# -----------------------------------------------------------------------------
# ECS Service — Fargate with public IP
# -----------------------------------------------------------------------------

resource "aws_ecs_service" "app" {
  name            = "${var.app_name}-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = data.aws_subnets.default.ids
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = true
  }

  force_new_deployment = true

  tags = {
    Name      = "${var.app_name}-service"
    ManagedBy = "terraform"
  }
}
