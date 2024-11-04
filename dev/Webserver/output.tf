output "public_instance_ip" {
  value = aws_instance.public_instance.private_ip       # private_ip  IPv4 private
}

output "web_eip" {
  value = aws_eip.static_eip.public_ip
}

output "public_instance_subnet_id" {
  value = data.terraform_remote_state.dev_net_tfstate.outputs.public_subnet_ids[1]
}

output "private_instances_subnet_ids" {
  value = data.terraform_remote_state.dev_net_tfstate.outputs.private_subnet_ids
}

output "ec2_vpc_id" {
  value = data.terraform_remote_state.dev_net_tfstate.outputs.vpc_id
}
