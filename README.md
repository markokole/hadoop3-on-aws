# Hadoop 3 as a Service on AWS

The general idea is to have a solution that builds an Apache Hadoop 3 cluster from command line.
This can be useful for learning purposes, for testing or for spinning a Hadoop cluster for a certain job and then terminating it, hence minimizing costs.

## Motivation
a couple of years ago I listened to a Spark Summit conference and one company introduced the following architectural solution: data were sitting in S3, when there was the need for analysis, a Hadoop cluster was created, data was pushed to HDFS and analyses were done. After the results were collected, the Hadoop cluster was terminated.

## About
The code has no exception handling, it uses AWS's t2.micro instances to prove the point. There is a lot of potential in building a friendly user interface to parametrize the solution. There is only one input parameter - number of datanodes. When using AWS's free instances, make sure you do not have more than 20 of them running.

There are four files:
- HaaS.sh
- script_namenode.sh
- script_datanode.sh
- terminate_cluster.sh

The HaaS.sh file launches the instances for namenode and datanode(s) (namenode instance is dedicated for namenode related services - no datanode services are installed there). It is advised to start at least one datanode.
Example on how to launch a cluster with 5 datanodes: . Haas.sh 5

When EC2 instance for namenode is ready, script_namenode.sh is executed on that instance.
When EC2 instance(s) for datanode(s) are ready, script_datanode.sh is executed on the instance(s).

## Prerequisities
I have defined one instance as "Initial" instance. This is where the scripts are located and this instance creates and terminates the cluster. This instance is not a part of the Hadoop cluster, it launches the cluster and terminates it.
I am using Ubuntu 16.04 for all my instances. Make sure you have awscli package installed and aws configured on this initial instance.

### Prerequisities on AWS
* key pair
* security group
  * open all traffic for all instances in the same subnet and security group
  * open port 9870 for Namenode Web Interface
  * open port 8088 for Resource Manager (YARN)
  * open port 19888 for MapReduce JobHistory server
* subnet

## Times
Launching a Hadoop cluster with 10 datanodes took less than 10 minutes. When testing, I did also come down to 8 minutes. I am using sleep command in the Haas.sh script in order to wait for the instances to either start running or for Hadoop to download and install (unpack). Room for optimization here as well.

## Order of execution
The HaaS.sh script does the following actions:
* **launch namenode instance** and read output text into a variable
* parse the variable to collect instance id and private ip
* create instances.list and add namenode instance id to it
* append private ip and instance name to /etc/hosts
* enable passwordless ssh to namenode
* **launch datanode(s)**
* update local /etc/hosts
* create workers file
* enable passwordless ssh to datanode(s)
* **start services on datanode(s)**
* copy /etc/hosts from initial instance to all Hadoop instances
* copy workers file to namenode's $HADOOP_HOME/etc/hadoop
* start services on datanode(s)
* remove temporary files
