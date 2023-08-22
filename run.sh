#!/bin/bash

# Some configurable defaults used in the cluster creation process

DEFAULT_KEY_PATH="./id_key_ed25519"

# User name that will be created on each server 
DEFAULT_USER_NAME="d8xtrader"
# Default user password that will be used when setting up DEFAULT_USER_NAME
DEFAULT_USER_PASSWORD="DOIf8e8D)4JT(3q6"
if [ -e /dev/urandom ]; then
    DEFAULT_USER_PASSWORD=$(cat /dev/urandom | tr -dc 'A-Za-z0-9!@#$%^&*()_+{}[]' | head -c16;echo;)    
fi

create_ssh_key() {
    echo "Creating new ssh key pair..."
    ssh-keygen -t ed25519 -f "${DEFAULT_KEY_PATH}" -C "d8x-cluster-user"
}

# Runs ansible setup playbook
run_ansible() {
    # Get the ssh public key that will be put in authorized_keys file for d8xtrader user
    SSH_PUBLIC_KEY=$(cat "${DEFAULT_KEY_PATH}.pub")

    ansible-playbook -i ./hosts.cfg -u root \
    --extra-vars "ansible_ssh_private_key_file=./id_key_ed25519" \
    --extra-vars "ansible_host_key_checking=false" \
    --extra-vars "user_public_key='${SSH_PUBLIC_KEY}'" \
    --extra-vars "default_user_name='${DEFAULT_USER_NAME}'" \
    --extra-vars "default_user_password='${DEFAULT_USER_PASSWORD}'" \
    ./playbooks/setup.ansible.yaml -vvv

    exitCode=$?

    if [ $exitCode -gt 0 ];then
        echo "Ansible exited with errror"
        return
    fi

    echo "Ansible run completed!"
    echo "Default user was created on each server"
    echo "User: ${DEFAULT_USER_NAME}"
    echo "Password: ${DEFAULT_USER_PASSWORD}"

    ssh_manager_message
}


ssh_manager_message() {
    MANAGER_IP=$(cat ./hosts.cfg | grep manager-1 | cut -d" " -f1)

    echo ""
    echo ""
    echo "------------------------------------------------------------"

    echo "SSH Into your manager node by running the following command: "
    echo "ssh ${DEFAULT_USER_NAME}@${MANAGER_IP} -i ${DEFAULT_KEY_PATH}"

    echo "------------------------------------------------------------"
}


# Runs terraform apply
run_terraform() {
    echo "Enter your Linode API token"
    read LINODE_TOKEN
    echo -e "Using LINODE_TOKEN=${LINODE_TOKEN}"
    echo ""
    export LINODE_TOKEN=${LINODE_TOKEN}

    create_ssh_key
    SSH_PUBLIC_KEY=$(cat ./id_key_ed25519.pub)

    echo ""
    echo "Running terraform apply..."

    # Provide ssh key and other available vars
    AUTHORIZED_KEYS_VAL="[\"${SSH_PUBLIC_KEY}\"]"
    terraform apply -var="authorized_keys=${AUTHORIZED_KEYS_VAL}" -auto-approve
}

echo -e "Welcome to D8X trader backend cluster setup. \nThis script will guide you on setting up and starting your d8x-trader-backend cluster on Linode\n"

echo "Choose action to perform:"
echo "1. Full setup, terraform apply + ansible"
echo "2. Run only terraform apply "
echo "3. Run only ansible playbooks"
read -p "Enter the action number [1]: " ACTION

ACTION=${ACTION:-1}

case "$ACTION" in
    # Full setup
    1) 

        run_terraform

        # Wait for a bit before attempting to connect to hosts, SSHD might not be ready
        # immediately after provisioning and ansible connections will fail.
        SLEEP_TIME=60
        while [ $SLEEP_TIME -gt 0 ]
        do
            printf "%-80s\r" ""
            printf "Waiting %d seconds for SSHDs to start in cluster nodes \r" $SLEEP_TIME
            SLEEP_TIME=$(($SLEEP_TIME-1));
            sleep 1
        done
        printf "%-80s\r\n" ""

        # Run ansible playbooks
        echo ""
        echo  "Running ansible playbooks"

        run_ansible
    ;;

    # Terraform only
    2)
        run_terraform
    ;;

    # Ansible only
    3)
        run_ansible
    ;;
esac


