# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0


terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 3.24.1"
    }
  }
  required_version = ">= 0.15.2"
}

provider "aws" {
  region = var.region
}

locals {
  security_groups = {
    sg_ping = aws_security_group.sg_ping.id,
    sg_8080 = aws_security_group.sg_8080.id,
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

data "http" "myip" {
  url = "http://ipv4.icanhazip.com"
}

resource "aws_instance" "web_app" {
  for_each               = local.security_groups
  ami                    = data.aws_ami.ubuntu.id
 subnet_id = aws_subnet.main.id
  instance_type          = "t2.micro"
  associate_public_ip_address = true
  
  vpc_security_group_ids = [each.value]
  user_data              = <<-EOF
              #!/bin/bash
              apt-get update
              apt-get install -y apache2
              sed -i -e 's/80/8080/' /etc/apache2/ports.conf
              echo "Hello World" > /var/www/html/index.html
              systemctl restart apache2
              EOF
  tags = {
    Name = "${var.name}-learn"
  }
}

# --- Security Group for Ping ---
resource "aws_security_group" "allow_ping" {
  name        = "allow_ping"
  description = "Allow ICMP"
  vpc_id      = aws_vpc.main.id
}

resource "aws_subnet" "main" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.1.0/24"
  availability_zone = var.region == "eu-west-2" ? "eu-west-2a" : "eu-west-2b"
  map_public_ip_on_launch = true
  
  tags = {
    Name = "public-subnet"
  }
}
# --- Security Group for Port 8080 ---
resource "aws_security_group" "allow_8080" {
  name        = "allow_8080"
  description = "Allow 8080 traffic"
  vpc_id      = aws_vpc.main.id

  # Allow outbound (needed for package installation)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "sg_ping" {
  name        = "sg_ping"
  description = "Allow ICMP traffic"
  vpc_id      = aws_vpc.main.id
  ingress {
    from_port       = -1
    to_port         = -1
    protocol        = "icmp"
    security_groups = [aws_security_group.allow_8080.id]
  }
}
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "main-vpc"
  }
}

resource "aws_security_group" "sg_8080" {
  name = "Allow 8080"
  vpc_id = aws_vpc.main.id
  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.allow_ping.id]
  }
  // connectivity to ubuntu mirrors is required to run `apt-get update` and `apt-get install apache2`
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group_rule" "allow_localhost_8080" {
  type              = "ingress"
  from_port         = 8080
  to_port           = 8080
  protocol          = "tcp"
  cidr_blocks       = ["${chomp(data.http.myip.response_body)}/32"]
  security_group_id = aws_security_group.sg_8080.id
}

resource "aws_security_group_rule" "allow_localhost_ping" {
  type              = "ingress"
  from_port         = -1
  to_port           = -1
  protocol          = "icmp"
  cidr_blocks       = ["${chomp(data.http.myip.response_body)}/32"]
  security_group_id = aws_security_group.sg_ping.id
}

