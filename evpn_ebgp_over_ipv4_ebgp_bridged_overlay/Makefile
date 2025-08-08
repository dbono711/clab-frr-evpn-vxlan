CLAB = clab-frr-evpn-vxlan
LOG_FILE = setup.log

define log
    echo "[$(shell date '+%Y-%m-%d %H:%M:%S')] $1" >> $(LOG_FILE)
endef

.PHONY: initialize_log
initialize_log:
	@echo -n "" > $(LOG_FILE)

.PHONY: lab
lab: initialize_log
	@$(call log,Deploying ContainerLAB topology...)
	@sudo clab deploy --topo lab.yml >> $(LOG_FILE) 2>&1
	@sleep 5
	@$(call log,ContainerLAB topology successfully deployed.)

.PHONY: validate
validate: lab
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
	@sudo clab destroy --cleanup --topo lab.yml >> $(LOG_FILE) 2>&1
	@$(call log,Cleaning complete.)
	@echo "Cleaning complete. Check 'setup.log' for detailed output."
