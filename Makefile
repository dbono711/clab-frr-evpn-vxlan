CLAB = clab-frr-evpn-vxlan
LOG_FILE = setup.log
CLIENTS = client1 client2
SWITCHES = spine01 spine02 leaf01 leaf02

define log
    echo "[$(shell date '+%Y-%m-%d %H:%M:%S')] $1" >> $(LOG_FILE)
endef

define client_setup
	for CLIENT in $(CLIENTS); do \
		docker cp clients/$$CLIENT.sh $(CLAB)-$$CLIENT:/tmp/; \
		docker exec $(CLAB)-$$CLIENT bash /tmp/$$CLIENT.sh 2>/dev/null; \
	done
endef

define switch_setup
	for SWITCH in $(SWITCHES); do \
		docker cp $$SWITCH/$$SWITCH.sh $(CLAB)-$$SWITCH:/tmp/; \
		docker exec $(CLAB)-$$SWITCH bash /tmp/$$SWITCH.sh 2>/dev/null; \
	done
endef

.PHONY: initialize_log
initialize_log:
	@echo -n "" > $(LOG_FILE)

.PHONY: lab
lab: initialize_log
	@$(call log,Deploying ContainerLAB topology...)
	@sudo clab deploy --topo setup.yml >> $(LOG_FILE) 2>&1
	@sleep 5
	@$(call log,ContainerLAB topology successfully deployed.)

.PHONY: configure
configure: lab
	@$(call log,Starting configuration...)
	@$(call log,Executing shell scripts for device configuration...)
	@$(call client_setup) >> $(LOG_FILE) 2>&1
	@$(call switch_setup) >> $(LOG_FILE) 2>&1

.PHONY: configure-only
configure-only:
	@$(call log,Starting configuration...)
	@$(call log,Executing shell scripts for device configuration...)
	@$(call client_setup) >> $(LOG_FILE) 2>&1
	@$(call switch_setup) >> $(LOG_FILE) 2>&1

.PHONY: validate
validate: configure
	@$(call log,Executing validation testing...)
	@/usr/bin/env python3 validate.py >> $(LOG_FILE) 2>&1
	@echo "Complete. Check 'setup.log' for detailed output."

.PHONY: validate-only
validate-only:
	@$(call log,Executing validation testing...)
	@/usr/bin/env python3 validate.py >> $(LOG_FILE) 2>&1
	@echo "Complete. Check 'setup.log' for detailed output."

all: validate

.PHONY: clean
clean: initialize_log
	@$(call log,Cleaning up...)
	@sudo clab destroy --topo setup.yml >> $(LOG_FILE) 2>&1
	@$(call log,Cleaning complete.)
	@echo "Cleaning complete. Check 'setup.log' for detailed output."
