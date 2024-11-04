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
    bucket = "dev-behzad-bucket"             
    key    = "network/terraform.tfstate" // dev/webservers/terraform.tfstate
    region = "us-east-1"                     
  }
}

data "terraform_remote_state" "prod_net_tfstate" { // This is to use Outputs from Remote State
  backend = "s3"
  config = {
    bucket = "prod-behzad-bucket"             
    key    = "network/terraform.tfstate" // dev/webservers/terraform.tfstate
    region = "us-east-1"                     
  }
}

# Transit Gateway
resource "aws_ec2_transit_gateway" "tgw" {
  description = "Transit Gateway"
  tags = {
    Name = "My Transit Gateway"
  }
}

# Transit Gateway Attachment for devVPC
resource "aws_ec2_transit_gateway_vpc_attachment" "dev_vpc_attachment" {
  subnet_ids         = data.terraform_remote_state.dev_net_tfstate.outputs.public_subnet_ids    # one subnet in each AZ is enough. Public subnet IDs, list []
  transit_gateway_id = aws_ec2_transit_gateway.tgw.id
  vpc_id             = data.terraform_remote_state.dev_net_tfstate.outputs.vpc_id
  tags = {
    Name = "TGW Attachment for devVPC"
  }
}

# Transit Gateway Attachment for prodVPC
resource "aws_ec2_transit_gateway_vpc_attachment" "prod_vpc_attachment" {
  subnet_ids         = data.terraform_remote_state.prod_net_tfstate.outputs.private_subnet_ids  # list []
  transit_gateway_id = aws_ec2_transit_gateway.tgw.id
  vpc_id             = data.terraform_remote_state.prod_net_tfstate.outputs.vpc_id
  tags = {
    Name = "TGW Attachment for prodVPC"
  }
}

# Route from devVPC public RT to prodVPC private_subnets
resource "aws_route" "public_route_to_tgw" {
  count                  = length(data.terraform_remote_state.prod_net_tfstate.outputs.private_subnet_cidrs[*])
  route_table_id         = data.terraform_remote_state.dev_net_tfstate.outputs.public_route_table_id
  destination_cidr_block = data.terraform_remote_state.prod_net_tfstate.outputs.private_subnet_cidrs[count.index]
  transit_gateway_id     = aws_ec2_transit_gateway.tgw.id
}

# Route from prodVPC private RT to devVPC public_subnet2
resource "aws_route" "public_route_to_tgw_2" {
  route_table_id          = data.terraform_remote_state.prod_net_tfstate.outputs.private_route_table_id
  destination_cidr_block  = data.terraform_remote_state.dev_net_tfstate.outputs.public_subnet_cidrs[1]
  transit_gateway_id     = aws_ec2_transit_gateway.tgw.id
}


