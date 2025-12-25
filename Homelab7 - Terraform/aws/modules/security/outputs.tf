output "web_sg_id" {
  value       = aws_security_group.web.id
  description = "ID of the web server security group"
}

output "database_sg_id" {
  value       = aws_security_group.database.id
  description = "ID of the database security group"
}