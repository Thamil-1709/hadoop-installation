#!/bin/bash

# Hadoop installation script with error handling for Ubuntu
# Version: Hadoop 2.7.3

set -e            # Exit on any command failure
set -o pipefail   # Ensure pipelines fail if any command fails
trap 'echo "Error occurred on line $LINENO. Exiting..."; exit 1;' ERR

echo "Starting Hadoop 2.7.3 installation on Ubuntu..."

# Function to check if a command succeeded
check_success() {
    if [ $? -ne 0 ]; then
        echo "Error: $1 failed. Exiting..."
        exit 1
    fi
}

# Update the system
echo "Updating system..."
sudo apt-get update -y && sudo apt-get upgrade -y
check_success "System update and upgrade"

# Install Java
echo "Installing Java..."
sudo apt-get install -y openjdk-8-jdk
check_success "Java installation"
echo "Java installed successfully."
java -version || { echo "Java not installed properly. Exiting..."; exit 1; }

# Create a Hadoop user and group
echo "Setting up Hadoop user and group..."
sudo addgroup hadoop || echo "Group 'hadoop' already exists."
sudo adduser --ingroup hadoop hadoopuser --disabled-password || echo "User 'hadoopuser' already exists."
echo "hadoopuser:hadoop" | sudo chpasswd
sudo usermod -aG sudo hadoopuser
check_success "Hadoop user and group setup"
echo "hadoopuser created and added to the sudo group."

# Create Hadoop installation directory
echo "Setting up Hadoop installation directory..."
HADOOP_INSTALL_DIR="/usr/local/hadoop"
sudo mkdir -p "$HADOOP_INSTALL_DIR"
sudo chown -R hadoopuser:hadoop "$HADOOP_INSTALL_DIR"
check_success "Hadoop installation directory setup"

# Switch to the hadoopuser for further setup
sudo su - hadoopuser << 'EOF'

# Variables
HADOOP_VERSION="2.7.3"
HADOOP_DOWNLOAD_URL="https://archive.apache.org/dist/hadoop/core/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}.tar.gz"
INSTALL_DIR="/usr/local/hadoop"

# Download and extract Hadoop
echo "Downloading Hadoop $HADOOP_VERSION..."
wget -q "${HADOOP_DOWNLOAD_URL}" -O "/tmp/hadoop-${HADOOP_VERSION}.tar.gz" || { echo "Failed to download Hadoop. Exiting..."; exit 1; }

echo "Extracting Hadoop..."
tar -xzf "/tmp/hadoop-${HADOOP_VERSION}.tar.gz" -C "$INSTALL_DIR" --strip-components=1 || { echo "Extraction failed. Exiting..."; exit 1; }

# Configure environment variables
echo "Configuring environment variables..."
cat <<EOL >> ~/.bashrc
# Hadoop environment variables
export HADOOP_HOME=${INSTALL_DIR}
export HADOOP_CONF_DIR=\$HADOOP_HOME/etc/hadoop
export PATH=\$PATH:\$HADOOP_HOME/bin:\$HADOOP_HOME/sbin
EOL
source ~/.bashrc || { echo "Failed to load environment variables. Exiting..."; exit 1; }

# Configure Hadoop XML files
echo "Configuring Hadoop XML files..."
cat <<EOL > \$HADOOP_CONF_DIR/core-site.xml
<configuration>
  <property>
    <name>fs.defaultFS</name>
    <value>hdfs://localhost:9000</value>
  </property>
</configuration>
EOL

cat <<EOL > \$HADOOP_CONF_DIR/hdfs-site.xml
<configuration>
  <property>
    <name>dfs.replication</name>
    <value>1</value>
  </property>
</configuration>
EOL

cat <<EOL > \$HADOOP_CONF_DIR/mapred-site.xml
<configuration>
  <property>
    <name>mapreduce.framework.name</name>
    <value>yarn</value>
  </property>
</configuration>
EOL

cat <<EOL > \$HADOOP_CONF_DIR/yarn-site.xml
<configuration>
  <property>
    <name>yarn.resourcemanager.hostname</name>
    <value>localhost</value>
  </property>
  <property>
    <name>yarn.nodemanager.aux-services</name>
    <value>mapreduce_shuffle</value>
  </property>
</configuration>
EOL

# Setup HDFS directories
echo "Setting up HDFS directories..."
mkdir -p \$HADOOP_HOME/hdfs/namenode
mkdir -p \$HADOOP_HOME/hdfs/datanode
cat <<EOL >> \$HADOOP_CONF_DIR/hadoop-env.sh
export JAVA_HOME=$(readlink -f /usr/bin/java | sed "s:/bin/java::")
EOL

# Format HDFS namenode
echo "Formatting HDFS namenode..."
\$HADOOP_HOME/bin/hdfs namenode -format || { echo "HDFS namenode formatting failed. Exiting..."; exit 1; }

EOF

# Set permissions and ownership
echo "Updating permissions and ownership..."
sudo chown -R hadoopuser:hadoop /usr/local/hadoop
check_success "Permissions and ownership update"

# Final validation
echo "Verifying Hadoop installation..."
sudo su - hadoopuser -c "hadoop version" || { echo "Hadoop installation verification failed. Exiting..."; exit 1; }

# Cleanup
echo "Cleaning up temporary files..."
sudo rm -rf "/tmp/hadoop-${HADOOP_VERSION}.tar.gz"

echo "Hadoop installation completed successfully. Log in as hadoopuser to start using Hadoop."
