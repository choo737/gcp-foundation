ROOTS := \
	foundation/00-bootstrap \
	foundation/01-org-governance \
	foundation/02-security-network \
	data/sandbox \
	data/enterprise/01-platform \
	data/enterprise/02-governance-ops

ENV ?= dev
TFSTATE_BUCKET ?=
STAGE ?= foundation/01-org-governance
VAR_FILE ?=

export ENV TFSTATE_BUCKET STAGE VAR_FILE

.PHONY: fmt fmt-check validate test clean init plan apply

fmt:
	terraform fmt -recursive

fmt-check:
	terraform fmt -check -recursive

validate:
	@for dir in $(ROOTS); do \
		echo "==> Validating $$dir"; \
		terraform -chdir="$$dir" init -backend=false -input=false >/dev/null; \
		terraform -chdir="$$dir" validate; \
	done

init:
	@case "$$STAGE" in \
		foundation/00-bootstrap|foundation/01-org-governance|foundation/02-security-network|data/sandbox|data/enterprise/01-platform|data/enterprise/02-governance-ops) ;; \
		*) echo "Invalid STAGE: $$STAGE" >&2; exit 1 ;; \
	esac; \
	case "$$ENV" in \
		dev|staging|prod|shared|global) ;; \
		*) echo "Invalid ENV: $$ENV" >&2; exit 1 ;; \
	esac; \
	if [ -n "$$TFSTATE_BUCKET" ]; then \
		terraform -chdir="$$STAGE" init -reconfigure -input=false \
			-backend-config="bucket=$$TFSTATE_BUCKET" \
			-backend-config="prefix=$$STAGE/$$ENV"; \
	else \
		terraform -chdir="$$STAGE" init -backend=false -input=false; \
	fi

plan: init
	@if [ -n "$$VAR_FILE" ]; then \
		terraform -chdir="$$STAGE" plan -input=false -var-file="$$VAR_FILE"; \
	elif [ -f "$$STAGE/envs/$$ENV.tfvars" ]; then \
		terraform -chdir="$$STAGE" plan -input=false -var-file="envs/$$ENV.tfvars"; \
	else \
		terraform -chdir="$$STAGE" plan -input=false; \
	fi

apply: init
	@if [ -n "$$VAR_FILE" ]; then \
		terraform -chdir="$$STAGE" apply -input=false -var-file="$$VAR_FILE"; \
	elif [ -f "$$STAGE/envs/$$ENV.tfvars" ]; then \
		terraform -chdir="$$STAGE" apply -input=false -var-file="envs/$$ENV.tfvars"; \
	else \
		terraform -chdir="$$STAGE" apply -input=false; \
	fi

test:
	python3 -m unittest discover -s tests -v

clean:
	find . \( -name ".terraform" -o -name "__pycache__" -o -name ".pytest_cache" \) -type d -prune -exec rm -rf {} +
	find . \( -name "00_linked.auto.tfvars.json" -o -name "linked.auto.tfvars.json" \) -type f -delete
