/*
Data Source - We find the latest Amazon Linux 2 AMI
This is like searching AWS's catalog of offerings for the right operating system image

In this case, we are looking for the most recent OS image of the "amzn2-ami-hvm-*-x86_64-gp2"
machine. notice the usage of the "*" character, which indicates that we are searching across
machines of any version number of the type. The most_recent field being "true" means that
if multiple AMIs match, we will get the newest one
*/
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

/*
Here we create the EC2 instance

notice the user_data field. This is a script that launches **automatically** when the instance
first boots. It runs with root privileges and is perfect to install software and configure the server

Regarding the syntax, the "<<-EOF" is the start of a multi-line string in Terraform, which ends with "EOF"
Think of it as the equivalent of Python's triple quotes: """ ... """

Here we install Apache web server, starts the web service, and enable it to start automatically on boot
*/
resource "aws_instance" "web" {

  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = var.security_group_ids
  key_name               = var.key_name

  user_data = <<-EOF
                              #!/bin/bash
                              yum update -y
                              yum install -y httpd
                              systemctl start httpd
                              systemctl enable httpd
                              echo "<h1>Hello from Terraform on AWS!</h1>" > /var/www/html/index.html
                              EOF

  tags = {
    Name        = "${var.project_name}-web-server"
    Environment = var.environment
  }
}