NAME  ?= cat
IMAGE ?= ami-c636acf6
SG    ?= sg-b0c4d2d2
NUMI  ?= 2

LC=$(NAME)-lc
GP=$(NAME)-grp

default:
	@echo "You must specify a target"

new_image: terminate_instances create_temp_lc switch_grp_tmp_lc delete_lc create_lc switch_grp_new_lc delete_temp_lc restart_instances
	@echo 
	@echo Cut and paste the commands above
	@echo

terminate_instances:
	@echo aws autoscaling update-auto-scaling-group --min-size 0 --desired-capacity 0 \
		--auto-scaling-group-name $(GP)

restart_instances:
	@echo aws autoscaling update-auto-scaling-group --min-size $(NUMI) --desired-capacity $(NUMI) \
		--auto-scaling-group-name $(GP)

create_temp_lc:
	@echo aws autoscaling create-launch-configuration     \
		--instance-type m1.medium      \
		--associate-public-ip-address     \
		--security-groups $(SG)     \
		--launch-configuration-name $(LC)tmp \
		--image-id $(IMAGE)

delete_temp_lc:
	@echo aws autoscaling delete-launch-configuration --launch-configuration-name $(LC)tmp

create_lc:
	@echo aws autoscaling create-launch-configuration     \
		--instance-type m1.medium      \
		--associate-public-ip-address     \
		--security-groups $(SG)     \
		--launch-configuration-name $(LC) \
		--image-id $(IMAGE)

delete_lc:
	@echo aws autoscaling delete-launch-configuration --launch-configuration-name $(LC)

switch_grp_tmp_lc:
	@echo aws autoscaling update-auto-scaling-group \
		--auto-scaling-group-name $(GP) \
		--launch-configuration-name $(LC)tmp

switch_grp_new_lc:
	@echo aws autoscaling update-auto-scaling-group \
		--auto-scaling-group-name $(GP) \
		--launch-configuration-name $(LC)

