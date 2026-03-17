provider "aws" {
  region = "eu-central-1"
}
locals {
  github_actions_ips = [
    "140.82.112.0/20",    # GitHub Actions (main)
    "143.55.64.0/20",     # GitHub Actions
    "185.199.108.0/22",   # GitHub Actions
    "192.30.252.0/22",    # GitHub Actions
    "13.107.42.0/24",     # GitHub Actions (Azure)
    "13.107.43.0/24",     # GitHub Actions (Azure)
    "20.201.0.0/16"       # GitHub Actions (Azure - broad range)
  ]
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

variable "ssh_key_name" {
  type = string
}

resource "aws_security_group" "flask_sg" {
  name = "flask-app-sg"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 3100
    to_port     = 3100
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 9100
    to_port     = 9100
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 9093
    to_port     = 9093
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "flask-app-sg"
  }
}

resource "aws_s3_bucket" "backups" {
  bucket = "flask-app-backups-${substr(md5(data.aws_caller_identity.current.account_id), 0, 8)}"

  tags = {
    Name = "flask-backups"
  }
}

resource "aws_s3_bucket_versioning" "backups" {
  bucket = aws_s3_bucket.backups.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "backups" {
  bucket = aws_s3_bucket.backups.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "backups" {
  bucket = aws_s3_bucket.backups.id

  rule {
    id     = "delete_old_backups"
    status = "Enabled"

    expiration {
      days = 30
    }
  }
}

resource "aws_s3_bucket_public_access_block" "backups" {
  bucket = aws_s3_bucket.backups.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_iam_role" "ec2_s3_backup_role" {
  name = "flask-app-ec2-s3-backup-role"

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

resource "aws_iam_role_policy" "ec2_s3_backup_policy" {
  name = "flask-app-ec2-s3-backup-policy"
  role = aws_iam_role.ec2_s3_backup_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.backups.arn,
          "${aws_s3_bucket.backups.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_instance_profile" "ec2_s3_backup_profile" {
  name = "flask-app-ec2-s3-backup-profile"
  role = aws_iam_role.ec2_s3_backup_role.name
}

data "aws_caller_identity" "current" {}

resource "aws_eip" "flask_app_eip" {
  domain = "vpc"
  
  tags = {
    Name = "flask-app-devops-eip"
  }
  depends_on = [aws_instance.flask_server]
}

resource "aws_instance" "flask_server" {
  ami                  = data.aws_ami.ubuntu.id
  instance_type        = "t3.micro"
  key_name             = var.ssh_key_name
  security_groups      = [aws_security_group.flask_sg.name]
  iam_instance_profile = aws_iam_instance_profile.ec2_s3_backup_profile.name

  tags = {
    Name = "flask-app-devops"
  }
  user_data = <<-EOF
              #!/bin/bash
              apt update -y && apt upgrade -y
              EOF
}

resource "aws_eip_association" "flask_app_eip_assoc" {
  instance_id   = aws_instance.flask_server.id
  allocation_id = aws_eip.flask_app_eip.id
}

output "public_ip" {
  value = aws_eip.flask_app_eip.public_ip
}

output "elastic_ip_allocation_id" {
  value = aws_eip.flask_app_eip.id
}

output "security_group_id" {
  value = aws_security_group.flask_sg.id
}

output "s3_backup_bucket" {
  value = aws_s3_bucket.backups.id
}