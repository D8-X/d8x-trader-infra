# D8X-trader-backend infrastructure

This directory contains infrastructure and deployment automation code for
d8x-trader-backend and optionally for d8x-broker-server. This readme acts as a
guide on how to use this repository and its contents to automatically spin up
d8x-trader docker swarm cluster on linode cloud.

**Make sure you read this documentation to properly setup your d8x-trader
backend cluster!**

# Provisioning cluster

Before starting, make sure you have the following tools installed on your
system:

- [Terraform](https://developer.hashicorp.com/terraform/downloads)
- [Ansible](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html#installing-ansible)

Additional ansible galaxy packages are used and should be installed:

```bash
$ ansible-galaxy collection install community.docker ansible.posix community.general
```

Clone this repository and navigate into the project folder:
```
$ git clone https://github.com/D8-X/d8x-trader-infra.git
$ cd d8x-trader-infra
```
Initialize your terraform setup before starting:

```bash
$ terraform init
```

Make sure you have a domain and are able to edit its DNS settings as you will
need this when setting up SSL certificate with certbot.

## Linode

Create Linode API token, you will need to provide it when provisioning servers.
This can be done in your Linode dashboard. Follow this guide on getting your
Linode PAT:
https://www.linode.com/docs/products/tools/api/guides/manage-api-tokens/ 


You will also need to create a database cluster. Since provisioning of database
cluster usually takes ~30 minutes, therefore, it is not included in this
automation script and we recommend to provision it before running this setup.

Follow [this guide](https://www.linode.com/docs/products/databases/managed-databases/guides/create-database/) 
for more info about creating managed postgres database on linode.

When creating your database, make sure you select latest version of postgres and
set the region to be the one which you will set up.

Once you have your postgres cluster, grab your database cluster id from linode's
dashboard. Database id can be found in database's overview page url:
```
https://cloud.linode.com/databases/postgresql/81283 -> db id is 81283
```

# Swarm and broker-server

Swarm deployment deploys `d8x-trader-backend` services:
- Main API
- History API
- Referral API
- Pyth price connector API

Swarm deployment related configuration files reside in `deployment` directory,
these files are copied to manager node when spinning up the services.


Optional broker server deployment deploys `d8x-broker-server` remote broker
service. Directory `depoloyment-broker` contains configs related to broker
server deployment.

## Dot env and configs

Copy the `.env.example` as `.env` in `deployment` directory

You can edit environment variables in `deployment/.env` file. Environment
variables defined in `.env` will be used when deploying docker stack in swarm.

Make sure you edit the required environment variables:
```
CHAIN_ID
SDK_CONFIG_NAME
REDIS_PASSWORD
DATABASE_DSN_HISTORY
DATABASE_DSN_REFERRAL
```

You should also edit the following configuration files:

```bash
live.referralSettings.json
live.rpc.json
live.wsConfig.json
```

Make sure you provide websockets urls for `WS` properties in `live.rpc.json`,
otherwise the services will not work properly.

The `deployment` directory will be copied to your manager node. Configs and .env
are used when deploying docker stack in your swarm cluster.

If you opted in to deploy broker-server, you should make sure `chainConfig.json`
in `deployment-broker` directory is configured as per your needs.

## Spin up infrastructure

You can explore the `vars.tf` file to see available terraform
variables. For example if you want to choose different region where you cluster
is deployed, you would need to edit `region` variable.

To start the cluster creation, simply run `./run.sh` script which will walk you
through provisioning servers on your linode account via terraform and then
configuring them with ansible to run a docker swarm.
 
You will need the following details to spin up a cluster:

- Linode API token, which you can get in your linode account settings
- Provisioned database cluster in linode. You can get the ID of database cluster
  from the cluster management url
  (https://cloud.linode.com/databases/postgresql/<ID>) or via `linode-cli`. 

Note that setting everything up can take about 10 minutes.

After setup is completed the following files will be generated:
- `hosts.cfg` - ansible inventory file with nodes and their public ip addresses
- `id_key_ed25519` - ssh private key which you can use to ssh into your cluster servers.
- `password.txt` - password for `d8xtrader` user created on each cluster server.

During the setup you will be asked to provide domains or subdomains for cluster
services. These domain/subdomain values will be used in nginx configuration as
`server_name` directives. You should also configure your DNS A records to point
to manager node's public IP address as this will be needed when issuing
certificates via certbot to enable HTTPS.

# Teardown

## Completely remove cluster
Perform terraform destroy:

```bash
export LINODE_TOKEN=<YOUR_TOKEN_HERE>
terraform destroy -var='authorized_keys=[""]
```

## Docker stack

In case you want to redeploy the services on existing provisioned servers, you
can simply remove the deployed stack. 

The default deployed docker stack name is: **stack**

You can manage your docker stack from your docker swarm manager. Refer to
`hosts.cfg` file (or linode dashboard) to get the ip address of your manager
node. You can ssh into your manager by using the default `id_key_ed25519` ssh
key that is generated when running `./run.sh` setup.

To remove the stack:
```bash
# SSH to manager
ssh d8xtrader@<MANAGER_IP> -i ./id_key_ed25519
sudo docker stack rm stack
```

Redeploy the stack (from your local machine where you have used `./run.sh`
before):

```bash
# Number 4 is the deploy docker stack action
./run.sh 4
```

# Known issues, limitations and caveats

- If default port numbers are changed, make sure to edit `nginx.conf` before
  running `run.sh`.
- Certbot snap installation will show an error from ansible, even though the
  certbot snap is installed correctly.


# Troubleshooting

Most of the command related to docker swarm must be executed on manager node.

## Inspect services

```bash
docker service ls
```

## Inspect service logs

```bash
docker service logs <SERVICE>
```

## I changed configs or `.env` in `deployment` directory - how do I redeploy changes?

Ssh into your manager node and remove the stack:
```bash
docker stack rm stack
```
Rerun `./run.sh` with `#4` (Deploy docker stack)

## Common issues

**Service loop restarts on error `Error: No Websocket RPC defined for chain ID...`**

Make sure you have set a correct `WS` Websockets RPC url in `live.rpc.json`.



