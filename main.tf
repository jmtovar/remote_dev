# =============================================================================
# main.tf — Ephemeral dev instance on AWS (spot, cheap, destroyable)
# =============================================================================
# Usage:
#   terraform init
#   terraform apply -var="your_ip=$(curl -s ifconfig.me)/32"
#   terraform destroy   ← when done for the day
# =============================================================================

terraform {
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

# ------------------------------------------------------------------------------
# Variables
# ------------------------------------------------------------------------------
variable "aws_region" {
  default = "eu-west-1"   # Change to your nearest region
}

variable "your_ip" {
  description = "Your home/office IP in CIDR, e.g. 1.2.3.4/32"
  type        = string
}

variable "instance_type" {
  default = "t3.medium"   # 2 vCPU, 4 GB RAM — good for dev
}

variable "git_name" {
  description = "Your name for git config"
  default     = "Your Name"
}

variable "git_email" {
  description = "Your email for git config"
  default     = "you@example.com"
}

variable "anthropic_api_key" {
  description = "Your Anthropic API key (stored in tfvars, not in code)"
  type        = string
  sensitive   = true
}

# ------------------------------------------------------------------------------
# Data: latest Ubuntu 24.04 LTS AMI
# ------------------------------------------------------------------------------
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }
}

# ------------------------------------------------------------------------------
# Key pair (uses your existing local SSH public key)
# ------------------------------------------------------------------------------
resource "aws_key_pair" "dev" {
  key_name   = "ephemeral-dev-key"
  public_key = file("~/.ssh/id_ed25519.pub")  # Your local public key
}

# ------------------------------------------------------------------------------
# Security group — SSH only from your IP
# ------------------------------------------------------------------------------
resource "aws_security_group" "dev" {
  name        = "ephemeral-dev-sg"
  description = "SSH access for ephemeral dev instance"

  ingress {
    description = "SSH from my IP only"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.your_ip]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "ephemeral-dev-sg" }
}

# ------------------------------------------------------------------------------
# Cloud-init: runs bootstrap.sh automatically on first boot
# ------------------------------------------------------------------------------
locals {
  user_data = <<-EOT
    #!/bin/bash
    export GIT_NAME="${var.git_name}"
    export GIT_EMAIL="${var.git_email}"
    export ANTHROPIC_API_KEY="${var.anthropic_api_key}"

    # Persist env vars for interactive SSH sessions
    echo "export ANTHROPIC_API_KEY=${var.anthropic_api_key}" >> /home/ubuntu/.bashrc
    echo "export GIT_NAME='${var.git_name}'"                 >> /home/ubuntu/.bashrc
    echo "export GIT_EMAIL='${var.git_email}'"               >> /home/ubuntu/.bashrc

    # Download and run bootstrap from your dotfiles repo
    # Option A: from a public gist / dotfiles repo (recommended)
    # curl -fsSL https://raw.githubusercontent.com/YOU/dotfiles/main/bootstrap.sh | sudo -u ubuntu bash

    # Option B: embed the script inline (copy bootstrap.sh content here)
    sudo -u ubuntu bash /tmp/bootstrap.sh
  EOT
}

# ------------------------------------------------------------------------------
# EC2 Spot instance
# ------------------------------------------------------------------------------
resource "aws_instance" "dev" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.dev.key_name
  vpc_security_group_ids = [aws_security_group.dev.id]

  # Spot instance = 60-90% cheaper; fine for dev work
  instance_market_options {
    market_type = "spot"
    spot_options {
      spot_instance_type = "one-time"
    }
  }

  user_data                   = local.user_data
  user_data_replace_on_change = true

  root_block_device {
    volume_size = 20  # GB — enough for most projects
    volume_type = "gp3"

    # IMPORTANT: delete on termination = no lingering EBS costs
    delete_on_termination = true
  }

  tags = { Name = "ephemeral-dev" }
}

# ------------------------------------------------------------------------------
# Outputs
# ------------------------------------------------------------------------------
output "ssh_command" {
  value       = "ssh ubuntu@${aws_instance.dev.public_ip}"
  description = "Run this to connect to your instance"
}

output "public_ip" {
  value = aws_instance.dev.public_ip
}
