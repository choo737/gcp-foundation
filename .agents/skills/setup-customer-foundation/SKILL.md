---
name: setup-customer-foundation
description: Interactive customer onboarding workflow covering private repo creation, variable intake, credential checks, stage linking, verification, and teardown.
---

# Setup Customer Foundation

Run these five steps in order whenever deploying this repository for a customer or test run.

## Step 0: Create a Private Customer Repository

GitHub keeps standard `gh repo fork` clones of public repositories public.
Never store customer variables, plans, or links inside a public fork.

Create a private repository first:

```bash
gh repo create <owner>/<customer-repo> --private --template choo737/gcp-foundation --clone
cd <customer-repo>
```

If creating manually, clone upstream, rename `origin` to `upstream`, and push to a private `origin`:

```bash
git clone https://github.com/choo737/gcp-foundation.git <customer-repo>
cd <customer-repo>
gh repo create <owner>/<customer-repo> --private
git remote rename origin upstream
git remote add origin https://github.com/<owner>/<customer-repo>.git
git push -u origin main
```

Verify the repository is private before writing any configs:

```bash
gh repo view --json isPrivate --jq '.isPrivate'
```

Confirm the command prints `true`.

## Step 1: Ask the Customer First

Never guess organization IDs, billing accounts, project IDs, or IAM principals.
Ask the customer to select an adoption path first:

1. **Path 1 (Greenfield End-to-End)**: `foundation/01-org-governance` -> `foundation/02-security-network` -> `data/enterprise/01-platform` -> `data/enterprise/02-governance-ops`.
2. **Path 2 (Brownfield Data Platform)**: `data/enterprise/01-platform` -> `data/enterprise/02-governance-ops` under an existing folder.
3. **Path 3 (Single-Project Sandbox)**: `data/sandbox/` inside one existing GCP project.

Collect the required variables before creating `custom.auto.tfvars`:

- **Path 1**: `parent_id`, `billing_account`, `region`, `prefix`, `project_suffix`, `enable_org_policies`, `allowed_policy_member_domains`, `allowed_contact_domains`, `enable_billing_budget`, `monthly_budget_amount`, `budget_currency_code`, `enable_reservations`, `masked_readers`, `bi_analysts`.
- **Path 2**: `data_folder_id`, `billing_account`, `region`, `prefix`, `project_suffix`, optional `kms_key_id`, `enable_reservations`, `masked_readers`, `bi_analysts`.
- **Path 3**: `project_id`, `region`, `prefix`, `masked_readers`.
- Keep `prefix` to 3-6 lowercase alphanumeric chars and set `project_suffix` (for example `dev01`) to avoid 30-day soft-delete collisions.
- Offer optional `gcloud` lookup commands (`gcloud organizations list`, `gcloud billing accounts list`) only if asked.
- If `enable_org_policies = true`, collect `allowed_policy_member_domains` (Workspace Customer ID via `gcloud organizations list`) and `allowed_contact_domains`.

Ask whether this is a **production** or **ephemeral test** deployment:

- **Production**: `deletion_protection = true`, `project_deletion_policy = "PREVENT"`, `delete_contents_on_destroy = false`.
- **Ephemeral test**: `deletion_protection = false`, `project_deletion_policy = "DELETE"`, `delete_contents_on_destroy = true`.

Map customer inputs to each stage's `custom.auto.tfvars`:

- `foundation/01-org-governance/custom.auto.tfvars`: `parent_id`, `billing_account`, `region`, `prefix`, `project_suffix`, `enable_org_policies`, `allowed_policy_member_domains`, `allowed_contact_domains`, `enable_billing_budget`, `monthly_budget_amount`, `budget_currency_code`, lifecycle flags.
- `foundation/02-security-network/custom.auto.tfvars`: optional `enable_cmek`, `enable_vpc`, `enable_psc`, `enable_vpc_sc`, `enforce_vpc_sc`, `project_deletion_policy`.
- `data/enterprise/01-platform/custom.auto.tfvars`: `domain_marts`, `primary_domain`, `enable_reservations`, `masked_readers`, `bi_analysts` (plus `data_folder_id`, `billing_account`, `prefix`, `project_suffix` for Path 2).
- `data/enterprise/02-governance-ops/custom.auto.tfvars`: `medallion_git_url`, `git_token_secret_version` (optional), `enable_scheduled_workflow`, `delete_contents_on_destroy`.
- `data/sandbox/custom.auto.tfvars`: `project_id`, `region`, `prefix`, `git_token_secret_version` (optional), `masked_readers`, `delete_contents_on_destroy`.

## Step 2: Verify Credentials, Git Secret, and Untracked Vars

