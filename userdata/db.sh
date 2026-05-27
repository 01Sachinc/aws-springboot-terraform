#!/bin/bash
# Redirect stdout and stderr to a log file for troubleshooting
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

echo "=========================================="
echo "Starting Database Server Configuration"
echo "=========================================="

# Update apt repositories
apt-get update -y

# Install MySQL Server
apt-get install -y mysql-server

# Verify MySQL installation
systemctl status mysql

# Configure MySQL to listen on all network interfaces (bind-address = 0.0.0.0)
# By default, MySQL only listens on localhost (127.0.0.1)
echo "Configuring MySQL to allow remote connections..."
sed -i 's/bind-address\s*=\s*127.0.0.1/bind-address = 0.0.0.0/' /etc/mysql/mysql.conf.d/mysqld.cnf

# Restart MySQL service to apply binding configuration
systemctl restart mysql
systemctl enable mysql

# Create database, user and grant privileges
# Under modern MySQL on Ubuntu, root login does not require password when run via sudo
echo "Creating database and user..."
mysql -u root <<EOF
CREATE DATABASE IF NOT EXISTS \`${db_name}\`;
CREATE USER IF NOT EXISTS '${db_user}'@'%' IDENTIFIED BY '${db_password}';
GRANT ALL PRIVILEGES ON \`${db_name}\`.* TO '${db_user}'@'%';
FLUSH PRIVILEGES;
EOF

echo "=========================================="
echo "Database Configuration Completed"
echo "=========================================="
