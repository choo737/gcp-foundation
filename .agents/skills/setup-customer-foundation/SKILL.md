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

## Step 1: Check Handoff and Walk Through `QUESTIONNAIRE.md`

Check for gitignored `platform-context.json` in the repo root first if routed from `https://github.com/choo737/gcp-launchpad`.
Walk the customer through [QUESTIONNAIRE.md](../../../QUESTIONNAIRE.md) before writing `custom.auto.tfvars` or `envs/<env>.tfvars`.
Never guess organization IDs, billing accounts, project IDs, or IAM principals.
Confirm these decisions with the customer first:

1. **Path 0 (Optional Bootstrap)**: `foundation/00-bootstrap` for GCS `tfstate`, `iac-outputs`, and GitHub WIF (`ci_repository_map`).
2. **Path 1 (Greenfield End-to-End)**: `foundation/01-org-governance` -> `foundation/02-security-network` -> `data/enterprise/01-platform` -> `data/enterprise/02-governance-ops`.
3. **Path 2 (Brownfield Data Platform)**: `data/enterprise/01-platform` -> `data/enterprise/02-governance-ops` under an existing folder.
4. **Path 3 (Single-Project Sandbox)**: `data/sandbox/` inside one existing GCP project.
5. **Regulatory profile**: `sandbox_poc` (`retention_days = 30`), `enterprise_standard` (`1095`), or `regulated_fsi_rmit` (`2555`, HSM, DR).
6. **SCC tier**: `NONE`, `STANDARD` (free regional BQ export + alerts), or `PREMIUM` (Custom SHA + Security Posture).
7. **VPC-SC and networking**: `subnet_cidr`, `allowed_private_db_cidrs`, Datastream PSC, and `enforce_vpc_sc` (`false` dry-run vs `true` enforced).
8. **FinOps, slots, and RBAC**: Monthly budget, `baseline_slots`/`max_slots`, `foundation_iam_groups`, and `bi_analysts_group`/`data_engineers_group`/`governance_stewards_group`.

Collect the required variables before creating `custom.auto.tfvars` or `envs/<env>.tfvars`:

- **Path 0**: `project_id`, `region`, `prefix`, `project_suffix`, `enable_github_wif`, `github_org`, `github_repositories`, `ci_repository_map`.
- **Path 1 (Core & Governance)**: `parent_id`, `billing_account`, `region`, `dr_region`, `prefix`, `project_suffix`, `environments`, `retention_days`, `lock_audit_bucket`, `enable_audit_project_lien`.
- **Path 1 (Security & Data)**: `scc_tier`, `scc_alert_email_addresses`, `enable_org_policies`, `kms_protection_level`, `enforce_vpc_sc`, `monthly_budget_amount`, `enable_reservations`, `masked_readers`, `bi_analysts`.
- **Path 2**: `data_folder_id`, `billing_account`, `region`, `prefix`, `project_suffix`, `environment`, optional `kms_key_id`, `shared_vpc_host_project_id`, `vpc_id`, `subnet_id`, `enable_reservations`, `masked_readers`, `bi_analysts`.
- **Path 3**: `project_id`, `region`, `prefix`, `masked_readers`.
- Keep `prefix` to 3-6 lowercase alphanumeric chars and set `project_suffix` (`dev01`, `stg01`, `prd01`).
- Offer optional `gcloud` lookup commands (`gcloud organizations list`, `gcloud billing accounts list`) only if asked.
- If `enable_org_policies = true`, collect `allowed_policy_member_domains` and `allowed_contact_domains`.
- Ask for `scc_tier` (`NONE`, `STANDARD` free, or `PREMIUM` paid; Enterprise retired May 2026).
- Keep `scc_location` at `global` unless data residency needs `us`, `eu`, or `sa`; BigQuery stays in `region`.

Ask whether this is a **production** or **ephemeral test** deployment:

- **Production**: `deletion_protection = true`, `project_deletion_policy = "PREVENT"`, `delete_contents_on_destroy = false`.
- **Ephemeral test**: `deletion_protection = false`, `project_deletion_policy = "DELETE"`, `delete_contents_on_destroy = true`.

