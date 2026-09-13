# Constants
CLAB = clab-frr-evpn-vxlan
LOG_FILE = setup.log

# Functions
define log
    echo "[$(shell date '+%Y-%m-%d %H:%M:%S')] $1" >> $(LOG_FILE)
endef

define exec_vtysh
	docker exec -it clab-frr-evpn-vxlan-$1 vtysh
endef

define exec_shell
	docker exec -it clab-frr-evpn-vxlan-$1 bash
endef

# ContainerLAB life cycle
.PHONY: initialize-log
initialize-log:
	@echo -n "" > $(LOG_FILE)

.PHONY: lab
lab: initialize-log
	@$(call log,Deploying ContainerLAB topology...)
	@sudo clab deploy --topo lab.yml >> $(LOG_FILE) 2>&1
	@sleep 5
	@$(call log,ContainerLAB topology successfully deployed.)

.PHONY: configure
configure: lab
	@$(call log,Starting configuration...)
	@echo "Configuration complete. Check 'setup.log' for detailed output."

all: configure

.PHONY: clean
clean: initialize-log
	@$(call log,Cleaning up...)
	@sudo clab destroy --cleanup --topo lab.yml >> $(LOG_FILE) 2>&1
	@$(call log,Cleaning complete.)
	@echo "Cleaning complete. Check 'setup.log' for detailed output."

# Interacting with ContainerLAB components
.PHONY: inspect
inspect:
	@sudo clab inspect --topo lab.yml

.PHONY: dc01spine01 dc01spine02 dc01leaf01 dc01leaf02 dc01leaf03 dc01border01 dc01border02 dc01fw01 pe1
dc01spine01 dc01spine02 dc01leaf01 dc01leaf02 dc01leaf03 dc01border01 dc01border02 dc01fw01 pe1:
	$(call exec_vtysh,$(subst -,_,$@))

.PHONY: client1 client2 client3 client4
client1 client2 client3 client4:
	$(call exec_shell,$(subst -,_,$@))
