/*
In this file we define the output variables that other Terraform modules need to get.

Notice the usage of the "*" (splat operator). In the case of the last two variables we say that we
want to generate a list of all the involved public/private subnet IDs for all the involved resources
*/
output "vpc_id" {
  value       = aws_vpc.main.id
  description = "ID of the VPC"
}

output "public_subnet_ids" {
  value       = aws_subnet.public[*].id
  description = "List of public subnet IDs"
}

output "private_subnet_ids" {
  value       = aws_subnet.private[*].id
  description = "List of private subnet IDs"
}