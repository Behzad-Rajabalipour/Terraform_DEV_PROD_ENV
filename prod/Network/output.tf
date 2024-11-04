output "private_subnet_cidrs" {
  value = module.vpc-prod.private_subnets[*].cidr_block
}

output "private_subnet_ids" {
  value = module.vpc-prod.private_subnets[*].id
}

output "private_route_table_id" {
  value = module.vpc-prod.private_route_table.id
}

output "vpc_id" {
  value = module.vpc-prod.vpc_id
}

output "vpc_cidr" {
  value = module.vpc-prod.vpc_cidr
}