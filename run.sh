#!/bin/bash
set -o pipefail

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
    ./playbooks/setup.ansible.yaml 

    exitCode=$?

    if [ $exitCode -gt 0 ];then
        echo "Ansible exited with errror"
        return
    fi

    echo "Ansible run completed!"
    echo "Default user was created on each server"
    echo "User: ${DEFAULT_USER_NAME}"
    echo "Password: ${DEFAULT_USER_PASSWORD}"

    # Store password in password file
    echo "${DEFAULT_USER_PASSWORD}" > ./password.txt
    echo "Password saved in ./password.txt"
}

# Retrieve first manager ip address from hosts.cfg
get_manager_ip() {
    cat ./hosts.cfg | grep manager-1 | cut -d" " -f1
}


ssh_manager_message() {
    MANAGER_IP=$(get_manager_ip)

    echo ""
    echo ""
    echo "------------------------------------------------------------"

    echo "SSH Into your manager node by running the following command: "
    echo "ssh ${DEFAULT_USER_NAME}@${MANAGER_IP} -i ${DEFAULT_KEY_PATH}"
    echo "Password: ${DEFAULT_USER_PASSWORD}"

    echo "------------------------------------------------------------"
}


# Runs terraform apply
run_terraform() {
    echo "Enter your Linode API token"
    read LINODE_TOKEN
    echo -e "Using LINODE_TOKEN=${LINODE_TOKEN}"
    echo ""
    export LINODE_TOKEN=${LINODE_TOKEN}

    read -p "Enter your Linode postgres cluster ID: " db_cluster_id
    db_cluster_id=${db_cluster_id:--1}
    
    create_ssh_key
    SSH_PUBLIC_KEY=$(cat ./id_key_ed25519.pub)


    echo ""
    echo "Running terraform apply..."

    # Provide ssh key and other available vars
    AUTHORIZED_KEYS_VAL="[\"${SSH_PUBLIC_KEY}\"]"
    terraform apply -auto-approve \
        -var="authorized_keys=${AUTHORIZED_KEYS_VAL}" \
        -var="linode_db_cluster_id=${db_cluster_id}" 

    # Pull the database certificate
    if [ "$db_cluster_id" -gt 0 ];then
        get_db_ca_key "$LINODE_TOKEN" "$db_cluster_id"
    fi

}

# Pull and create deployment/pg.crt CA certificate  Param 1 is the LINODE_TOKEN,
# param 2 is the Database ID from linode. 
get_db_ca_key() {
    url="https://api.linode.com/v4/databases/postgresql/instances/${2}/ssl"
    echo "Pulling postgresql database $db_cluster_id ca.crt from linode: $url"
    curl -s -X GET \
     -H "Authorization: Bearer ${1}" \
     "$url" 2>/dev/null \
      | python3 -c "import json;import sys; out = json.loads(sys.stdin.read())['ca_certificate']; print(out)" \
      | base64 -d > ./deployment/pg.crt;
}

ssh_manager() {
    ssh "${DEFAULT_USER_NAME}@$(get_manager_ip)" -i "${DEFAULT_KEY_PATH}" "$@"
}

# Copy the deployments dir to manager, create configs and deploy the stack
run_deploy_swarm_cluster() {
    tar czvf - ./deployment | \
        ssh_manager 'tar xzf -'
    password=$(cat ./password.txt)

    ssh_manager "echo '${password}' | sudo -S docker config rm cfg_rpc cfg_referral cfg_wscfg pg_ca 2>&1 > /dev/null"
    ssh_manager "echo '${password}' | sudo -S docker config create cfg_rpc ./deployment/live.rpc.json 2>&1 > /dev/null"
    ssh_manager "echo '${password}' | sudo -S docker config create cfg_referral ./deployment/live.referralSettings.json 2>&1 > /dev/null"
    ssh_manager "echo '${password}' | sudo -S docker config create cfg_wscfg ./deployment/live.wsConfig.json 2>&1 > /dev/null"

    if [ -e "./deployment/pg.crt" ];then
        ssh_manager "echo '${password}' | sudo -S docker config create pg_ca ./deployment/pg.crt 2>&1 > /dev/null"
    fi

    ssh_manager \
"$(cat << EOF
    cd ./deployment && echo '${password}' | sudo -S bash -c ". .env && docker compose -f ./docker-stack.yml config | sed -E 's/published: \"([0-9]+)\"/published: \1/g' | sed -E 's/^name: .*$/ /'|  docker stack deploy -c - stack"
EOF
)"  
  
}

