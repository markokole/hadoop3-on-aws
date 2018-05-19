# name of the namenode
NAME="namenode"
KEYPAIR="keypair"
SECURITYGROUP="sg-xxxx"
SUBNET="subnet-xxxx"
SCRIPT="file:///home/ubuntu/hadoop/script_namenode.sh"

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

# add the IP and hostname association to the ~/hadoop/hosts file for copying all hosstnames to /etc/hosts in the cluster
echo "$PRIVATE_IP $NAME" | tee -a ~/hadoop/hosts

# pause for 1 minute for the instance to start running
echo "Instance pending..."
sleep 60
echo "Instance running."

# add hosts to known_hosts automatically
ssh -o StrictHostKeyChecking=no -l ubuntu $NAME

# append public key to the authorized_keys
cat ~/.ssh/id_rsa.pub | ssh -i ~/.ssh/my.key ubuntu@$NAME "cat >> ~/.ssh/authorized_keys"

# add public key
cat ~/.ssh/id_rsa.pub | ssh -i ~/.ssh/my.key ubuntu@$NAME "cat > ~/.ssh/id_rsa.pub"

# add private key and change access level
cat ~/.ssh/id_rsa | ssh -i ~/.ssh/my.key ubuntu@$NAME "cat > ~/.ssh/id_rsa && chmod 600 ~/.ssh/id_rsa"
