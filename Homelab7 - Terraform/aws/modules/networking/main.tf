/* 
The VPC - Virtual private cloud
This is THE isolated network in AWS

In the next line, we say that we want to create something of type "aws_vpc"
with "main" being my nickname for it (it can be referenced later with aws_vpc.main)

We then initialize its main IP address CIDR range using the variable-provided VPC-cidr range

The lines enable_dns_hostnames and enable_dns_support = true ensure that each EC2
gets its own name like "ec2-54-123-45-67.compute-1.amazonaws.com" and that each
name can be translated into a concrete IP address using DNS.

Otherwise, one can only use IP addresses -- which is annoying!

This is the first resource of the file, so it is necessary to explain
what the tags = { .... } is about. These are just labels for keeping track
of resources in Terraform, for biling, ownership, automation, access control,
and other use cases. See https://registry.terraform.io/providers/hashicorp/aws/latest/docs/guides/resource-tagging
for more information regarding how they work

Also note that the "${var.project_name}-vpc" is string interpolation 
which is explained in https://registry.terraform.io/providers/hashicorp/aws/latest/docs/guides/resource-tagging

If "var.project_name" = "lab", then this becomes "lab-vpc"
*/
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "${var.project_name}-vpc"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

/* 
Creating the Internet Gateway, which allows the VPC to communicate with the Internet.
Think of it as being the front door to one's house

In this case, we declare the Internet Gateway's vpc_id as being the same value as the
previously-created VPC with the nickname "main"!

Regarding the usage of the ".id" --> every AWS resource has a unique ID
(like vpc-0a1b2c3d4e5f)
*/
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "${var.project_name}-igw"
  }
}

/*
Public Subnet -- these are subnets that CAN be accessed from the Internet

Notice the usage of the keyword "count". Per https://developer.hashicorp.com/terraform/language/meta-arguments/count
it is a keyword that accepts a whole number to execute a loop (think of it as Terraform's for loop).
The "count.index" is the analogue of a for loop's "i" variable, also starts at the value of 0,1,2,2... 
-- and can be referenced with the "count.index" command to help understand where Terraform 
is currently in the process of the loop iterations

As we see with the usage of the "length(var.public_subnet_cidrs)" command, if we pass in
2 CIDR blocks, it will create two subnets. 

This is why Terraform is so powerful! You write once -- and create many resource instances.

So now you see what is going on here: for each of the provided public subnet cidrs, we
create the appropriate aws_subnet resource with the corresponding IP CIDR block, and place it
into an appropriate availability zone. Using multiple availability zones helps ensure that if
one data center ends, the app stays up!

The usage of the "map_public_ip_on_launch = true" means that any EC2 instance launched here gets
a public IP, which is crucial for them being reachable from the Internet
*/
resource "aws_subnet" "public" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-subnet-${count.index + 1}"
    Type = "Public"
  }
}

/*
Private Subnet -- which are subnets that CANNOT be accessed from the internet

Notice that there is no "map_public_ip_on_launch = true" here --> this is what makes it private!
*/
resource "aws_subnet" "private" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name = "${var.project_name}-private-subnet-${count.index + 1}"
    Type = "Private"
  }
}

/* 
Elastic IP for NAT Gateway -- The NAT Gateway needs a static public IP
which does *not* change when you start/stop instances. Regular IPs do 
*/
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "${var.project_name}-nat-eip"
  }
}

/* 
NAT Gateway -- Allows private subnets to access Internet (but not be accessed)
It is important to note that the NAT Gateway lives in a PUBLIC subnet only!
*/
resource "aws_nat_gateway" "main" {

  # The NAT Gateway needs a permanent IP to function
  allocation_id = aws_eip.nat.id

  # Using the first public subnet
  subnet_id = aws_subnet.public[0].id

  tags = {
    Name = "${var.project_name}-nat"
  }
}

/*
Route Table - Public 
What it says: "Hey traffic, if you want to go to the Internet, use the Internet Gateway"

The usage of the 0.0.0.0/0 means *ALL* IP addresses
The "gateway_id = ..." means "Send the traffic through this specific Internet Gateway"

Think of it as GPS navigation: "To go anywhere on the internet (0.0.0.0/0), exit through the Internet Gateway"

The Internet gateway allows for both inbound and outbound traffic to resources/instances in a public subnet
*/
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

/*
Route Table - Private 
What it says: "Hey traffic, if you want to go to the Internet, use the NAT Gateway"

A NAT Gateway is similar to an Internet gateawy, but it:

1. Allows resources in a private subnet to access the Internet [like yum updates, sudo apt upgrade, etc]
2. **MOST CRITICALLY** -- it only works one way. The Internet cannot get to the NAT to private resources
   unless permission is explicitly granted

Many thanks to https://www.reddit.com/r/aws/comments/4qzp38/comment/d4x53r3/?utm_source=share&utm_medium=web3x&utm_name=web3xcss&utm_term=1&utm_content=share_button
for the explanation
*/
resource "aws_route_table" "private" {

  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-private-rt"
  }
}

/*
Route Table Associations
We connect the previously-created route tables to the subnets
Why is this done? A routing table that is created isn't automatically applied!
*/

# This is for the public routing table
resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# This is for the private routing table
resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}