run_collect_domains_cp_nginxconf() {
    echo ""
    echo ""
    echo "------------------------------------------------------------"
    echo "Configuring nginx"
    echo "------------------------------------------------------------"
    echo ""
    
    mngr=$(get_manager_ip)
    echo -e "Before continuing to setup nginx, make sure you update your \nDNS A records to point to your manager ip address (${mngr})\n\n"
    echo -e "Make sure you enter (sub)domains only - without HTTP or HTTPS prefix! \nThese values will be set as server_name directives in nginx.conf\n"  

    # read -p "Main HTTP (sub)domain: " MAIN_API_HTTP
    # read -p "Main Websockets (sub)domain: " MAIN_API_WS
    # read -p "History HTTP (sub)domain: " HISTORY_API_HTTP
    # read -p "Referral HTTP (sub)domain: " REFERRAL_API_HTTP
    # read -p "PXWS HTTP (sub)domain: " PXWS_API_HTTP
    # read -p "PXWS Websockets (sub)domain: " PXWS_API_WS

    # cat ./nginx.conf \
    #     | sed -E "s/%main%/${MAIN_API_HTTP}/"  \
    #     | sed -E "s/%main_ws%/${MAIN_API_WS}/" \
    #     | sed -E "s/%history%/${HISTORY_API_HTTP}/" \
    #     | sed -E "s/%referral%/${REFERRAL_API_HTTP}/" \
    #     | sed -E "s/%pxws%/${PXWS_API_HTTP}/" \
    #     | sed -E "s/%pxws_ws%/${PXWS_API_WS}/" \
    #     | tee ./nginx.configured.conf >/dev/null

    password=$(cat ./password.txt)

    ansible-playbook -i ./hosts.cfg -u "${DEFAULT_USER_NAME}" \
        --extra-vars "ansible_ssh_private_key_file=${DEFAULT_KEY_PATH}" \
        --extra-vars "ansible_host_key_checking=false" \
        --extra-vars "ansible_become_pass=${password}" \
        ./playbooks/nginx.ansible.yaml -v

    if [ $? == 0 ];then 
        echo ""
        echo "-------------------------------------------------------------------"
        echo "Nginx configuring was completed successfully. Do you want to set up"
        echo "HTTP (install SSL certificates from Letsencrypt via certbot)"
        echo "-------------------------------------------------------------------"
        echo ""
        read -p "(y/n) [y]: " setup_certs
        setup_certs=${setup_certs:-"y"}
        if [  "$setup_certs" = "y" ];then
            echo "Running certbot setup for nginx on manager"
            ssh_manager -t "sudo certbot --nginx"
        fi
    fi
}

echo -e "Welcome to D8X trader backend cluster setup. \nThis script will guide you on setting up and starting your d8x-trader-backend cluster on Linode\n"

echo "Choose action to perform:"
echo "1. Full setup, terraform apply + ansible"
echo "2. Run only terraform apply "
echo "3. Run only ansible playbooks"
echo "4. Deploy docker stack (via ssh on manager node)"    
echo "5. Setup nginx and nginx.conf for all services on manager node (requires setting up DNS A records first)"    

if [ -z $1 ];then
    read -p "Enter the action number [1]: " ACTION
else
    ACTION="$1"
fi

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

        run_ansible

        run_deploy_swarm_cluster

        ssh_manager_message

        # Must run last since we might establish ssh with terminal allocation to setup certs
        run_collect_domains_cp_nginxconf
    ;;

    # Terraform only
    2)
        run_terraform
    ;;

    # Ansible only
    3)
        run_ansible
    ;;

    4)
        run_deploy_swarm_cluster
    ;;

    5)
        run_collect_domains_cp_nginxconf
    ;;
esac


