# ==============================================================================
# AWS NETWORK RESOURCES
# ==============================================================================

# Virtual Private Cloud (VPC)
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "gympro-vpc"
    Environment = "Production"
    Project     = "GymPro"
  }
}

# Internet Gateway (IGW) for Public Subnet internet access
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "gympro-igw"
    Environment = "Production"
    Project     = "GymPro"
  }
}

# Public Subnet (Hosts the Application Server)
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = true

  tags = {
    Name        = "gympro-public-subnet"
    Environment = "Production"
    Project     = "GymPro"
  }
}

# Private Subnet (Hosts the Database Server)
resource "aws_subnet" "private" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.private_subnet_cidr
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = false

  tags = {
    Name        = "gympro-private-subnet"
    Environment = "Production"
    Project     = "GymPro"
  }
}

# Elastic IP for NAT Gateway
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name        = "gympro-nat-eip"
    Environment = "Production"
    Project     = "GymPro"
  }
}

# NAT Gateway (Deployed in Public Subnet to give Private Subnet outbound internet access)
resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id

  tags = {
    Name        = "gympro-nat-gw"
    Environment = "Production"
    Project     = "GymPro"
  }

  depends_on = [aws_internet_gateway.igw]
}

# ==============================================================================
# ROUTE TABLES & ASSOCIATIONS
# ==============================================================================

# Route Table for Public Subnet
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name        = "gympro-public-rt"
    Environment = "Production"
    Project     = "GymPro"
  }
}

# Route Table for Private Subnet
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw.id
  }

  tags = {
    Name        = "gympro-private-rt"
    Environment = "Production"
    Project     = "GymPro"
  }
}

# Associate Public Route Table with Public Subnet
resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Associate Private Route Table with Private Subnet
resource "aws_route_table_association" "private_assoc" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

# ==============================================================================
# SECURITY GROUPS
# ==============================================================================

# Application Security Group (Public EC2)
resource "aws_security_group" "app_sg" {
  name        = "gympro-app-sg"
  description = "Security group for application server hosting Spring Boot"
  vpc_id      = aws_vpc.main.id

  # Allow SSH from anywhere
  ingress {
    description = "Allow SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow HTTP traffic on application port 8080 from anywhere
  ingress {
    description = "Allow Spring Boot HTTP traffic"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Egress - Allow all traffic outbound
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "gympro-app-sg"
    Environment = "Production"
    Project     = "GymPro"
  }
}

# Database Security Group (Private EC2)
resource "aws_security_group" "db_sg" {
  name        = "gympro-db-sg"
  description = "Security group for database server hosting MySQL"
  vpc_id      = aws_vpc.main.id

  # Allow MySQL traffic (3306) only from Application Security Group
  ingress {
    description     = "Allow MySQL traffic from app server only"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.app_sg.id]
  }

  # Allow SSH (22) traffic only from the VPC CIDR
  ingress {
    description = "Allow SSH only from VPC CIDR"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # Egress - Allow outbound traffic (needed for package installation/updates via NAT)
  egress {
    description = "Allow all outbound traffic for installation"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "gympro-db-sg"
    Environment = "Production"
    Project     = "GymPro"
  }
}

# ==============================================================================
# DATA SOURCES
# ==============================================================================

# Fetch the latest Ubuntu 22.04 LTS AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ==============================================================================
# EC2 COMPUTING RESOURCES
# ==============================================================================

# Database Server (Deploys in Private Subnet)
resource "aws_instance" "db_server" {
  ami                    = var.ami_id
  instance_type          = var.instance_type_db
  subnet_id              = aws_subnet.private.id
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  key_name               = var.key_name

  # Inject user data script template with variables
  user_data = templatefile("${path.module}/userdata/db.sh", {
    db_name     = var.db_name
    db_user     = var.db_user
    db_password = var.db_password
  })

  tags = {
    Name        = "gympro-db-server"
    Environment = "Production"
    Project     = "GymPro"
  }
}

# Application Server (Deploys in Public Subnet)
resource "aws_instance" "app_server" {
  ami                    = var.ami_id
  instance_type          = var.instance_type_app
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.app_sg.id]
  key_name               = var.key_name

  # Inject user data script template with variables
  # It depends on db_server's private IP, ensuring proper provisioning order
  user_data = templatefile("${path.module}/userdata/app.sh", {
    git_repo    = var.git_repo
    git_token   = var.git_token
    db_host     = aws_instance.db_server.private_ip
    db_name     = var.db_name
    db_user     = var.db_user
    db_password = var.db_password
  })

  tags = {
    Name        = "gympro-app-server"
    Environment = "Production"
    Project     = "GymPro"
  }

  # Explicit dependency to ensure DB is initialized
  depends_on = [aws_instance.db_server]
}
