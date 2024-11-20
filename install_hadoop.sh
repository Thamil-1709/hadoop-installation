#!/bin/bash

# Check if the script is run as root
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root. Please use sudo." >&2
  exit 1
fi

# Variables
HADOOP_VERSION="2.7.3"
HADOOP_URL="https://dlcdn.apache.org/hadoop/common/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}.tar.gz"
HADOOP_INSTALL_DIR="/usr/local/hadoop"
JAVA_HOME_DIR=$(dirname $(dirname $(readlink -f $(which java))))

# Helper function for error handling
error_exit() {
  echo "Error: $1" >&2
  exit 1
}

# Update and install dependencies
echo "Updating and installing dependencies..."
apt update -y || error_exit "Failed to update package list"
apt install -y openjdk-11-jdk wget ssh rsync || error_exit "Failed to install dependencies"

# Download Hadoop
echo "Downloading Hadoop..."
wget -q --show-progress "$HADOOP_URL" -P /tmp || error_exit "Failed to download Hadoop"

# Extract Hadoop
echo "Installing Hadoop to $HADOOP_INSTALL_DIR..."
tar -xzf /tmp/hadoop-${HADOOP_VERSION}.tar.gz -C /usr/local || error_exit "Failed to extract Hadoop"
mv /usr/local/hadoop-${HADOOP_VERSION} $HADOOP_INSTALL_DIR || error_exit "Failed to move Hadoop to $HADOOP_INSTALL_DIR"

# Set permissions
echo "Setting permissions for $HADOOP_INSTALL_DIR..."
chown -R $USER:$USER $HADOOP_INSTALL_DIR || error_exit "Failed to set permissions for Hadoop"

# Configure environment variables
echo "Configuring environment variables..."
cat <<EOL >> /etc/profile.d/hadoop.sh
export HADOOP_HOME=$HADOOP_INSTALL_DIR
export PATH=\$PATH:\$HADOOP_HOME/bin:\$HADOOP_HOME/sbin
export JAVA_HOME=$JAVA_HOME_DIR
EOL

source /etc/profile.d/hadoop.sh || error_exit "Failed to source environment variables"

# Configure Hadoop core files
echo "Configuring Hadoop files..."
mkdir -p $HADOOP_INSTALL_DIR/hadoop_data/hdfs/namenode
mkdir -p $HADOOP_INSTALL_DIR/hadoop_data/hdfs/datanode

# Core site configuration
cat <<EOL > $HADOOP_INSTALL_DIR/etc/hadoop/core-site.xml
<configuration>
  <property>
    <name>fs.defaultFS</name>
    <value>hdfs://localhost:9000</value>
  </property>
</configuration>
EOL

# HDFS site configuration
cat <<EOL > $HADOOP_INSTALL_DIR/etc/hadoop/hdfs-site.xml
<configuration>
  <property>
    <name>dfs.replication</name>
    <value>1</value>
  </property>
  <property>
    <name>dfs.namenode.name.dir</name>
    <value>file://$HADOOP_INSTALL_DIR/hadoop_data/hdfs/namenode</value>
  </property>
  <property>
    <name>dfs.datanode.data.dir</name>
    <value>file://$HADOOP_INSTALL_DIR/hadoop_data/hdfs/datanode</value>
  </property>
</configuration>
EOL

# Mapred site configuration
cat <<EOL > $HADOOP_INSTALL_DIR/etc/hadoop/mapred-site.xml
<configuration>
  <property>
    <name>mapreduce.framework.name</name>
    <value>yarn</value>
  </property>
</configuration>
EOL

# YARN site configuration
cat <<EOL > $HADOOP_INSTALL_DIR/etc/hadoop/yarn-site.xml
<configuration>
  <property>
    <name>yarn.nodemanager.aux-services</name>
    <value>mapreduce_shuffle</value>
  </property>
</configuration>
EOL

# Configure SSH for Hadoop
echo "Configuring SSH for Hadoop..."
ssh-keygen -t rsa -P '' -f ~/.ssh/id_rsa || error_exit "Failed to generate SSH keys"
cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys || error_exit "Failed to configure SSH keys"
chmod 0600 ~/.ssh/authorized_keys || error_exit "Failed to set permissions for authorized_keys"
service ssh restart || error_exit "Failed to restart SSH service"

# Format HDFS Namenode
echo "Formatting HDFS Namenode..."
$HADOOP_INSTALL_DIR/bin/hdfs namenode -format || error_exit "Failed to format HDFS Namenode"

echo "Hadoop installation and configuration completed successfully!"
