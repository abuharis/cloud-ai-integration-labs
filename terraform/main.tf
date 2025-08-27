provider "aws" {
  region = var.aws_region
}

# -------------------------
# VPC + Networking (Demo)
# -------------------------
resource "aws_vpc" "demo_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = { Name = "demo-vpc" }
}

resource "aws_subnet" "demo_subnet" {
  vpc_id                  = aws_vpc.demo_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "${var.aws_region}a"
  tags = { Name = "demo-subnet" }
}

resource "aws_internet_gateway" "demo_igw" {
  vpc_id = aws_vpc.demo_vpc.id
  tags = { Name = "demo-igw" }
}

resource "aws_route_table" "demo_route_table" {
  vpc_id = aws_vpc.demo_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.demo_igw.id
  }
  tags = { Name = "demo-route-table" }
}

resource "aws_route_table_association" "demo_rta" {
  subnet_id      = aws_subnet.demo_subnet.id
  route_table_id = aws_route_table.demo_route_table.id
}

resource "aws_security_group" "demo_sg" {
  name        = "demo-sg"
  vpc_id      = aws_vpc.demo_vpc.id
  description = "Allow HTTP traffic for demo app"

  ingress {
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# -------------------------
# ECR Repository
# -------------------------
resource "aws_ecr_repository" "demo_repo" {
  name = "demo-cloud-ai-integration"
}

# -------------------------
# S3 Bucket
# -------------------------
resource "aws_s3_bucket" "demo_bucket" {
  bucket        = "demo-photo-album-${random_id.bucket_suffix.hex}"
  force_destroy = true
}

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# -------------------------
# DynamoDB Table
# -------------------------
resource "aws_dynamodb_table" "demo_table" {
  name         = "demo-photo-metadata"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "file_key"

  attribute {
    name = "file_key"
    type = "S"
  }
}

# -------------------------
# IAM Roles
# -------------------------

## Task Role (App permissions)
resource "aws_iam_role" "demo_ecs_task_role" {
  name = "demo-ecsTaskRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_policy" "demo_ecs_task_policy" {
  name = "demo-ecsTaskPolicy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:PutObject"]
        Resource = "${aws_s3_bucket.demo_bucket.arn}/*"
      },
      {
        Effect = "Allow"
        Action = ["rekognition:DetectLabels"]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = ["dynamodb:PutItem"]
        Resource = aws_dynamodb_table.demo_table.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "demo_task_attach" {
  role       = aws_iam_role.demo_ecs_task_role.name
  policy_arn = aws_iam_policy.demo_ecs_task_policy.arn
}

## Execution Role (ECR + Logs)
resource "aws_iam_role" "demo_ecs_execution_role" {
  name = "demo-ecsExecutionRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "demo_execution_attach" {
  role       = aws_iam_role.demo_ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# -------------------------
# ECS Cluster + Service
# -------------------------
resource "aws_ecs_cluster" "demo_cluster" {
  name = "demo-photo-cluster"
}

resource "aws_ecs_task_definition" "demo_task" {
  family                   = "demo-photo-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"

  execution_role_arn = aws_iam_role.demo_ecs_execution_role.arn
  task_role_arn      = aws_iam_role.demo_ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "demo-flask-api"
      image     = "${aws_ecr_repository.demo_repo.repository_url}:latest"
      essential = true
      portMappings = [{
        containerPort = 8000
        hostPort      = 8000
      }]
      environment = [
        { name = "S3_BUCKET", value = aws_s3_bucket.demo_bucket.bucket },
        { name = "DYNAMODB_TABLE", value = aws_dynamodb_table.demo_table.name },
        { name = "AWS_REGION", value = var.aws_region }
      ]
    }
  ])
}

resource "aws_ecs_service" "demo_service" {
  name            = "demo-photo-service"
  cluster         = aws_ecs_cluster.demo_cluster.id
  task_definition = aws_ecs_task_definition.demo_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = [aws_subnet.demo_subnet.id]
    security_groups = [aws_security_group.demo_sg.id]
    assign_public_ip = true
  }
}