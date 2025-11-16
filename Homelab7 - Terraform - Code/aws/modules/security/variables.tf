variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

/*
We need VPC ids because security groups must be created inside them
*/
variable "vpc_id" {
  description = "ID of the VPC to create security groups in"
  type        = string
}

/*
The usage of the "0.0.0.0/0" means "any IPv4 address" -- so we are saying
here that we allow anywhere on the Internet to SSH into instances

This obviously is a security risk, but this it is going to be deemed "OK"
for the purposes of learning in this homelab
*/
variable "allowed_ssh_cidrs" {
  description = "CIDR blocks allowed to SSH into instances"
  type        = list(string)
  default     = ["0.0.0.0/0"] # WARNING: Open to world - change in production
}