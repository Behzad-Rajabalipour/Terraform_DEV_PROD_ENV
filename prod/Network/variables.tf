# Default tags
variable "default_tags" {
  default = {
    "Owner" = "behzad",
    "App"   = "Web"
  }
  type        = map(any)
  description = "Default tags to be appliad to all AWS resources"
}

# Name prefix
variable "prefix" {
  default     = "prod"
  type        = string
  description = "Name prefix"
}

# Provision public subnets in custom VPC
variable "private_subnet_cidrs" {
  default     = ["10.10.1.0/24", "10.10.2.0/24"]
  type        = list(string)
  description = "Public Subnet CIDRs"
}

# VPC CIDR range
variable "vpc_cidr" {
  default     = "10.10.0.0/16"
  type        = string
  description = "VPC to host static web site"
}

# Variable to signal the current environment 
variable "env" {
  default     = "prod"
  type        = string
  description = "Deployment Environment"
}