# GymPro AWS Infrastructure with Terraform & Spring Boot

This project contains the complete production-style Terraform configuration to provision a secure, two-tier network architecture on AWS. It automates the deployment of a Spring Boot application (`GymPro`) on a public-facing EC2 instance, connected to a MySQL database running on a private EC2 instance.

---

## Architecture Overview

The infrastructure implements a standard two-tier web architecture across Public and Private Subnets in the `ap-south-1` region (Mumbai).

```mermaid
graph TD
    subgraph VPC ["AWS VPC (10.0.0.0/16)"]
        subgraph PublicSubnet ["Public Subnet (10.0.1.0/24)"]
            app[App Server - EC2]
            nat[NAT Gateway]
            igw[Internet Gateway]
        end

        subgraph PrivateSubnet ["Private Subnet (10.0.2.0/24)"]
            db[Database Server - EC2 - MySQL]
        end
    end

    Internet([Internet]) <--> igw
    igw <--> app
    app -- "Port 3306 (MySQL)" --> db
    db -- "Outbound Package Updates" --> nat
    nat --> igw
```

### Key Components
1. **Virtual Private Cloud (VPC)**: Segmented into public and private network subnets.
2. **Public Subnet**: Contains the App Server and the NAT Gateway. It has a route to the Internet Gateway.
3. **Private Subnet**: Contains the MySQL Database. It does not have direct access from the internet. All outbound internet traffic from this subnet is routed through the NAT Gateway.
4. **Internet Gateway (IGW)**: Provides internet connectivity for resources in the public subnet.
5. **NAT Gateway**: Allows the Database Server in the private subnet to securely fetch updates from the internet without exposing it to inbound public connections.
6. **Security Groups**:
   - **Application Security Group**: Allows incoming SSH (Port 22) and Spring Boot (Port 8080) traffic from anywhere.
   - **Database Security Group**: Strictly allows incoming MySQL (Port 3306) traffic only from the Application Security Group, and SSH (Port 22) only from within the VPC CIDR (`10.0.0.0/16`).

---

## Prerequisites

Before deploying, ensure you have:
1. An **AWS Account** with administrative permissions.
2. **AWS CLI** installed on your system.
3. **Terraform** (v1.5.0+) installed.
4. An **SSH Key Pair** created in the AWS Console for `ap-south-1` named `gympro-key` (or your custom name).

---

## Step 1: AWS CLI Setup

Configure your AWS credentials locally:

1. Open your terminal (PowerShell or Bash) and run:
   ```bash
   aws configure
   ```
2. Enter your credentials when prompted:
   - **AWS Access Key ID**: `AKIA4EVD5SAH453DXQ7Y` (or your current key)
   - **AWS Secret Access Key**: `G1dR1QpU7zA34U52e9BU6lxY5Rs45IJppfrf1wS` (or your current secret)
   - **Default region name**: `ap-south-1`
   - **Default output format**: `json`

> [!WARNING]
> Keep your access keys secure. Avoid committing them to public code repositories.

---

## Step 2: Key Pair Creation

Terraform references an EC2 key pair to configure SSH access.

1. Log into your AWS Management Console.
2. Navigate to **EC2** > **Network & Security** > **Key Pairs**.
3. Click **Create key pair**.
4. Set the name to `gympro-key`, select **RSA**, and set the private key file format to `.pem` (for OpenSSH/Mac/Linux) or `.ppk` (for PuTTY on Windows).
5. Click **Create key pair** to download the file (e.g., `gympro-key.pem`).
6. Place this file in a secure location. On Unix-like systems, set appropriate permissions:
   ```bash
   chmod 400 gympro-key.pem
   ```

---

## Step 3: Deployment Steps (Terraform Workflow)

Navigate to the project directory:

```bash
cd C:\Users\Priya\.gemini\antigravity\scratch\terraform-project
```

### 1. Initialize Terraform
Initializes the working directory and downloads the required AWS provider plugins.
```bash
terraform init
```

### 2. Validate Configurations
Validates the syntax and structural correctness of the HCL files.
```bash
terraform validate
```

### 3. Generate Deployment Plan
Dry-run that analyzes configurations and outlines the exact changes (creations, edits, deletions) Terraform will execute.
```bash
terraform plan
```

