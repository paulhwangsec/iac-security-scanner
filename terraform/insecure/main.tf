terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-2"
}

# ISSUE 1: S3 bucket with public access
resource "aws_s3_bucket" "insecure_bucket" {
  bucket = "iac-scanner-demo-bucket-paulh"
}

resource "aws_s3_bucket_acl" "insecure_bucket_acl" {
  bucket = aws_s3_bucket.insecure_bucket.id
  acl    = "public-read"
}

resource "aws_s3_bucket_public_access_block" "insecure_bucket_pab" {
  bucket = aws_s3_bucket.insecure_bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# ISSUE 2: Security group open to the world on SSH
resource "aws_security_group" "insecure_sg" {
  name        = "iac-scanner-demo-sg"
  description = "Demo security group with open SSH access"

  ingress {
    description = "SSH open to the world"
    from_port   = 22
    to_port     = 22
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

# ISSUE 3: IAM role with wildcard permissions
resource "aws_iam_role" "insecure_role" {
  name = "iac-scanner-demo-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "insecure_policy" {
  name = "iac-scanner-demo-policy"
  role = aws_iam_role.insecure_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = "*"
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

# ISSUE 4: Hardcoded secret
resource "aws_db_instance" "insecure_db" {
  identifier           = "iac-scanner-demo-db"
  allocated_storage    = 10
  engine               = "mysql"
  engine_version       = "8.0"
  instance_class       = "db.t3.micro"
  username             = "admin"
  password             = "SuperSecretPassword123!"  # hardcoded secret - flagged by scanners
  skip_final_snapshot  = true
  publicly_accessible  = false
}