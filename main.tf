locals {
  common_tags = merge(
    var.tags,
    {
      Project     = var.project
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  )
}

module "vpc" {
  source = "./modules/vpc"

  project     = var.project
  environment = var.environment
  vpc_cidr    = var.vpc_cidr
  tags        = local.common_tags
}

module "igw" {
  source = "./modules/igw"

  vpc_id      = module.vpc.vpc_id
  project     = var.project
  environment = var.environment
  tags        = local.common_tags
}

module "subnets" {
  source = "./modules/subnets"

  vpc_id               = module.vpc.vpc_id
  project              = var.project
  environment          = var.environment
  availability_zones   = var.azs
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  tags                 = local.common_tags
}

module "nat" {
  source = "./modules/nat"

  vpc_id             = module.vpc.vpc_id
  project            = var.project
  environment        = var.environment
  public_subnet_ids  = module.subnets.public_subnet_ids
  availability_zones = var.azs
  enable_nat_gateway = var.enable_nat_gateway
  single_nat_gateway = var.single_nat_gateway
  tags               = local.common_tags
}

module "routing" {
  source = "./modules/routing"

  vpc_id             = module.vpc.vpc_id
  project            = var.project
  environment        = var.environment
  igw_id             = module.igw.igw_id
  public_subnet_ids  = module.subnets.public_subnet_ids
  private_subnet_ids = module.subnets.private_subnet_ids
  nat_gateway_ids    = module.nat.nat_gateway_ids
  enable_nat_gateway = var.enable_nat_gateway
  single_nat_gateway = var.single_nat_gateway
  tags               = local.common_tags
}

module "security_groups" {
  source = "./modules/security_groups"

  vpc_id                  = module.vpc.vpc_id
  project                 = var.project
  environment             = var.environment
  admin_cidr_blocks       = var.admin_cidr_blocks
  device_cidr_blocks      = var.device_cidr_blocks
  windows_web_cidr_blocks = var.windows_web_cidr_blocks
  tags                    = local.common_tags
}

module "ec2" {
  source = "./modules/ec2"

  project           = var.project
  environment       = var.environment
  instance_type     = var.ec2_instance_type
  ami_id            = var.ec2_ami_id
  key_name          = var.ec2_key_name
  subnet_id         = module.subnets.public_subnet_ids[0]
  security_group_id = module.security_groups.windows_security_group_id
  root_volume_size  = var.ec2_root_volume_size
  data_volume_size  = var.ec2_data_volume_size
  create_eip        = var.ec2_create_eip
  tags              = local.common_tags
}
