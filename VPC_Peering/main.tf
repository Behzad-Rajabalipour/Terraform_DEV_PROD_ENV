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

resource "aws_vpc_peering_connection" "devVPC_to_prodVPC" {
  peer_vpc_id      = data.terraform_remote_state.prod_net_tfstate.outputs.vpc_id
  vpc_id           = data.terraform_remote_state.dev_net_tfstate.outputs.vpc_id
  auto_accept      = true                # Set to false to manually accept the peering request

  tags = {
    Name = "dev-to-prod-VPC-peering"
  }
}

resource "aws_route" "route_to_vpc2" {
  route_table_id         = data.terraform_remote_state.dev_net_tfstate.outputs.public_route_table_id
  destination_cidr_block = data.terraform_remote_state.prod_net_tfstate.outputs.vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.devVPC_to_prodVPC.id
}

resource "aws_route" "route_to_vpc1" {
  route_table_id         = data.terraform_remote_state.prod_net_tfstate.outputs.private_route_table_id
  destination_cidr_block = data.terraform_remote_state.dev_net_tfstate.outputs.vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.devVPC_to_prodVPC.id
}
