resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name        = "${var.vpc_name}-vpc"
    Environment = var.environment
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "${var.vpc_name}-igw"
    Environment = var.environment
  }
}

# Public Subnets
resource "aws_subnet" "public" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name        = "${var.vpc_name}-public-subnet-${count.index + 1}"
    Environment = var.environment
  }
}

# Private Subnets
resource "aws_subnet" "private" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name        = "${var.vpc_name}-private-subnet-${count.index + 1}"
    Environment = var.environment
  }
}

# Route Tables
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name        = "${var.vpc_name}-public-route-table"
    Environment = var.environment
  }
}

resource "aws_route_table" "private" {
  count  = length(var.private_subnet_cidrs)
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "${var.vpc_name}-private-route-table-${count.index + 1}"
    Environment = var.environment
  }
}

# Route Table Associations
resource "aws_route_table_association" "public" {
  count          = length(var.public_subnet_cidrs)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count          = length(var.private_subnet_cidrs)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# s3 endpoint
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = aws_route_table.private[*].id
}

# security group to allow access to vpc endpoints from everything in vpc
resource "aws_security_group" "vpc_endpoint" {
  name        = "${var.vpc_name}-vpc-endpoint"
  description = "Allow access to vpc endpoints from everything in vpc"
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
}

# ECR DKR endpoint
resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.region}.ecr.dkr"
  vpc_endpoint_type = "Interface"
  subnet_ids        = aws_subnet.private[*].id
  security_group_ids = [aws_security_group.vpc_endpoint.id]

  private_dns_enabled = true

  tags = {
    Name        = "${var.vpc_name}-ecr-dkr-endpoint"
    Environment = var.environment
  }
}

# ECR API endpoint
# resource "aws_vpc_endpoint" "ecr_api" {
#   vpc_id            = aws_vpc.main.id
#   service_name      = "com.amazonaws.${var.region}.ecr.api"
#   vpc_endpoint_type = "Interface"
#   subnet_ids        = aws_subnet.private[*].id
#   security_group_ids = [aws_security_group.vpc_endpoint.id]

#   private_dns_enabled = true

#   tags = {
#     Name        = "${var.vpc_name}-ecr-api-endpoint"
#     Environment = var.environment
#   }
# }

# iam endpoints
# resource "aws_vpc_endpoint" "iam" {
#   vpc_id            = aws_vpc.main.id
#   service_name      = "com.amazonaws.iam"
#   vpc_endpoint_type = "Interface"
#   subnet_ids        = aws_subnet.private[*].id
#   security_group_ids = [aws_security_group.vpc_endpoint.id]

#   private_dns_enabled = true

#   tags = {
#     Name        = "${var.vpc_name}-iam-endpoint"
#     Environment = var.environment
#   }
# }

# ssm endpoint
resource "aws_vpc_endpoint" "ssm" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.region}.ssm"
  vpc_endpoint_type = "Interface"
  subnet_ids        = aws_subnet.private[*].id
  security_group_ids = [aws_security_group.vpc_endpoint.id]

  private_dns_enabled = true

  tags = {
    Name        = "${var.vpc_name}-ssm-endpoint"
    Environment = var.environment
  }
}

# ssm messages endpoint
resource "aws_vpc_endpoint" "ssm_messages" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.region}.ssmmessages"
  vpc_endpoint_type = "Interface"
  subnet_ids        = aws_subnet.private[*].id
  security_group_ids = [aws_security_group.vpc_endpoint.id]

  private_dns_enabled = true

  tags = {
    Name        = "${var.vpc_name}-ssm-messages-endpoint"
    Environment = var.environment
  }
}

# sts endpoint
resource "aws_vpc_endpoint" "sts" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.region}.sts"
  vpc_endpoint_type = "Interface"
  subnet_ids        = aws_subnet.private[*].id
  security_group_ids = [aws_security_group.vpc_endpoint.id]

  private_dns_enabled = true

  tags = {
    Name        = "${var.vpc_name}-sts-endpoint"
    Environment = var.environment
  }
}
