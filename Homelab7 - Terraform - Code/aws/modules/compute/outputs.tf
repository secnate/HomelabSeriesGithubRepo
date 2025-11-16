output "instance_id" {
  value       = aws_instance.web.id
  description = "ID of the EC2 instance"
}

/*
Why output the public IP? 
- We need to might need to know IP to visit the website!
- Other Terraform modules might need it too!
*/
output "public_ip" {
  value       = aws_instance.web.public_ip
  description = "Public IP address of the instance"
}