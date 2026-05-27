# AWS Region & AZ
aws_region        = "ap-south-1"
availability_zone = "ap-south-1a"

# Networking Configuration
vpc_cidr            = "10.0.0.0/16"
public_subnet_cidr  = "10.0.1.0/24"
private_subnet_cidr = "10.0.2.0/24"

# EC2 Instance Configurations
instance_type_app = "t2.micro"
instance_type_db  = "t2.micro"
key_name          = "security"
ami_id            = "ami-07a00cf47dbbc844c"



# Application Git Repository Configuration
git_repo  = "https://github.com/01Sachinc/GymPro.git"
git_token = ""


# Database Configuration
db_name     = "gympro_db"
db_user     = "gym_user"
db_password = "GymProPassword123!"
