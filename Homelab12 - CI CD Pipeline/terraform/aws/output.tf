output "instance_public_ip" {
  value = aws_instance.flask_app.public_ip
  description = "Public IP Address of the EC2 Instance"
}

output "app_url" {
    value = "http://${aws_instance.flask_app.public_ip}:5000"
    description = "URL to access the Flask application"
}

output "instance_public_dns" {
    value = aws_instance.flask_app.public_dns
    description = "Public DNS of EC2 instance"
}

output "instance_id" {
    value = aws_instance.flask_app.id
    description = "EC2 Instance ID"
}

output "ssh_command" {
    value = "ssh -i path/to/key ec2-user@${aws_instance.flask_app.public_ip}"
}
