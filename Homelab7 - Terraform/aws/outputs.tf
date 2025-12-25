output "vpc_id" {
  description = "ID of the VPC"
  value       = module.networking.vpc_id
}

output "public_subnet_ids" {
  description = "IDs of public subnets"
  value       = module.networking.public_subnet_ids
}

output "private_subnet_ids" {
  description = "IDs of private subnets"
  value       = module.networking.private_subnet_ids
}

output "web_security_group_id" {
  description = "ID of web security group"
  value       = module.security.web_sg_id
}

output "database_security_group_id" {
  description = "ID of database security group"
  value       = module.security.database_sg_id
}

output "ec2_instance_id" {
  description = "ID of EC2 instance"
  value       = module.compute.instance_id
}

output "ec2_public_ip" {
  description = "Public IP of EC2 instance"
  value       = module.compute.public_ip
}