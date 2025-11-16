/*
Web Sever Security Group 
Controls traffic to/from web servers (EC2 Instances)

The line "vpc_id = var.vpc_id" is crucial as it specifies which VPC it belongs to
*/
resource "aws_security_group" "web" {

  name        = "${var.project_name}-web-sg"
  description = "Security group for web servers"
  vpc_id      = var.vpc_id


  /*
    HTTP - Port 80 (Web Traffic)

    The line "cidr_blocks = ["0.0.0.0/0"]" means allow in from ANY IP address 
    */
  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  /*
    HTTPS - Port 443 (Secure Web Traffic)

    The line "cidr_blocks = ["0.0.0.0/0"]" means allow in from ANY IP address 
    */
  ingress {
    description = "HTTPS from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  /*
    SSH - Port 22 (Remote Administration)
    */
  ingress {
    description = "SSH from specific IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidrs
  }

  /*
    Allow ALL outbound traffic

    The "protocol = -1" means that traffic for all protocols is allowed
    */
  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-web-sg"
  }
}

/*
Database Security Group -- Only allows access FROM web servers (not the Internet!)
*/
resource "aws_security_group" "database" {

  name        = "${var.project_name}-db-sg"
  description = "Security group for database servers"
  vpc_id      = var.vpc_id

  /*
    MySQL - Port 3306
    Notice that we are NOT using cidr_blocks here, using security_groups instead!
    */
  ingress {
    description     = "MySQL from web servers"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.web.id] # <-- KEY DIFFERENCE!
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-db-sg"
  }
}