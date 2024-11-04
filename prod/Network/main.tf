# remember whenever you changed the git repository files, you have to use terraform init -upgrade to not use the cache data
# 1. git add .    
# 2. git commit -m "change output"
# 2. git push devOrigin master
# 2. terraform init -upgrade
module "vpc-prod" {
  # source = "../../prod_network_module"
  source              = "git::https://github.com/Behzad-Rajabalipour/prod_network_module.git"      # it's better to use https URl instead of ssh. because ssh need authentication even in public repository
  env                 = var.env
  vpc_cidr            = var.vpc_cidr
  private_cidr_blocks = var.private_subnet_cidrs
  prefix              = var.prefix
  default_tags        = var.default_tags
}
