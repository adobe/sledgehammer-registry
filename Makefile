# Find all tools in the tool folder gives a list of make go git etc
TOOLS := $(shell find tools -mindepth 1 -maxdepth 1 -type d | sed -e "s;^tools/;;")

# define the targets available
steps := check clean build verify release

# Dependencies
tgt_dep_check =
tgt_dep_clean = $1.check
tgt_dep_build = $1.clean
tgt_dep_verify = $1.build
tgt_dep_release = $1.verify

# define a generic block to generate some rules on the fly
# Will get the name of the tool and the name of step as an argument
define make-tool-target
.PHONY: $1.$2
$1.$2: $(tgt_dep_$2)
	@./make.sh $2 $1
endef

.PHONY: all
all: prb

.PHONY: prb
prb: $(foreach tool,$(TOOLS),$(addprefix $(tool).,verify))

.PHONY: ci
ci: $(foreach tool,$(TOOLS),$(addprefix $(tool).,release))

# generate targets for all prb steps
$(foreach tool,$(TOOLS),$(foreach step,$(steps),$(eval $(call make-tool-target,$(tool),$(step)))))