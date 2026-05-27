variable "aws_region" {
  description = "The AWS region to deploy the infrastructure in"
  type        = string
  default     = "ap-south-1"
}

variable "availability_zone" {
  description = "The availability zone to place resources in"
  type        = string
  default     = "ap-south-1a"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_subnet_cidr" {
  description = "CIDR block for the private subnet"
  type        = string
  default     = "10.0.2.0/24"
}

variable "instance_type_app" {
  description = "EC2 instance type for the Spring Boot application server"
  type        = string
  default     = "t3.micro"
}

variable "instance_type_db" {
  description = "EC2 instance type for the MySQL database server"
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "The name of the SSH key pair to associate with EC2 instances. Ensure this exists in your AWS region."
  type        = string
  default     = "gympro-key"
}

variable "git_repo" {
  description = "GitHub repository URL of the Spring Boot application"
  type        = string
  default     = "https://github.com/01Sachinc/GymPro.git"
}

variable "git_token" {
  description = "Personal Access Token for cloning the GitHub repository (if private)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "db_name" {
  description = "Name of the MySQL database to create"
  type        = string
  default     = "gympro_db"
}

variable "db_user" {
  description = "Username for the database user"
  type        = string
  default     = "gym_user"
}

variable "db_password" {
  description = "Password for the database user"
  type        = string
  default     = "GymProPassword123!"
  sensitive   = true
}

variable "ami_id" {
  description = "The AMI ID to use for the EC2 instances"
  type        = string
  default     = "ami-07a00cf47dbbc844c"
}