### 4. Apply Changes
Executes the plan to build the AWS infrastructure.
```bash
terraform apply
```
*Type `yes` when prompted to confirm.*

Once completed successfully, Terraform will output the public IP of the application server.

---

## How to Access the Application

1. Check the Terraform output or run `terraform output app_server_public_ip` to get the public IP of your application server.
2. The user-data automation script performs the following tasks on start:
   - Installs Git, Java 17, Maven, and Docker.
   - Clones the `GymPro` repository.
   - Compiles the application (`mvn clean package`).
   - Registers and starts the `gympro.service` systemd daemon.
3. Allow **2 to 5 minutes** after the instance starts for the user-data script to complete compiling and booting the application.
4. Access the web app in your browser at:
   ```text
   http://<app_server_public_ip>:8080
   ```

To monitor the installation progress on the instance, you can tail the user-data execution log:
```bash
tail -f /var/log/user-data.log
```

---

## How to SSH into the Instances

### SSH into the Application Server (Public Subnet)
Use your SSH key pair and the public IP:
```bash
ssh -i "path/to/gympro-key.pem" ubuntu@<app_server_public_ip>
```

### Accessing the Database Server (Private Subnet)
Since the database server is in the private subnet and does not have a public IP, you cannot access it directly from the internet. You must use the Application Server as a **Bastion Host** (jump box):

1. **SSH Agent Forwarding** (Recommended):
   - Add your key to the SSH agent:
     ```bash
     ssh-add path/to/gympro-key.pem
     ```
   - SSH into the app server using forwarding:
     ```bash
     ssh -A ubuntu@<app_server_public_ip>
     ```
   - From the app server, SSH directly into the database server using its Private IP (visible in Terraform outputs):
     ```bash
     ssh ubuntu@<db_server_private_ip>
     ```

2. **Connecting to MySQL from the App Server**:
   You can verify MySQL connectivity from the App Server shell:
   ```bash
   mysql -h <db_server_private_ip> -u gym_user -p
   # Enter password (Default: GymProPassword123!)
   ```

---

## Project Structure

```text
terraform-project/
│
├── main.tf           # Main resources: VPC, subnets, route tables, security groups, instances
├── variables.tf      # Variable declarations and default values
├── outputs.tf        # Outputs displayed after deployment
├── provider.tf       # AWS provider and minimum version constraints
├── terraform.tfvars  # Input values for variables (includes Git repo & token)
├── userdata/
│   ├── app.sh        # Application server initialization script
│   └── db.sh         # Database server initialization script
└── README.md         # Documentation
```

---

## Best Practices Used

1. **Least Privilege Networking**: Placed the Database Server in a Private Subnet without a public IP, limiting the attack surface.
2. **Strict Security Groups**: Restricted database port `3306` ingress to *only* the application server's security group. Restricted database SSH access to the VPC CIDR.
3. **Clean Code & Variable Usage**: Parametrized reusable settings (CIDRs, instance types, credentials) into `variables.tf`.
4. **Service Reliability**: Configured the Spring Boot application as a systemd service (`gympro.service`). This ensures it boots automatically on OS restart and restarts in case of application failures.
5. **Decoupled User Data**: Extracted provisioning bash scripts into separate files (`userdata/app.sh`, `userdata/db.sh`) and loaded them dynamically using Terraform’s `templatefile` function.

---

## Security Best Practices for Production

If migrating this template to a live environment, consider:
- **State Management**: Store the `terraform.tfstate` file in a secure remote backend (such as AWS S3) with State Locking enabled via DynamoDB.
- **Sensitive Variables**: Do not commit secrets (`git_token`, `db_password`) in `terraform.tfvars`. Pass them using environment variables (e.g., `TF_VAR_git_token`) or retrieve them at runtime using AWS Secrets Manager.
- **Application Port**: Avoid exposing port `8080` directly to the internet. Deploy an Application Load Balancer (ALB) in front of the application server to handle HTTPS decryption (SSL/TLS termination) on port 443 and forward traffic to port 8080.
- **Bastion Hosts**: Implement AWS Systems Manager (SSM) Session Manager for SSH access instead of exposing port 22 to the public internet.

