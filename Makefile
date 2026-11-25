ifeq ($(wildcard .env),)
$(error Missing .env; create it from .env.example with: cp .env.example .env)
endif

include .env

export PROJECT_ROOT ARTIFACTS_DIR CONFIGS_DIR SSH_PUBLIC_KEY_DIR SSH_PRIVATE_KEY_DIR
export ROUTEROS_VERSION ROUTEROS_VDI_FILENAME ROUTEROS_VDI_PATH ROUTEROS_BOX_NAME ROUTEROS_BOX_FILE
export VBOX_ROOT_GROUP VM_ROUTERS_GROUP VM_TEMPLATES_GROUP VBOXMANAGE_BIN

BASH_DIR := $(PROJECT_ROOT)/infrastructure/bash
BOOTSTRAP_DIR := $(PROJECT_ROOT)/automation/scripts/bootstrap

.PHONY: help deploy-routers delete-routers reset-routers reset_routers ssh-keys routeros-box

help:
	@printf '%s\n' \
	  'Targets:' \
	  '  deploy-routers  Create and configure the router VMs' \
	  '  delete-routers  Delete the router VM group' \
	  '  reset-routers   Delete and redeploy the router VMs' \
	  '  ssh-keys        Generate the project SSH keys' \
	  '  routeros-box    Build the RouterOS Vagrant box'

deploy-routers:
	"$(BASH_DIR)/deploy_routers.sh"

delete-routers:
	"$(BASH_DIR)/del_vbox_group.sh" --routers

reset-routers:
	"$(BASH_DIR)/del_vbox_group.sh" --routers
	"$(BASH_DIR)/deploy_routers.sh"

# Keep the original target name available for existing callers.
reset_routers: reset-routers

ssh-keys:
	"$(BOOTSTRAP_DIR)/create_ssh_keys.sh"

routeros-box:
	"$(BOOTSTRAP_DIR)/create_mikrotik_box.sh"

.PHONY: create_templates deploy_equipment
create_templates:
	"$(BASH_DIR)/create_templates.sh"
deploy_equipment:
	"$(BASH_DIR)/deploy_equipment.sh"

.PHONY: deploy_dhcp
deploy_dhcp:
	terraform -chdir=infrastructure/terraform/proxmox init
	terraform -chdir=infrastructure/terraform/proxmox apply -var-file=terraform.local.tfvars -auto-approve
	python3 automation/scripts/generate_kea_config.py
	cd automation/ansible && ansible-playbook playbooks/configure_dhcp_dns.yml
	cd automation/ansible && ansible-playbook playbooks/configure_dhcp_relay.yml
