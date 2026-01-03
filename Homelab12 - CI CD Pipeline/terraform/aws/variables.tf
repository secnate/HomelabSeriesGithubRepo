variable "aws_region" {
    description = "AWS Region"
    type = string
    default = "us-east-2"
}

variable "environment" {
    description = "Environment name"
    type = string
    default = "dev"
}

variable "instance_type" {
    description = "EC2 instance type"
    type = string
    default = "t3.micro"    # Free tier eligible
}

variable "ami_id" {
    description = "AMI ID for the EC2 Instance to be Launched"
    type = string
    default = "ami-00e428798e77d38d9" # Amazon Linux 2023 AMI
}

variable "key_name" {
    description = "SSH key pair name"
    type = string
    default = "jenkins-aws-key"
}