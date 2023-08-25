# D8X-trader-backend infrastructure

This directory contains infrastructure and deployment automation code for
d8x-trader-backend.

# Provisioning servers with terraform

Before starting, make sure you have the following tools installed on your system:

- [Terraform](https://developer.hashicorp.com/terraform/downloads):
- [Ansible](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html#installing-ansible)

Additional ansible galaxy packages are used and should be installed:

```bash
ansible-galaxy collection install community.docker ansible.posix community.general
```

## Linode

Create Linode API token, you will need to provide it when provisioning servers.

## Dot env and configs

Copy the `.env.example` as `.env` in `deployment` directory

You can edit environment variables in `deployment/.env` file. These environment
vairables will be used when deploying docker stack in swarm.

You should also edit the following configuration files:

```bash
live.referralSettings.json
live.rpc.json
live.wsConfig.json
```

The `deployment` directory will be copied to your manager node. Configs and .env
are used when deploying docker stack in your swarm cluster.

### Spin up infrastructure

**Note!**, you can explore the `vars.tf` file to see available terraform
variables.

Simply run `./run.sh` script which will walk you through provisioning servers on
your linode account via terraform and then configuring them wth ansible to run
a docker swarm.
 
You will need the following details to spin up a cluster:

- Linode API token, which you can get in your linode account settings
- Provisioned database cluster in linode. You can get the ID of database cluster
  from the cluster management url
  (https://cloud.linode.com/databases/postgresql/<ID>) or via `linode-cli`. 


Setting everything up can take about 10 minutes.


# Limitations and caveats

- If default port numbers are changed, make sure to edit `nginx.conf` before
  running `run.sh`.