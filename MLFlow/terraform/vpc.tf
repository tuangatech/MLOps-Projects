# Create a VPC for hosting our FastAPI service securely
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"   # IP range for this network
  enable_dns_hostnames = true            # Enable DNS resolution (e.g., myservice.local)
  enable_dns_support   = true            # Allow internal DNS lookups

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

# Public subnet in Availability Zone A
resource "aws_subnet" "public_subnet_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"         # First subnet
  map_public_ip_on_launch = true             # Auto assign public IPs
  availability_zone = "${var.region}a"       # e.g., us-east-1a

  tags = {
    Name = "${var.project_name}-public-subnet-1"
  }
}

# Public subnet in Availability Zone B
resource "aws_subnet" "public_subnet_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"         # Second subnet
  map_public_ip_on_launch = true             # Auto assign public IPs
  availability_zone = "${var.region}b"       # e.g., us-east-1b

  tags = {
    Name = "${var.project_name}-public-subnet-2"
  }
}

# Internet Gateway connects the VPC to the internet
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "${var.project_name}-igw"
  }
}

# Route Table defines where traffic goes
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"                    # All internet traffic
    gateway_id = aws_internet_gateway.gw.id     # goes through IGW
  }

  tags = {
    Name = "${var.project_name}-public-route-table"
  }
}

# Associate both subnets with the public route table, 
# defining how traffic flows in/out of that subnet
resource "aws_route_table_association" "public_assoc_1" {
  subnet_id      = aws_subnet.public_subnet_1.id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_route_table_association" "public_assoc_2" {
  subnet_id      = aws_subnet.public_subnet_2.id
  route_table_id = aws_route_table.public_route_table.id
}