Map customer inputs to each stage's `custom.auto.tfvars` or `envs/<env>.tfvars`:

- `foundation/00-bootstrap/custom.auto.tfvars`: `project_id`, `region`, `prefix`, `project_suffix`, `enable_github_wif`, `github_org`, `github_repositories`, `ci_repository_map`, `allowed_refs`, `allowed_environments`, `force_destroy`.
- `foundation/01-org-governance/custom.auto.tfvars`: `parent_id`, `billing_account`, `region`, `dr_region`, `prefix`, `project_suffix`, `environments`, `retention_days`, `enable_org_policies`, `allowed_policy_member_domains`, `allowed_contact_domains`, `lock_audit_bucket`, `enable_audit_project_lien`, `foundation_iam_groups`, `enable_billing_budget`, `monthly_budget_amount`, `budget_currency_code`, lifecycle flags.
- `foundation/01-org-governance/custom.auto.tfvars` (SCC): `scc_tier`, `scc_location`, `scc_alert_email_addresses`, `enable_security_posture`, `organization_id`.
- `foundation/02-security-network/envs/<env>.tfvars`: `environment`, `enable_cmek`, `kms_protection_level`, `enable_vpc`, `enable_shared_vpc_host`, `subnet_cidr`, `allowed_private_db_cidrs`, `enable_datastream_psc_attachment`, `enable_psc`, `enable_vpc_sc`, `enforce_vpc_sc`, `enable_alerts`, `project_deletion_policy`.
- `data/enterprise/01-platform/envs/<env>.tfvars`: `environment`, `domain_marts`, `primary_domain`, `enable_dr_datasets`, `enable_reservations`, `baseline_slots`, `max_slots`, `enforce_vpc_sc`, `masked_readers`, `bi_analysts`, `bi_analysts_group`, `data_engineers_group`, `governance_stewards_group`, `break_glass_admins_group`.
- `data/enterprise/02-governance-ops/envs/<env>.tfvars`: `environment`, `medallion_git_url`, `git_token_secret_version`, `enforce_vpc_sc`, `enable_scheduled_workflow`, `enable_quality_scan`, `delete_contents_on_destroy`.
- `data/sandbox/custom.auto.tfvars`: `project_id`, `region`, `prefix`, `git_token_secret_version`, `masked_readers`, `delete_contents_on_destroy`.

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
  --replication-policy="user-managed" \
  --locations="${REGION}" \
  --data-file=-
```

Pass `projects/${TARGET_PROJECT}/secrets/${PREFIX}-git-pat/versions/1` as `git_token_secret_version` in `custom.auto.tfvars`.
In Path 1 Enterprise, set `TARGET_PROJECT` to `<prefix>-<suffix>-data-etl` right after `data/enterprise/01-platform` finishes.
Destroying `data/enterprise/01-platform` removes `<prefix>-<suffix>-data-etl` and that secret automatically.

Write customer inputs only into gitignored `custom.auto.tfvars` or `envs/<env>.tfvars` files.
Never commit customer IDs into tracked files.

## Step 3: Execute Stages, Link Outputs, and Tear Down Safely

Run Path 1 forward per environment (`00_linked.auto.tfvars.json` loads before `custom.auto.tfvars`):

```bash
export TFSTATE_BUCKET="<prefix>-<suffix>-tfstate"
export ENV="dev"

make apply STAGE="foundation/01-org-governance" ENV="shared" TFSTATE_BUCKET="${TFSTATE_BUCKET}"

./scripts/link-stages.sh --env "${ENV}" foundation/01-org-governance foundation/02-security-network
make apply STAGE="foundation/02-security-network" ENV="${ENV}" TFSTATE_BUCKET="${TFSTATE_BUCKET}"

./scripts/link-stages.sh --env "${ENV}" foundation/01-org-governance foundation/02-security-network data/enterprise/01-platform
make apply STAGE="data/enterprise/01-platform" ENV="${ENV}" TFSTATE_BUCKET="${TFSTATE_BUCKET}"