Check active authentication before running Terraform:

```bash
gcloud config get-value account
```

If using a named `gcloud` configuration without ADC, export a short-lived token:

```bash
export GOOGLE_OAUTH_ACCESS_TOKEN=$(gcloud auth print-access-token --configuration=<config_name>)
```

Decide how Dataform should run before writing `custom.auto.tfvars`:

- **Standalone mode (default)**: Leave `git_token_secret_version = ""` to deploy a standalone Dataform repository in BigQuery Studio.
- **Git-synced mode**: Set `git_token_secret_version` to a Secret Manager version so Dataform compiles `choo737/gcp-data-medallion`.
- Never place Git tokens in `.tfvars` or Terraform state.

Create a Secret Manager PAT via stdin without touching Terraform state.
Use `printf '%s'` to strip trailing newlines; never pipe `gh auth token` directly:

```bash
gcloud services enable secretmanager.googleapis.com --project="${TARGET_PROJECT}"
printf '%s' "${GITHUB_PAT}" | gcloud secrets create "${PREFIX}-git-pat" \
  --project="${TARGET_PROJECT}" \
  --replication-policy="automatic" \
  --data-file=-
```

Pass `projects/${TARGET_PROJECT}/secrets/${PREFIX}-git-pat/versions/1` as `git_token_secret_version` in `custom.auto.tfvars`.
In Path 1 Enterprise, set `TARGET_PROJECT` to `<prefix>-<suffix>-data-etl` right after `data/enterprise/01-platform` finishes.
Destroying `data/enterprise/01-platform` removes `<prefix>-<suffix>-data-etl` and that secret automatically.

Write customer inputs only into gitignored `custom.auto.tfvars` files.
Never commit customer IDs into tracked files.

## Step 3: Execute Stages, Link Outputs, and Tear Down Safely

Run Path 1 forward in exact order (`00_linked.auto.tfvars.json` loads before `custom.auto.tfvars`):

```bash
terraform -chdir=foundation/01-org-governance init
terraform -chdir=foundation/01-org-governance plan
terraform -chdir=foundation/01-org-governance apply

./scripts/link-stages.sh foundation/01-org-governance foundation/02-security-network
terraform -chdir=foundation/02-security-network init
terraform -chdir=foundation/02-security-network plan
terraform -chdir=foundation/02-security-network apply

./scripts/link-stages.sh foundation/01-org-governance foundation/02-security-network data/enterprise/01-platform
terraform -chdir=data/enterprise/01-platform init
terraform -chdir=data/enterprise/01-platform plan
terraform -chdir=data/enterprise/01-platform apply

./scripts/link-stages.sh data/enterprise/01-platform data/enterprise/02-governance-ops
terraform -chdir=data/enterprise/02-governance-ops init
terraform -chdir=data/enterprise/02-governance-ops plan
terraform -chdir=data/enterprise/02-governance-ops apply
```

For teardown, use a two-step pass when originally deployed with protection flags enabled:

1. Set `deletion_protection = false`, `project_deletion_policy = "DELETE"`, and `delete_contents_on_destroy = true` in `custom.auto.tfvars` and run `terraform apply` on each stage.
2. Run `terraform destroy` in exact reverse order:

```bash
terraform -chdir=data/enterprise/02-governance-ops destroy
terraform -chdir=data/enterprise/01-platform destroy
terraform -chdir=foundation/02-security-network destroy
terraform -chdir=foundation/01-org-governance destroy
```

Increment `project_suffix` (for example `dev01` to `dev02`) before re-running after project deletion.

## Step 4: Run Post-Deploy Verification

If `bq` is missing from default `$PATH`, add the Cloud SDK bin path first:

```bash
command -v bq >/dev/null || export PATH="${HOME}/google-cloud-sdk/bin:${PATH}"
```

Verify FinOps resources from Stage 01:

```bash
bq show --dataset "${AUDIT_PROJECT_ID}:${PREFIX//-/_}_billing_export"
gcloud billing budgets list --billing-account="${BILLING_ACCOUNT}" --billing-project="${AUDIT_PROJECT_ID}"
gcloud pubsub topics describe "${PREFIX}-finops-budget-alerts" --project="${AUDIT_PROJECT_ID}"
```

When `enable_org_policies = true`, list active Org Policy rules on the root folder:

```bash
gcloud resource-manager org-policies list --folder="${ROOT_FOLDER_NUMERIC_ID}"
gcloud org-policies list --folder="${ROOT_FOLDER_NUMERIC_ID}" --billing-project="${AUDIT_PROJECT_ID}"
```

Seed two synthetic rows per table before verifying masking and Dataform:

