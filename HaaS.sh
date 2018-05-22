#!/bin/bash

############
# NAMENODE #
############

# name of the namenode
NAME="namenode"
KEYPAIR="keypair"
SECURITYGROUP="sg-xxxx"
SUBNET="subnet-xxxx"
SCRIPT="file:///script_namenode.sh"

# run the aws command to create an instance and run a script when the instance is created.
# the command returns the private IP address which is used to update the local /etc/hosts file
MYVAR=$(aws ec2 run-instances --image-id ami-43a15f3e --count 1 \
            --instance-type t2.micro --key-name ${KEYPAIR} \
            --subnet-id ${SUBNET} --security-group-ids ${SECURITYGROUP} \
            --user-data ${SCRIPT} \
            --associate-public-ip-address \
            --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value='${NAME}'}]' \
            --output text | grep -w 'PRIVATEIPADDRESSES\|INSTANCES')

INSTANCE_ID=$(echo $MYVAR | awk '{print $7}')
PRIVATE_DNS=$(echo $MYVAR | awk '{print $11}')
PRIVATE_IP=$(echo $MYVAR | awk '{print $12}')
PRIVATE_IP_WITH_MASK=$PRIVATE_IP/32

#add instance id to the instances list
echo $INSTANCE_ID | tee ~/hadoop/instances.list

# add the IP and hostname association to the /etc/hosts file
echo "$PRIVATE_IP $NAME" | sudo tee -a /etc/hosts

# add the IP and hostname association to the ~/hadoop/hosts file for copying all hostnames to /etc/hosts in the cluster
#echo "$PRIVATE_IP $NAME" | tee -a ~/hadoop/hosts

# pause for 1 minute for the instance to start running
echo "Installing Hadoop on namenode..."
sleep 60
echo "Namenode is ready."

# add hosts to known_hosts automatically
ssh -o StrictHostKeyChecking=no -l ubuntu $NAME

# append public key to the authorized_keys
cat ~/.ssh/id_rsa.pub | ssh -i ~/.ssh/my.key ubuntu@$NAME "cat >> ~/.ssh/authorized_keys"

# add public key
cat ~/.ssh/id_rsa.pub | ssh -i ~/.ssh/my.key ubuntu@$NAME "cat > ~/.ssh/id_rsa.pub"

# add private key and change access level
cat ~/.ssh/id_rsa | ssh -i ~/.ssh/my.key ubuntu@$NAME "cat > ~/.ssh/id_rsa && chmod 600 ~/.ssh/id_rsa"

#############
# DATANODES #
#############

SCRIPT="file:///script_datanode.sh"
NAME="datanode"

aws ec2 run-instances --image-id ami-43a15f3e --count $1 \
              --instance-type t2.micro --key-name ${KEYPAIR} \
              --subnet-id ${SUBNET} --security-group-ids ${SECURITYGROUP} \
              --user-data ${SCRIPT} \
              --associate-public-ip-address \
              --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value='${NAME}'}]' \
              --output text | grep -w 'PRIVATEIPADDRESSES\|INSTANCES' | awk '{print $7 " " $12}' > ~/hadoop/hosts

COUNTER=1

# pause for 1 minute for the instance to start running
echo "Pending datanode instances..."
sleep 180s
echo "Instances running."

while read line;
do
  if [ "$line" != "" ]; then
    INSTANCE_ID=$(echo $line | awk '{print $1}')
    PRIVATE_IP=$(echo $line | awk '{print $2}')

    #add instance id to the instances list
    echo $INSTANCE_ID | tee -a ~/hadoop/instances.list

    # add the IP and hostname association to the /etc/hosts file
    echo "$PRIVATE_IP $NAME$COUNTER" | sudo tee -a /etc/hosts

    #append the datanode host to temporary workers file.
    echo $NAME$COUNTER | tee -a ~/hadoop/workers

    # add host to known_host automatically
    ssh -o StrictHostKeyChecking=no -l ubuntu $NAME$COUNTER

    # append public key to the authorized_keys
    cat ~/.ssh/id_rsa.pub | ssh -i ~/.ssh/my.key ubuntu@$NAME$COUNTER "cat >> ~/.ssh/authorized_keys"

    # add public key
    cat ~/.ssh/id_rsa.pub | ssh -i ~/.ssh/my.key ubuntu@$NAME$COUNTER "cat > ~/.ssh/id_rsa.pub"

    # add private key and change access level
    cat ~/.ssh/id_rsa | ssh -i ~/.ssh/my.key ubuntu@$NAME$COUNTER "cat > ~/.ssh/id_rsa && chmod 600 ~/.ssh/id_rsa"

    COUNTER=$(expr $COUNTER + 1)
  fi
done<hadoop/hosts

echo "Installing Hadoop on datanodes..."
sleep 120s
echo "Done."

##################
# START SERVICES #
##################

#loop through all instances to copy hosts in the cluster
for i in $(getent hosts | awk '{print $1}')
do
  #if not THIS host
  if [ "$i" != "127.0.0.1" ]; then
    # cat ~/hadoop/hosts
    awk 'NR > 1' /etc/hosts | ssh -i ~/.ssh/my.key ubuntu@$i "sudo tee /etc/hosts"
  fi
done

# copy workers file to the namenode
cat ~/hadoop/workers | ssh -i ~/.ssh/my.key ubuntu@namenode "sudo -u hadoop tee $HADOOP_HOME/etc/hadoop/workers"

# start hadoop services on datanodes
for i in $(getent hosts | awk '{print $2}')
do
  if [[ "$i" = *"datanode"* ]]; then
    sleep 5s
    echo "Starting services on $i"
    ssh -i ~/.ssh/my.key ubuntu@$i "sudo -u hdfs $HADOOP_HOME/sbin/hadoop-daemon.sh start datanode && sudo -u yarn $HADOOP_HOME/sbin/yarn-daemon.sh start nodemanager"
  fi
done

# remove the temp files
rm ~/hadoop/workers
rm ~/hadoop/hosts