./scripts/link-stages.sh --env "${ENV}" data/enterprise/01-platform data/enterprise/02-governance-ops
make apply STAGE="data/enterprise/02-governance-ops" ENV="${ENV}" TFSTATE_BUCKET="${TFSTATE_BUCKET}"
```

For cross-repo CI/CD handoffs, export non-sensitive outputs to the `iac-outputs` bucket without sharing `.tfstate`:

```bash
./scripts/link-stages.sh --env "${ENV}" --export-gcs "gs://${IAC_OUTPUTS_BUCKET}/${ENV}-platform.json" \
  foundation/02-security-network data/enterprise/01-platform data/enterprise/02-governance-ops
./scripts/link-stages.sh --env "${ENV}" --from-gcs "gs://${IAC_OUTPUTS_BUCKET}/${ENV}-platform.json" \
  /path/to/gcp-data-ingestion/stages/enterprise
```

For teardown, follow [docs/04-multi-env-and-decommission.md](../../../docs/04-multi-env-and-decommission.md):

1. Set `deletion_protection = false`, `project_deletion_policy = "DELETE"`, and `delete_contents_on_destroy = true`.
2. Remove project liens before destroying `foundation/01-org-governance`.
3. Destroy stages in exact reverse order (`02-governance-ops` -> `01-platform` -> `02-security-network` -> `01-org-governance`).

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
   (order_id, customer_id, customer_email, customer_ic_number, store_id, order_status, order_date, gross_amount, discount_amount, tax_amount, net_amount, currency_code, country_code, _ingested_at, _cdc_sequence_num, _op_type, _metadata_deleted)
   VALUES
   ('ord-1001', 'cust-01', 'amina@example.com', '900101145566', 'st-01', 'COMPLETED', CURRENT_DATE(), 120.00, 10.00, 0.00, 110.00, 'MYR', 'MY', CURRENT_TIMESTAMP(), 1, 'INSERT', FALSE),
   ('ord-1002', 'cust-02', 'bala@example.com', '880505107788', 'st-02', 'COMPLETED', CURRENT_DATE(), 85.00, 0.00, 0.00, 85.00, 'MYR', 'MY', CURRENT_TIMESTAMP(), 2, 'INSERT', FALSE);"

bq query --use_legacy_sql=false --project_id="${COMPUTE_OR_SANDBOX_PROJECT}" \
  "INSERT INTO \`${CORE_STORAGE_PROJECT}.${BRONZE_DATASET}.crm_customers_cdc\`
   (customer_id, customer_name, customer_email, customer_ic_number, segment, country_code, _ingested_at, _cdc_sequence_num, _op_type, _metadata_deleted)
   VALUES
   ('cust-01', 'Amina Ali', 'amina@example.com', '900101145566', 'RETAIL', 'MY', CURRENT_TIMESTAMP(), 1, 'INSERT', FALSE),
   ('cust-02', 'Bala Tan', 'bala@example.com', '880505107788', 'VIP', 'MY', CURRENT_TIMESTAMP(), 2, 'INSERT', FALSE);"

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

Trigger and inspect the Dataplex profile and quality scans:

```bash
gcloud dataplex datascans run "${SCAN_ID}" --project="${SCAN_PROJECT}" --location="${REGION}"
gcloud dataplex datascans jobs list --datascan="${SCAN_ID}" --project="${SCAN_PROJECT}" --location="${REGION}"
```

Compile, assert zero `compilationErrors`, invoke Dataform, and poll until `SUCCEEDED`:

```bash
ENV="${ENV:-dev}"
TOKEN=$(gcloud auth print-access-token)
REPO_PATH="projects/${ETL_PROJECT}/locations/${REGION}/repositories/${PREFIX}-medallion"

COMP_JSON=$(curl -fsS -X POST \
  "https://dataform.googleapis.com/v1beta1/${REPO_PATH}/compilationResults" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{\"releaseConfig\": \"${REPO_PATH}/releaseConfigs/${ENV}-main\"}")

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
