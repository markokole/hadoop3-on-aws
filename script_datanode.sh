#!/bin/bash

# update the system and install java
sudo apt-get update -y
sudo -s apt-get install grub -y
sudo apt-get upgrade -y
sudo apt-get install default-jdk -y

# add JAVA_HOME to env variables
sudo touch /etc/profile.d/hadoop.sh
sudo echo 'export JAVA_HOME="/usr/lib/jvm/java-8-openjdk-amd64"' | sudo tee /etc/profile.d/hadoop.sh
source /etc/profile.d/hadoop.sh

# create directories for Hadoop
sudo mkdir /apache
sudo mkdir /apache/hadoop
cd /apache/hadoop/

# create user hadoop
sudo su -c "useradd hadoop -s /bin/bash"
echo "hadoop:hadoop" | sudo chpasswd

# create user hdfs
sudo su -c "useradd hdfs -s /bin/bash"
echo "hdfs:hdfs" | sudo chpasswd

# add user hdfs to hadoop group
sudo usermod -a -G hadoop hdfs

# create user yarn
sudo su -c "useradd yarn -s /bin/bash"
echo "yarn:yarn" | sudo chpasswd

# add user yarn to hadoop group
sudo usermod -a -G hadoop yarn

# change ownership
sudo chown -R hadoop:hadoop /apache/hadoop

# download Hadoop 3.1 and unpack it
sudo -u hadoop wget http://apache.uib.no/hadoop/common/hadoop-3.1.0/hadoop-3.1.0.tar.gz -P /apache/hadoop
sudo -u hadoop tar -xvzf hadoop-3.1.0.tar.gz
sudo -u hadoop rm hadoop-3.1.0.tar.gz

# add HADOOP_HOME to env variables
sudo echo 'export HADOOP_HOME="/apache/hadoop/hadoop-3.1.0"' | sudo tee -a /etc/profile.d/hadoop.sh

# add HADOOP_CONF_DIR to env variables
sudo echo 'export HADOOP_CONF_DIR="/apache/hadoop/hadoop-3.1.0/etc/hadoop"' | sudo tee -a /etc/profile.d/hadoop.sh

# add HADOOP_HOME to PATH
sudo echo 'PATH="$PATH:$HADOOP_HOME/bin:$HADOOP_HOME/sbin"' | sudo tee -a /etc/profile.d/hadoop.sh
source /etc/profile.d/hadoop.sh

# create Hadoop logs directory and adjust RWX rights
sudo -u hadoop mkdir $HADOOP_HOME/logs
sudo -u hadoop chmod -R 775 $HADOOP_HOME/logs

# add JAVA_HOME to hadoop-env.sh
sudo -u hadoop sed -i -e '$aexport JAVA_HOME="/usr/lib/jvm/java-8-openjdk-amd64"\' $HADOOP_CONF_DIR/hadoop-env.sh

# create metadata directoriy for DataNodes
sudo -u hadoop mkdir -p $HADOOP_HOME/metadata/DataNode
sudo chown hdfs:hadoop -R $HADOOP_HOME/metadata

# create core-site.xml
sudo -u hadoop rm -f $HADOOP_CONF_DIR/core-site.xml
sudo -u hadoop echo '<configuration>
    <property>
        <name>fs.defaultFS</name>
        <value>hdfs://namenode:9000</value>
    </property>
        <property>
        <name>hadoop.tmp.dir</name>
        <value>/tmp/hadoop-$(user.name)</value>
    </property>
</configuration>' | sudo -u hadoop tee -a $HADOOP_CONF_DIR/core-site.xml

# create hdfs-site.xml
sudo -u hadoop rm -f $HADOOP_CONF_DIR/hdfs-site.xml
sudo -u hadoop echo '<configuration>
    <property>
        <name>dfs.replication</name>
        <value>3</value>
    </property>
        <property>
                <name>dfs.namenode.name.dir</name>
                <value>/apache/hadoop/hadoop-3.1.0/metadata/NameNode</value>
        </property>
        <property>
                <name>dfs.datanode.data.dir</name>
                <value>/apache/hadoop/hadoop-3.1.0/metadata/DataNode</value>
        </property>
</configuration>' | sudo -u hadoop tee -a $HADOOP_CONF_DIR/hdfs-site.xml

# create mapred-site.xml
sudo -u hadoop rm -f $HADOOP_CONF_DIR/mapred-site.xml
sudo -u hadoop echo '<configuration>
    <property>
        <name>mapreduce.framework.name</name>
        <value>yarn</value>
    </property>
    <property>
        <name>mapreduce.admin.user.env</name>
        <value>HADOOP_MAPRED_HOME=$HADOOP_COMMON_HOME</value>
    </property>
    <property>
        <name>yarn.app.mapreduce.am.env</name>
        <value>HADOOP_MAPRED_HOME=$HADOOP_COMMON_HOME</value>
    </property>
</configuration>' | sudo -u hadoop tee -a $HADOOP_CONF_DIR/mapred-site.xml

# yarn-site.xml
sudo -u hadoop rm -f $HADOOP_CONF_DIR/yarn-site.xml
sudo -u hadoop echo '<configuration>
    <property>
        <name>yarn.nodemanager.aux-services</name>
        <value>mapreduce_shuffle</value>
    </property>
    <property>
        <name>yarn.resourcemanager.hostname</name>
        <value>namenode</value>
    </property>
</configuration>' | sudo -u hadoop tee -a $HADOOP_CONF_DIR/yarn-site.xml

## Hadoop daemons
# start datanode
#sudo -u hdfs $HADOOP_HOME/sbin/hadoop-daemon.sh start datanode

## YARN daemons
#sudo -u yarn $HADOOP_HOME/sbin/yarn-daemon.sh start nodemanager
