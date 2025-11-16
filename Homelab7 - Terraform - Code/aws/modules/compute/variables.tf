/*
In this file, we define the variables needed for defining and deploying our actual infrastructure
*/

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name (dev/staging/prod)"
  type        = string
}

/*
We select the type of the instance being by default t2.micro type 
due to it being Free Tier Eligible
*/
variable "instance_type" {
  description = "EC2 instance type (size)"
  type        = string
  default     = "t3.micro"
}

variable "subnet_id" {
  description = "ID of subnet to launch instance in"
  type        = string
}

variable "security_group_ids" {
  description = "List of security group IDs to attach"
  type        = list(string)
}

variable "key_name" {
  description = "Name of SSH key pair for instance access"
  type        = string
}