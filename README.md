# D8X-trader-backend infrastructure

This directory contains infrastructure code for d8x-trader-backend.

# Provisioning servers with terraform

Before starting, make sure you have the following tools installed on your system:

- [Terraform](https://developer.hashicorp.com/terraform/downloads):
- [Ansible](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html#installing-ansible)

Additional ansible galaxy packages are used and should be installed:

```bash
ansible-galaxy collection install community.docker ansible.posix
```

## Linode

Create Linode API token and set `LINODE_TOKEN` env variable in your current
shell session.

```bash
export LINODE_TOKEN="<YOUR_TOKEN>"
```

**Note!**, you can explore the `vars.tf` file to see available terraform
variables.

### Spin up infrastructure

Simply run `./run.sh` script which will walk you through provisioning servers on
your linode account via terraform and then configuring them wth ansible to run
a docker swarm.
 