```bash
bq query --use_legacy_sql=false --project_id="${COMPUTE_OR_SANDBOX_PROJECT}" \
  "INSERT INTO \`${CORE_STORAGE_PROJECT}.${BRONZE_DATASET}.pos_orders_cdc\`
   (order_id, order_date, store_id, customer_id, customer_ic_number, country_code, currency_code, gross_amount, discount_amount, net_amount, status, updated_at)
   VALUES
   ('ord-1001', CURRENT_DATE(), 'st-01', 'cust-01', '900101145566', 'MY', 'MYR', 120.00, 10.00, 110.00, 'COMPLETED', CURRENT_TIMESTAMP()),
   ('ord-1002', CURRENT_DATE(), 'st-02', 'cust-02', '880505107788', 'MY', 'MYR', 85.00, 0.00, 85.00, 'COMPLETED', CURRENT_TIMESTAMP());"

bq query --use_legacy_sql=false --project_id="${COMPUTE_OR_SANDBOX_PROJECT}" \
  "INSERT INTO \`${CORE_STORAGE_PROJECT}.${BRONZE_DATASET}.crm_customers_cdc\`
   (customer_id, customer_name, customer_ic_number, segment, country_code, updated_at)
   VALUES
   ('cust-01', 'Amina Ali', '900101145566', 'RETAIL', 'MY', CURRENT_TIMESTAMP()),
   ('cust-02', 'Bala Tan', '880505107788', 'VIP', 'MY', CURRENT_TIMESTAMP());"

bq query --use_legacy_sql=false --project_id="${COMPUTE_OR_SANDBOX_PROJECT}" \
  "INSERT INTO \`${GOLD_STORAGE_PROJECT}.${GOLD_DATASET}.masked_customers_canary\`
   (customer_id, customer_name, customer_ic_number, country_code, updated_at)
   VALUES
   ('cust-01', 'Amina Ali', '900101145566', 'MY', CURRENT_TIMESTAMP()),
   ('cust-02', 'Bala Tan', '880505107788', 'MY', CURRENT_TIMESTAMP());"
```

Verify BigQuery `LAST_FOUR_CHARACTERS` masking on `masked_customers_canary`:

```bash
bq query --use_legacy_sql=false --project_id="${BI_OR_SANDBOX_PROJECT}" \
  "SELECT customer_id, customer_name, customer_ic_number FROM \`${GOLD_STORAGE_PROJECT}.${GOLD_DATASET}.masked_customers_canary\` ORDER BY customer_id"
```

Trigger and inspect the Dataplex profile scan:

```bash
gcloud dataplex datascans run "${SCAN_ID}" --project="${SCAN_PROJECT}" --location="${REGION}"
gcloud dataplex datascans jobs list --datascan="${SCAN_ID}" --project="${SCAN_PROJECT}" --location="${REGION}"
```

Compile, assert zero `compilationErrors`, invoke Dataform, and poll until `SUCCEEDED`:

```bash
TOKEN=$(gcloud auth print-access-token)
REPO_PATH="projects/${ETL_PROJECT}/locations/${REGION}/repositories/${PREFIX}-medallion"

COMP_JSON=$(curl -fsS -X POST \
  "https://dataform.googleapis.com/v1beta1/${REPO_PATH}/compilationResults" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{\"releaseConfig\": \"${REPO_PATH}/releaseConfigs/prod-main\"}")

COMPILATION_NAME=$(python3 - <<'PY' "${COMP_JSON}"
import json, sys
data = json.loads(sys.argv[1])
errors = data.get("compilationErrors") or []
if errors:
    raise SystemExit(f"Dataform compilationErrors: {errors}")
print(data["name"])
PY
)

INVOCATION_NAME=$(curl -fsS -X POST \
  "https://dataform.googleapis.com/v1beta1/${REPO_PATH}/workflowInvocations" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{\"compilationResult\": \"${COMPILATION_NAME}\", \"invocationConfig\": {\"transitiveDependenciesIncluded\": true, \"fullyRefreshIncrementalTablesEnabled\": false}}" \
  | python3 -c "import json,sys; print(json.load(sys.stdin)['name'])")

while true; do
  STATE=$(curl -fsS -H "Authorization: Bearer ${TOKEN}" \
    "https://dataform.googleapis.com/v1beta1/${INVOCATION_NAME}" \
    | python3 -c "import json,sys; print(json.load(sys.stdin)['state'])")
  echo "Dataform state: ${STATE}"
  case "${STATE}" in
    SUCCEEDED) break ;;
    FAILED|CANCELLED) echo "Dataform run failed: ${STATE}" >&2; exit 1 ;;
    *) sleep 5 ;;
  esac
done
```
