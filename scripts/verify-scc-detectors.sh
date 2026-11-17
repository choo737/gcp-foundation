#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: verify-scc-detectors.sh (--org <org_id> | --project <project_id>) [--dry-run]

Verifies active Security Command Center built-in detector services and custom SHA modules.

Options:
  --org <org_id>          Organization ID (numeric or organizations/<id>).
  --project <project_id>  Project ID for project-level PAYG verification.
  --dry-run               Print gcloud commands without executing them.
  -h, --help              Show this help message.
EOF
}

ORG_ID=""
PROJECT_ID=""
DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --org)
      if [[ $# -lt 2 || -z "${2:-}" || "${2:-}" == --* ]]; then
        echo "Error: --org requires a non-empty value." >&2
        exit 2
      fi
      ORG_ID="${2#organizations/}"
      shift 2
      ;;
    --project)
      if [[ $# -lt 2 || -z "${2:-}" || "${2:-}" == --* ]]; then
        echo "Error: --project requires a non-empty value." >&2
        exit 2
      fi
      PROJECT_ID="$2"
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

if [[ -z "$ORG_ID" && -z "$PROJECT_ID" ]]; then
  echo "Error: either --org or --project is required." >&2
  usage >&2
  exit 2
fi

if [[ -n "$ORG_ID" && -n "$PROJECT_ID" ]]; then
  echo "Error: specify only one of --org or --project." >&2
  exit 2
fi

if [[ -n "$ORG_ID" && ! "$ORG_ID" =~ ^[0-9]+$ ]]; then
  echo "Error: invalid --org value: $ORG_ID" >&2
  exit 2
fi

if [[ -n "$PROJECT_ID" && ! "$PROJECT_ID" =~ ^[a-z][a-z0-9-]{4,29}$ ]]; then
  echo "Error: invalid --project value: $PROJECT_ID" >&2
  exit 2
fi

SERVICES=(
  "EVENT_THREAT_DETECTION"
  "CONTAINER_THREAT_DETECTION"
  "VIRTUAL_MACHINE_THREAT_DETECTION"
  "CLOUD_RUN_THREAT_DETECTION"
)

if [[ -n "$ORG_ID" ]]; then
  SCOPE_FLAG="--organization=${ORG_ID}"
else
  SCOPE_FLAG="--project=${PROJECT_ID}"
fi

if [[ "$DRY_RUN" == "true" ]]; then
  for svc in "${SERVICES[@]}"; do
    echo "[DRY-RUN] gcloud scc settings services describe ${svc} ${SCOPE_FLAG} --format=json"
  done
  echo "[DRY-RUN] gcloud scc custom-modules sha list ${SCOPE_FLAG} --format=json"
  exit 0
fi

if ! command -v gcloud >/dev/null 2>&1; then
  echo "Error: gcloud CLI is not installed or not in PATH." >&2
  exit 1
fi

for svc in "${SERVICES[@]}"; do
  echo "==> Checking SCC service: ${svc} (${SCOPE_FLAG})"
  gcloud scc settings services describe "${svc}" "${SCOPE_FLAG}" --format=json
done

echo "==> Listing custom Security Health Analytics modules (${SCOPE_FLAG})"
gcloud scc custom-modules sha list "${SCOPE_FLAG}" --format=json
