#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: configure-bq-dr-replica.sh --project <project_id> --dataset <dataset_id> --replica-location <region> [--dry-run]

Creates a BigQuery dataset replica in a secondary DR region using SQL DDL.

Options:
  --project <project_id>       GCP project ID owning the BigQuery dataset.
  --dataset <dataset_id>       BigQuery dataset ID to replicate.
  --replica-location <region>  Target DR region (for example asia-southeast2).
  --dry-run                    Print the DDL statement and bq command without executing.
  -h, --help                   Show this help message.
EOF
}

PROJECT_ID=""
DATASET_ID=""
REPLICA_LOCATION=""
DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project)
      if [[ $# -lt 2 || -z "${2:-}" || "${2:-}" == --* ]]; then
        echo "Error: --project requires a non-empty value." >&2
        exit 2
      fi
      PROJECT_ID="$2"
      shift 2
      ;;
    --dataset)
      if [[ $# -lt 2 || -z "${2:-}" || "${2:-}" == --* ]]; then
        echo "Error: --dataset requires a non-empty value." >&2
        exit 2
      fi
      DATASET_ID="$2"
      shift 2
      ;;
    --replica-location)
      if [[ $# -lt 2 || -z "${2:-}" || "${2:-}" == --* ]]; then
        echo "Error: --replica-location requires a non-empty value." >&2
        exit 2
      fi
      REPLICA_LOCATION="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Error: unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ -z "$PROJECT_ID" || -z "$DATASET_ID" || -z "$REPLICA_LOCATION" ]]; then
  echo "Error: --project, --dataset, and --replica-location are required." >&2
  usage >&2
  exit 2
fi

if [[ ! "$PROJECT_ID" =~ ^[a-z][a-z0-9-]{4,28}[a-z0-9]$ ]]; then
  echo "Error: invalid --project value: $PROJECT_ID" >&2
  exit 2
fi

if [[ ! "$DATASET_ID" =~ ^[A-Za-z0-9_]+$ ]]; then
  echo "Error: invalid --dataset value: $DATASET_ID" >&2
  exit 2
fi

if [[ ! "$REPLICA_LOCATION" =~ ^(us|eu|US|EU|[a-z]{2,}(-[a-z0-9]+)+)$ ]]; then
  echo "Error: invalid --replica-location value: $REPLICA_LOCATION" >&2
  exit 2
fi

SQL="ALTER SCHEMA \`${PROJECT_ID}.${DATASET_ID}\` ADD REPLICA \`${REPLICA_LOCATION}\` OPTIONS(location='${REPLICA_LOCATION}')"

if [[ "$DRY_RUN" == "true" ]]; then
  echo "[DRY-RUN] SQL: $SQL"
  echo "[DRY-RUN] CMD: bq query --use_legacy_sql=false --project_id=${PROJECT_ID} \"$SQL\""
  exit 0
fi

if ! command -v bq >/dev/null 2>&1; then
  echo "Error: bq CLI is not installed or not in PATH." >&2
  exit 1
fi

bq query --use_legacy_sql=false --project_id="${PROJECT_ID}" "${SQL}"
