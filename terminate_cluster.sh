#!/bin/bash

awk '{print $1}' /home/ubuntu/hadoop/instances.list | while read line
do
    aws ec2 terminate-instances --instance-ids $line
done
echo "Terminated all worker instances"

#removes any old associations that have "worker" in it
sudo sed -i.bak '/datanode/d' /etc/hosts
echo "Removed all lines from /etc/hosts with worker information"

#removes any old associations that have "worker" in it
sudo sed -i.bak '/namenode/d' /etc/hosts
echo "Removed the line from /etc/hosts with namenode information"

#removes known hosts from the file
sudo sed -i 'd' /home/ubuntu/.ssh/known_hosts
echo "Removed all lines from known_hosts"

#remove the file with instance_ids
rm /home/ubuntu/hadoop/instances.list
echo "Deleted the list file with instance ids"
