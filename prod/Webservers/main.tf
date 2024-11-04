# Terraform Config file (main.tf). This has provider block (AWS) and config for provisioning one EC2 instance resource.  

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 3.27"
    }
  }

  required_version = ">=0.14"
}
provider "aws" {
  profile = "default"
  region  = "us-east-1"
}

data "terraform_remote_state" "prod_net_tfstate" { // This is to use Outputs from Remote State
  backend = "s3"
  config = {
    bucket = "prod-behzad-bucket"         // Bucket from where to GET Terraform State
    key    = "network/terraform.tfstate" // Object name in the bucket to GET Terraform State
    region = "us-east-1"                      // Region where bucket created
  }
}

data "terraform_remote_state" "dev_web_tfstate" { // This is to use Outputs from Remote State
  backend = "s3"
  config = {
    bucket = "dev-behzad-bucket"             
    key    = "webservers/terraform.tfstate" // dev/webservers/terraform.tfstate
    region = "us-east-1"                     
  }
}

# Data source for AMI id
data "aws_ami" "latest_amazon_linux" {
  owners      = ["amazon"]
  most_recent = true
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# Data source for availability zones in us-east-1
data "aws_availability_zones" "available" {
  state = "available"
}

# Define tags locally
locals {
  default_tags = merge(var.default_tags, { "env" = var.env })
  name_prefix  = "${var.prefix}-${var.env}"
}

resource "aws_instance" "private_instance" {
  count                       = length(data.terraform_remote_state.prod_net_tfstate.outputs.private_subnet_ids)
  ami                         = data.aws_ami.latest_amazon_linux.id
  instance_type               = lookup(var.instance_type, var.env)
  key_name                    = aws_key_pair.keyName.key_name
  security_groups             = [aws_security_group.private_instance_SG.id]
  subnet_id                   = data.terraform_remote_state.prod_net_tfstate.outputs.private_subnet_ids[count.index]
  associate_public_ip_address = true

  root_block_device {
    encrypted = var.env == "prod" ? true : false
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(local.default_tags,
    {
      "Name" = "VM${count.index + 1}"
    }
  )
}

# Adding public key into the AWS if it doesn't exist
resource "aws_key_pair" "keyName" {
  key_name   = var.keyName
  public_key = file("~/.ssh/${var.keyName}.pub")    # # file, use my local linux computer(wsl) files. key pairs must be in ~/.ssh address to be able to change security level(chmod 400)
}

#security Group
resource "aws_security_group" "private_instance_SG" {
  name        = "allow_http_ssh"
  description = "Allow HTTP and SSH inbound traffic"
  vpc_id      = data.terraform_remote_state.prod_net_tfstate.outputs.vpc_id

  ingress {
    description      = "SSH from everywhere"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["${data.terraform_remote_state.dev_web_tfstate.outputs.public_instance_ip}/32"]    # we bring dev/webserver/terraform.tfstate, public_instance_ip
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Allow SSH Security Group"
  }
}

# Attach EBS volume
resource "aws_volume_attachment" "ebs_att" {
  count       = var.env == "prod" ? 1 : 0
  device_name = "/dev/sdh"
  volume_id   = aws_ebs_volume.web_ebs[count.index].id
  instance_id = aws_instance.private_instance[0].id
}

# Create another EBS volume
resource "aws_ebs_volume" "web_ebs" {
  count             = var.env == "prod" ? 1 : 0
  availability_zone = data.aws_availability_zones.available.names[0]
  size              = 40

  tags = merge(local.default_tags,
    {
      "Name" = "${var.prefix}-EBS"
    }
  )
}
