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

# FIXED: S3 bucket - encryption, versioning, logging
resource "aws_s3_bucket" "secure_bucket" {
  bucket = "iac-scanner-demo-bucket-paulh-secure"
}

resource "aws_s3_bucket_versioning" "secure_bucket_versioning" {
  bucket = aws_s3_bucket.secure_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "secure_bucket_encryption" {
  bucket = aws_s3_bucket.secure_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_logging" "secure_bucket_logging" {
  bucket        = aws_s3_bucket.secure_bucket.id
  target_bucket = aws_s3_bucket.secure_bucket.id
  target_prefix = "log/"
}

resource "aws_s3_bucket_acl" "secure_bucket_acl" {
  bucket = aws_s3_bucket.secure_bucket.id
  acl    = "private"
}

resource "aws_s3_bucket_public_access_block" "secure_bucket_pab" {
  bucket = aws_s3_bucket.secure_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# FIXED: Security group - restricted ingress, description added
resource "aws_security_group" "secure_sg" {
  name        = "iac-scanner-demo-sg-secure"
  description = "Demo security group with restricted SSH access"

  ingress {
    description = "SSH restricted to a single known IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["203.0.113.10/32"] # replace with your actual IP in a real scenario
  }

  egress {
    description = "Restricted egress to HTTPS only"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# FIXED: IAM role scoped to least privilege
resource "aws_iam_role" "secure_role" {
  name = "iac-scanner-demo-role-secure"

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

resource "aws_iam_role_policy" "secure_policy" {
  name = "iac-scanner-demo-policy-secure"
  role = aws_iam_role.secure_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]
        Effect   = "Allow"
        Resource = "${aws_s3_bucket.secure_bucket.arn}/*"
      }
    ]
  })
}

# FIXED: No hardcoded secret - uses a variable instead
variable "db_password" {
  description = "RDS master password, supplied at runtime, never hardcoded"
  type        = string
  sensitive   = true
}

resource "aws_db_instance" "secure_db" {
  identifier                     = "iac-scanner-demo-db-secure"
  allocated_storage              = 10
  engine                         = "mysql"
  engine_version                 = "8.0"
  instance_class                 = "db.t3.micro"
  username                       = "admin"
  password                       = var.db_password
  storage_encrypted              = true
  publicly_accessible            = false
  deletion_protection            = true
  backup_retention_period        = 7
  auto_minor_version_upgrade     = true
  iam_database_authentication_enabled = true
  enabled_cloudwatch_logs_exports = ["error", "general"]
  skip_final_snapshot            = true
}