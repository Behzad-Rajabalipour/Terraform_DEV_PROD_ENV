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

data "terraform_remote_state" "dev_net_tfstate" { // This is to use Outputs from Remote State
  backend = "s3"
  config = {
    bucket = "dev-behzad-bucket"             // Bucket from where to GET Terraform State
    key    = "network/terraform.tfstate" // Object name in the bucket to GET Terraform State
    region = "us-east-1"                     // Region where bucket created
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

resource "aws_instance" "public_instance" {
  ami                         = data.aws_ami.latest_amazon_linux.id
  instance_type               = lookup(var.instance_type, var.env)
  key_name                    = aws_key_pair.keyName.key_name    # because we used count in key_name so we have to give it's index
  security_groups             = [aws_security_group.public_instance_SG.id]
  subnet_id                   = data.terraform_remote_state.dev_net_tfstate.outputs.public_subnet_ids[1] # it use s3/dev/network/terraform.tfstate => outputs. you can also see it in Network/output.tf file
  associate_public_ip_address = true
  # # 1st way
  #user_data  = file("${path.module}/install_httpd.sh")
  # user_data  =<<-EOF
  #           #!/bin/bash
  #           sudo yum -y update
  #           sudo yum -y install httpd
  #           echo "<h1>Welcome to ACS730 Week 6!" >  /var/www/html/index.html
  #           sudo systemctl start httpd
  #           sudo systemctl enable httpd
  #       EOF

  # # 2nd way
  # user_data = file("${path.module}/install_httpd.sh")

 # 3rd way
  # format msut be .sh.tpl  we can use variables(env, prefix) inside the script      templatefile("address",{variables})
  user_data = templatefile("${path.module}/install_httpd.sh.tpl",
    {
      env    = upper(var.env),
      prefix = upper(var.prefix)
      name = "Behzad Rajabalipour"
    }
  )

  root_block_device { # it will encrypt it if it is in env=test
    encrypted = var.env == "test" ? true : false
  }

  lifecycle { # lifecycle will create a new instance before destroy previous one
    create_before_destroy = true
  }

  tags = merge(local.default_tags,
    {
      "Name" = "Bastion VM"
    }
  )
}

resource "aws_instance" "private_instance" {
  count                       = length(data.terraform_remote_state.dev_net_tfstate.outputs.private_subnet_ids)
  ami                         = data.aws_ami.latest_amazon_linux.id
  instance_type               = lookup(var.instance_type, var.env)
  key_name                    = aws_key_pair.keyName.key_name    # because we used count in key_name so we have to give it's index
  security_groups             = [aws_security_group.private_instance_SG.id]
  subnet_id                   = data.terraform_remote_state.dev_net_tfstate.outputs.private_subnet_ids[count.index] # it use s3/dev/network/terraform.tfstate => outputs. you can also see it in Network/output.tf file
  associate_public_ip_address = true

  # IMPORTANT: We must have userdata in private VMs, otherwise health check in ALB is unhealthy. when we have apache server(http) installed, health check will get answer from VM
  user_data = templatefile("${path.module}/install_httpd.sh.tpl",
    {
      env    = upper(var.env),
      prefix = upper(var.prefix)
      name = "Behzad Rajabalipour"
    }
  )

  root_block_device { # it will encrypt it if it is in env=test
    encrypted = var.env == "test" ? true : false
  }

  lifecycle { # lifecycle will create a new instance before destroy previous one
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
  public_key = file("~/.ssh/${var.keyName}.pub")        # file, use my local linux computer(wsl) files. key pairs must be in ~/.ssh address to be able to change security level(chmod 400)
}

#security Group
resource "aws_security_group" "public_instance_SG" {
  name        = "allow_http_ssh"
  description = "Allow HTTP and SSH inbound traffic"
  vpc_id      = data.terraform_remote_state.dev_net_tfstate.outputs.vpc_id

  ingress {
    description      = "HTTP from everywhere"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description      = "SSH from everywhere"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = merge(local.default_tags,
    {
      "Name" = "~/.ssh/${var.prefix}-public-SG"         # keys should be in ~/.ssh otherwise you can't change their permission with chmod 400
    }
  )
}

resource "aws_security_group" "private_instance_SG" {
  name        = "allow_ssh_icmp"
  description = "Allow SSH and ICMP traffic from a specific VM"
  vpc_id      = data.terraform_remote_state.dev_net_tfstate.outputs.vpc_id

  # Ingress rule for SSH
  ingress {
    description = "Allow SSH from specific VM"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${aws_instance.public_instance.private_ip}/32"]  # private_ip(IPV4 private), Allow SSH from the Bastion VM (public VM)
  }

  # Ingress rule for HTTP
  ingress {
    description = "Allow SSH from specific VM"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    security_groups = [data.terraform_remote_state.dev_net_tfstate.outputs.ALB_SG_id ]  # ALB security group
  }

  # Egress rule to allow all outbound traffic
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"    # Allow all egress traffic
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Allow SSH and ICMP Security Group"
  }
}

# Elastic IP
resource "aws_eip" "static_eip" {
  instance = aws_instance.public_instance.id
  tags = merge(local.default_tags,
    {
      "Name" = "${var.prefix}-eip"
    }
  )
}

# Attach EBS volume
# resource "aws_volume_attachment" "ebs_att" {
#   count       = var.env == "prod" ? 1 : 0
#   device_name = "/dev/sdh"
#   volume_id   = aws_ebs_volume.web_ebs[count.index].id
#   instance_id = aws_instance.public_instance.id
# }

# # Create another EBS volume
# resource "aws_ebs_volume" "web_ebs" {
#   count             = var.env == "prod" ? 1 : 0
#   availability_zone = data.aws_availability_zones.available.names[1]
#   size              = 40

#   tags = merge(local.default_tags,
#     {
#       "Name" = "${var.prefix}-EBS"
#     }
#   )
# }


# Register EC2 Instances to Target Group
resource "aws_lb_target_group_attachment" "tg_attachment" {
  count             = length(aws_instance.private_instance[*].id)
  target_group_arn  = data.terraform_remote_state.dev_net_tfstate.outputs.target_group_arn
  target_id         = aws_instance.private_instance[count.index].id
  port              = 80
}