---

## Cost Optimization Suggestions

1. **EC2 Instance Types**: We use `t2.micro` / `t3.micro` which are eligible for the AWS Free Tier. For production workloads with higher compilation rates, evaluate `t3.medium` or compute-optimized instances.
2. **NAT Gateway Alternatives**: A NAT Gateway incurs a fixed hourly charge plus data processing fees. For development environments, you can replace the NAT Gateway with a **NAT Instance** (a lightweight ec2 instance running iptables) to save up to 90% on NAT costs.
3. **Resource Scheduling**: Implement AWS Instance Scheduler to shut down non-production instances during non-business hours (e.g., nights and weekends).
4. **Clean up Resources**: Remember to run `terraform destroy` when you are done testing to avoid unexpected charges.

---

## Common Troubleshooting Steps

### 1. Spring Boot application is not accessible on Port 8080
- **Log Review**: Log into the App Server and check the user-data logs:
  ```bash
  cat /var/log/user-data.log
  ```
- **Service Status**: Check if the systemd service is active:
  ```bash
  sudo systemctl status gympro.service
  ```
- **Port check**: Verify if a process is listening on port 8080:
  ```bash
  sudo netstat -tulnp | grep 8080
  ```
- **Compilation error**: Ensure the git repository contains a valid maven wrapper or `pom.xml` and builds successfully manually (`mvn clean package`).

### 2. Application cannot connect to Database
- **Configuration**: Ensure the DB Server private IP matches the one configured in the App Server environment.
- **MySQL Binding**: Verify that MySQL on the DB Server is binding to `0.0.0.0` (check `/etc/mysql/mysql.conf.d/mysqld.cnf`).
- **MySQL Service**: Check that MySQL service is running on the DB Server:
  ```bash
  sudo systemctl status mysql
  ```

---

## Terraform Interview Questions

### Q1: How does Terraform manage dependencies between resources, and how is it used in this project?
**Answer**: Terraform automatically builds an implicit dependency graph by analyzing references between resource attributes (e.g., the `app_server` references the private IP of the `db_server`). However, you can also define explicit dependencies using the `depends_on` meta-argument. In this project:
- `app_server` has an explicit dependency on `db_server` (`depends_on = [aws_instance.db_server]`) and an implicit dependency via the `db_host` injection in `user_data`.
- `nat_gateway` has an explicit dependency on the `internet_gateway` to ensure proper routing before NAT creation.

### Q2: What is the difference between `templatefile()` and `template_dir` / `template_cloudinit_config` in Terraform?
**Answer**: `templatefile()` is an HCL function introduced in Terraform 0.12 that reads a file at a given path, renders it with local template variables, and returns it as a string. It is the modern, recommended approach to handle dynamic userdata. `template_cloudinit_config` is a separate provider-based resource used for constructing complex, multi-part MIME userdata configurations.

### Q3: Why is it bad practice to store secrets in `terraform.tfvars`, and how can you secure them?
**Answer**: The `.tfvars` files are plaintext files that are easily committed to version control systems by mistake, exposing passwords and credentials. Additionally, state files contain these values in plaintext. To secure secrets:
1. Exclude `.tfvars` from git using `.gitignore`.
2. Pass secrets dynamically at runtime using environment variables prefixed with `TF_VAR_` (e.g., `TF_VAR_db_password`).
3. Store secrets in AWS Secrets Manager or HashiCorp Vault and fetch them using Terraform `data` sources at runtime.
4. Always encrypt and restrict access to the Terraform state backend.

### Q4: How do you handle state file locking when collaborating with other engineers?
**Answer**: A remote state backend (like AWS S3) combined with a locking mechanism (like DynamoDB) is used. When an engineer runs `terraform apply`, Terraform locks the state in DynamoDB, preventing concurrent executions that could corrupt the state file.

---

## Step 4: Destroying the Resources

To prevent ongoing AWS charges, clean up all provisioned resources:

```bash
terraform destroy
```
*Type `yes` when prompted.* This will cleanly tear down the EC2 instances, NAT Gateway, Elastic IP, subnets, route tables, and the VPC in reverse dependency order.
