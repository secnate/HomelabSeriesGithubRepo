/*
Terraform configuration

We require the current version of Terraform to be version 1.0 or higher
and use the official AWS provider from HashiCorp

The usage of the "~>" operator in Terraform syntax is that we allow anything to the right of the
last-most period while keeping everything to the left fixed. In this case, we allow versions
5.0, 5.1, 5.2, ..., 5.9 -- BUT NOT 6.0

The ~> operator is used to ensure a degree of compatibility by preventing upgrades that might 
introduce breaking changes at higher version levels, while still allowing for bug fixes and 
minor updates within the specified range
*/
terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

/*
AWS Provider Configuration

The provider is the plugin that talks to AWS API

Here we specify which AWS region we will create the resources in
*/
provider "aws" {
  region = var.aws_region
}

/*
Networking Module

Here we call the networking module and nickname it "networking"
We reference
*/
module "networking" {
  source = "./modules/networking"

  vpc_cidr             = var.vpc_cidr
  project_name         = var.project_name
  environment          = var.environment
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  availability_zones   = var.availability_zones
}

/*
Security Module
*/
module "security" {
  source = "./modules/security"

  project_name      = var.project_name
  vpc_id            = module.networking.vpc_id
  allowed_ssh_cidrs = var.allowed_ssh_cidrs
}

/*
Compute Module

The "module.networking.public_subnet_ids[0]" line means that we are getting
the first public subnet for this EC2 instance

Meanwhile the "[module.security.web_sg_id]" line means that we are
making a list of the security group identifiers
*/
module "compute" {
  source = "./modules/compute"

  project_name       = var.project_name
  environment        = var.environment
  instance_type      = var.instance_type
  subnet_id          = module.networking.public_subnet_ids[0]
  security_group_ids = [module.security.web_sg_id]
  key_name           = var.key_name
}