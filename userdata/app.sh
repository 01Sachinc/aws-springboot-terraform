#!/bin/bash
# Redirect stdout and stderr to a log file for troubleshooting
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

echo "=========================================="
echo "Starting Application Server Configuration"
echo "=========================================="

# Update apt repositories
apt-get update -y

# Install dependencies (Java 17, Maven, Git, Docker)
echo "Installing OpenJDK 17, Maven, Git, and Docker..."
apt-get install -y openjdk-17-jdk openjdk-17-jre maven git docker.io

# Start and enable Docker service
echo "Starting and enabling Docker..."
systemctl start docker
systemctl enable docker
usermod -aG docker ubuntu

# Clone the Spring Boot repository using the provided credentials
GIT_URL="${git_repo}"
GIT_TOKEN="${git_token}"

if [ -n "$GIT_TOKEN" ]; then
  # Strip https:// if it exists in the git_repo variable to avoid duplication
  CLEAN_URL=$(echo "$https://github.com/01Sachinc/GymPro.git" | sed 's|https://||')
  CLONE_URL="https://$GIT_TOKEN@$CLEAN_URL"
  echo "Cloning repository with provided Git Token..."
else
  CLONE_URL="$GIT_URL"
  echo "Cloning repository anonymously..."
fi

mkdir -p /opt/gympro
git clone "$https://github.com/01Sachinc/GymPro.git" /opt/gympro
cd /opt/gympro

# Build the application using Maven (skipping tests during initial deploy to prevent failure before DB is ready)
echo "Building the Spring Boot application..."
mvn clean package -DskipTests

# Find the built jar file and create a static symlink for systemd service
JAR_PATH=$(find target/ -name "*.jar" | head -n 1)
if [ -z "$JAR_PATH" ]; then
  echo "Error: No JAR file was found in target directory!"
  exit 1
fi
echo "Found JAR file at $JAR_PATH. Creating symlink /opt/gympro/app.jar..."
ln -sf "/opt/gympro/$JAR_PATH" /opt/gympro/app.jar

# Create a systemd service file to run the Spring Boot application
echo "Creating systemd service configuration..."
cat <<EOF > /etc/systemd/system/gympro.service
[Unit]
Description=GymPro Spring Boot Application
After=network.target

[Service]
User=root
WorkingDirectory=/opt/gympro
ExecStart=/usr/bin/java -Dserver.port=8080 -jar /opt/gympro/app.jar
SuccessExitStatus=143
TimeoutStopSec=10
Restart=on-failure
RestartSec=5

# Inject DB environment variables so Spring Boot picks them up automatically
Environment=SPRING_DATASOURCE_URL=jdbc:mysql://${db_host}:3306/${db_name}?useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=UTC
Environment=SPRING_DATASOURCE_USERNAME=${root}
Environment=SPRING_DATASOURCE_PASSWORD=${root}

[Install]
WantedBy=multi-user.target
EOF

# Reload daemon, enable and start application service
echo "Starting GymPro application service..."
systemctl daemon-reload
systemctl enable gympro
systemctl start gympro

echo "=========================================="
echo "Application Server Configuration Completed"
echo "=========================================="
