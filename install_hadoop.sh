#!/bin/bash

set -e  # Exit immediately if a command fails
set -o pipefail  # Exit if any part of a pipeline fails
trap 'echo "Error occurred on line $LINENO. Exiting..."; exit 1;' ERR

echo "Starting Hadoop installation..."

# Update system
echo "Updating system packages..."
sudo apt-get update -y && sudo apt-get upgrade -y

# Install Java
# Update system package index
echo "Updating system package index..."
sudo apt-get update -y

# Install Java (OpenJDK 8)
echo "Installing OpenJDK 8..."
sudo apt-get install -y openjdk-8-jdk

# Verify Java installation
echo "Verifying Java installation..."
java -version

# Locate Java installation path
JAVA_HOME=$(readlink -f /usr/bin/java | sed "s:/bin/java::")
echo "JAVA_HOME detected as: $JAVA_HOME"

# Configure environment variables
echo "Configuring environment variables..."
cat <<EOL | sudo tee /etc/profile.d/java.sh
# Java environment variables
export JAVA_HOME=$JAVA_HOME
export PATH=\$JAVA_HOME/bin:\$PATH
EOL

# Load the environment variables
echo "Reloading environment variables..."
source /etc/profile.d/java.sh

# Verify JAVA_HOME
echo "Verifying JAVA_HOME..."
echo "JAVA_HOME is set to: $JAVA_HOME"

echo "Java installation and configuration completed successfully."

# Create Hadoop user
echo "Creating Hadoop user..."
sudo addgroup hadoop || echo "Group 'hadoop' already exists."
sudo adduser --ingroup hadoop hadoopuser --disabled-password || echo "User 'hadoopuser' already exists."
echo "hadoopuser:hadoop" | sudo chpasswd
sudo usermod -aG sudo hadoopuser

# Create Hadoop installation directory
HADOOP_INSTALL_DIR="/usr/local/hadoop"
echo "Creating Hadoop installation directory at $HADOOP_INSTALL_DIR..."
sudo mkdir -p $HADOOP_INSTALL_DIR
sudo chown -R hadoopuser:hadoop $HADOOP_INSTALL_DIR

# Switch to Hadoop user for further setup
sudo su - hadoopuser << 'EOF'

HADOOP_VERSION="2.7.3"
HADOOP_DOWNLOAD_URL="https://archive.apache.org/dist/hadoop/core/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}.tar.gz"
INSTALL_DIR="/usr/local/hadoop"

# Download and extract Hadoop
echo "Downloading Hadoop $HADOOP_VERSION..."
if ! wget -q ${HADOOP_DOWNLOAD_URL} -O /tmp/hadoop-${HADOOP_VERSION}.tar.gz; then
    echo "Failed to download Hadoop. Check your internet connection."
    exit 1
fi

echo "Extracting Hadoop..."
if ! tar -xzf /tmp/hadoop-${HADOOP_VERSION}.tar.gz -C ${INSTALL_DIR} --strip-components=1; then
    echo "Failed to extract Hadoop."
    exit 1
fi

# Set up environment variables
echo "Setting up environment variables..."
cat <<EOL >> ~/.bashrc
# Hadoop environment variables
export HADOOP_HOME=${INSTALL_DIR}
export HADOOP_CONF_DIR=\$HADOOP_HOME/etc/hadoop
export PATH=\$PATH:\$HADOOP_HOME/bin:\$HADOOP_HOME/sbin
EOL
source ~/.bashrc

# Create necessary Hadoop configuration files and directories
echo "Configuring Hadoop directories and files..."
mkdir -p \$HADOOP_HOME/hdfs/namenode
mkdir -p \$HADOOP_HOME/hdfs/datanode

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

cat <<EOL >> \$HADOOP_CONF_DIR/hadoop-env.sh
export JAVA_HOME=$(readlink -f /usr/bin/java | sed "s:/bin/java::")
EOL

# Format the HDFS namenode
echo "Formatting the HDFS namenode..."
if ! \$HADOOP_HOME/bin/hdfs namenode -format; then
    echo "Failed to format the HDFS namenode."
    exit 1
fi

EOF

# Ensure correct permissions for Hadoop directories
sudo chown -R hadoopuser:hadoop /usr/local/hadoop

echo "Hadoop installation completed successfully. Switch to the hadoopuser account to use Hadoop."
