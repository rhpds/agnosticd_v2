VARS=openshift-cluster-417
SANDBOX=587
PLAYBOOK=main.yml
GUID=wk417
OUTPUT_DIR_ROOT=../agnosticd-v2-output
OUTPUT_DIR=$(GUID)
PLAYBOOK_DIR=ansible

# AWS Uses Sandbox creds typically

SECRETS_DIR=../agnosticd-v2-secrets
SECRETS=secrets-sandbox$(SANDBOX)
SECRETS_FILE=$(SECRETS_DIR)/$(SECRETS).yml

VARS_DIR=../agnosticd-v2-vars
VARS_FILE=$(VARS_DIR)/$(VARS).yml

TARGET ?= bastion
ROLE ?= test-empty-role
EXTRA_ARGS=
USER_EXTRA_ARGS=
# Adjust to taste

.SILENT: setup my-env ssh-target

help: ## Show this help - technically unnecessary as `make` alone will do
	@egrep -h '\s##\s' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", ($$2=="" ? "" : $$1 ),  $$2}' 

# Thanks to victoria.dev for the above syntax
# https://victoria.dev/blog/how-to-create-a-self-documenting-makefile/

env: ## Confirm env setup
	@echo "\n\nActivate a virtualenv if required\n"
	@type python3
	@printf "Python3 version is: "
	@python3 --version
	@type ansible
	@ansible --version
	@printf "ENV VARS containing ANSIBLE: "
	@-env | grep ANSIBLE || echo "None"

ansible-navigator-execute: ## Execute ansible-playbook with PLAYBOOK of choice
	mkdir -p $(OUTPUT_DIR_ROOT)/$(OUTPUT_DIR); \
	export ANSIBLE_LOG_PATH=/output_dir_root/$(OUTPUT_DIR)/$(GUID).log; \
	ansible-navigator run $(PLAYBOOK_DIR)/$(PLAYBOOK) \
		--extra-vars ACTION=provision \
		--extra-vars @/vars/$(VARS).yml \
		--extra-vars @/secrets/$(SECRETS).yml \
		--extra-vars @/secrets/secrets.yml \
		--extra-vars guid=$(GUID) \
		--extra-vars output_dir=/output_dir_root/$(OUTPUT_DIR) \
		--mode stdout \
		$(USER_EXTRA_ARGS) $(EXTRA_ARGS)

ansible-navigator-destroy: ## Execute ansible-playbook with PLAYBOOK of choice
	mkdir -p $(OUTPUT_DIR_ROOT)/$(OUTPUT_DIR); \
	export ANSIBLE_LOG_PATH=$(OUTPUT_DIR_ROOT)/$(OUTPUT_DIR)/$(GUID).log; \
	ansible-navigator run $(PLAYBOOK_DIR)/$(PLAYBOOK) \
		--extra-vars ACTION=destroy \
		--extra-vars @/vars/$(VARS).yml \
		--extra-vars @/secrets/$(SECRETS).yml \
		--extra-vars @/secrets/secrets.yml \
		--extra-vars guid=$(GUID) \
		--extra-vars output_dir=$(OUTPUT_DIR) \
		--mode stdout \
		$(USER_EXTRA_ARGS) $(EXTRA_ARGS)

deploy: ## Deploy normally with package updates etc (can be slow)
	$(MAKE) ansible-navigator-execute PLAYBOOK=main.yml 

ansible-playbook-execute: ## Execute ansible-playbook with PLAYBOOK of choice
	mkdir -p $(OUTPUT_DIR); \
	export ANSIBLE_LOG_PATH=$(OUTPUT_DIR)/$(GUID).log; \
		ansible-playbook $(PLAYBOOK_DIR)/$(PLAYBOOK) \
		-e @$(VARS_FILE) \
		-e @$(SECRETS_FILE) \
		-e output_dir=$(OUTPUT_DIR) \
		-e config=$(CONFIG) \
		-e guid=$(GUID) \
		$(USER_EXTRA_ARGS) $(EXTRA_ARGS)

deploy-play: ## Deploy normally with package updates etc (can be slow)
	$(MAKE) ansible-playbook-execute PLAYBOOK=main.yml 

deploy-play-fast: ## Deploy fast without package updates etc
	$(MAKE) ansible-playbook-execute PLAYBOOK=main.yml EXTRA_ARGS="-e update_packages=false"	

role-runner: ## Deploy fast without package updates etc
	$(MAKE) ansible-playbook-execute PLAYBOOK=role_runner.yml EXTRA_ARGS="-e role=$(ROLE)"	

destroy: ## Destroy the config
	$(MAKE) ansible-playbook-execute PLAYBOOK=destroy.yml

# user-data: ## Assumes an existing output_dir, outputs contenst of user-data.yaml
# 	ansible-playbook rhdp.agnostic_utilities.agd_user_info.yml -e output_dir=$(OUTPUT_DIR) 
	
ssh-target: ## ssh to your bastion by default or use `make ssh-target target=hostname` 
	ssh -F $(OUTPUT_DIR)/$(ENV_TYPE)_$(GUID)_ssh_conf $(TARGET)

ssh: ## ssh to your bastion by default or use `make ssh target=hostname` 
	ssh -F $(OUTPUT_DIR)/$(ENV_TYPE)_$(GUID)_ssh_conf $(TARGET)

user-data: ## Output user-data
	cat $(OUTPUT_DIR)/user-data.yaml

user-info: ## Output user-info
	cat $(OUTPUT_DIR)/user-info.yaml

last-status: ## Output last status file
	ls -l $(OUTPUT_DIR)/status.txt

update-status: ## Update status file
	$(MAKE) ansible-playbook-execute PLAYBOOK=lifecycle_entry_point.yml EXTRA_ARGS="-e ACTION=status"

stop: ## Suspend, stop, instances
	$(MAKE) ansible-playbook-execute PLAYBOOK=lifecycle_entry_point.yml EXTRA_ARGS="-e ACTION=stop"

start: ## Start stopped instances
	$(MAKE) ansible-playbook-execute PLAYBOOK=lifecycle_entry_point.yml EXTRA_ARGS="-e ACTION=start"

bounce: ## Bounce the deploy IE stop then start
bounce: stop start

showroom-remove: ## Remove showroom
	ansible-playbook \
		~/.ansible/collections/ansible_collections/rhdp/agnostic_utilities/playbooks/remove_showroom.yml \
		-i $(OUTPUT_DIR)/inventory_post_software.yaml \
		-e @$(OUTPUT_DIR)/user-data.yaml

showroom-install: ## Install showroom
	ANSIBLE_ROLES_PATH=../../roles \
	ansible-playbook \
		~/.ansible/collections/ansible_collections/rhdp/agnostic_utilities/playbooks/agd_role_runner.yml \
		-i $(OUTPUT_DIR)/inventory_post_software.yaml \
		-e @$(OUTPUT_DIR)/user-data.yaml \
		-e role=showroom
	
backup-output: ## Backup the output dir
	cp -r $(OUTPUT_HOME) $(BACKUP_HOME)

restore-output: ## Backup the output dir
	cp -r $(BACKUP_HOME)/output_dir /tmp/

relog: ## Zero out the ANSIBLE_LOG_PATH log file
	rm $(OUTPUT_DIR)/$(ENV_TYPE)_$(GUID).log
