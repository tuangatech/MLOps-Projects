resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
  tags = {
    Name = "${var.project_name}-${var.environment}-vpc"
  }
}

resource "aws_subnet" "public_subnets" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  map_public_ip_on_launch = true
  availability_zone       = element(var.azs, count.index)

  tags = {
    Name = "${var.project_name}-${var.environment}-public-subnet-${count.index + 1}"
  }
}

resource "aws_subnet" "private_subnets" {
  count                   = length(var.private_subnet_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.private_subnet_cidrs[count.index]
  map_public_ip_on_launch = false
  availability_zone       = element(var.azs, count.index)

  tags = {
    Name = "${var.project_name}-${var.environment}-private-subnet-${count.index + 1}"
  }
}

resource "aws_security_group" "mwaa_sg" {
  name        = "${var.project_name}-${var.environment}-mwaa-sg"
  description = "Allow MWAA access"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-mwaa-sg"
  }
}