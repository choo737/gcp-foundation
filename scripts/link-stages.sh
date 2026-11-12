#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'USAGE'
Usage:
  scripts/link-stages.sh [--env <env>] <source_stage_dir> [<source_stage_dir> ...] <target_stage_dir>
  scripts/link-stages.sh [--env <env>] --export-gcs gs://<bucket>/<stage>.json <source_stage_dir> [<source_stage_dir> ...]
  scripts/link-stages.sh [--env <env>] --from-gcs gs://<bucket>/<stage1>.json [gs://<bucket>/<stage2>.json ...] <target_stage_dir>
USAGE
}

env_name=""
mode="local"
gcs_export_uri=""
positional=()

while [ "$#" -gt 0 ]; do
  case "$1" in
    --env)
      if [ "$#" -lt 2 ]; then
        usage
        exit 1
      fi
      env_name="$2"
      shift 2
      ;;
    --export-gcs)
      if [ "$#" -lt 2 ] || [ "$mode" != "local" ]; then
        usage
        exit 1
      fi
      mode="export-gcs"
      gcs_export_uri="$2"
      shift 2
      ;;
    --from-gcs)
      if [ "$mode" != "local" ]; then
        usage
        exit 1
      fi
      mode="from-gcs"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      positional+=("$1")
      shift
      ;;
  esac
done

if [ "$mode" = "export-gcs" ]; then
  if [ "${#positional[@]}" -lt 1 ]; then
    usage
    exit 1
  fi
  if [[ ! "$gcs_export_uri" =~ ^gs://[^/]+/.+ ]]; then
    echo "Invalid GCS URI: $gcs_export_uri" >&2
    exit 1
  fi
  source_abs_dirs=()
  for src in "${positional[@]}"; do
    if [ ! -d "$src" ]; then
      echo "Source stage directory does not exist: $src" >&2
      exit 1
    fi
    source_abs_dirs+=("$(cd "$src" && pwd)")
  done

  python3 - "$gcs_export_uri" "$env_name" "${source_abs_dirs[@]}" <<'PY'
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

gcs_uri = sys.argv[1]
env_name = sys.argv[2]
source_dirs = [Path(p) for p in sys.argv[3:]]

exported: dict[str, object] = {}
for source_dir in source_dirs:
    raw = subprocess.check_output(
        ["terraform", f"-chdir={source_dir}", "output", "-json"],
        text=True,
    )
    outputs = json.loads(raw)
    for key, payload in outputs.items():
        if not isinstance(payload, dict):
            continue
        if payload.get("sensitive") is True:
            continue
        val = payload.get("value")
        if val is not None:
            exported[key] = val

if env_name:
    exported["environment"] = env_name

fd, tmp_name = tempfile.mkstemp(prefix="iac-outputs-", suffix=".json")
tmp_path = Path(tmp_name)
try:
    os.chmod(tmp_path, 0o600)
    with os.fdopen(fd, "w", encoding="utf-8") as handle:
        handle.write(json.dumps(exported, indent=2, sort_keys=True) + "\n")
    os.chmod(tmp_path, 0o600)
    subprocess.run(
        ["gcloud", "storage", "cp", str(tmp_path), gcs_uri],
        check=True,
    )
finally:
    if tmp_path.exists():
        tmp_path.unlink()

print(f"Exported {len(exported)} non-sensitive output(s) from {len(source_dirs)} stage(s) to {gcs_uri}")
PY
  exit 0
fi

if [ "${#positional[@]}" -lt 2 ]; then
  usage
  exit 1
fi

last_idx=$(( ${#positional[@]} - 1 ))
target_dir="${positional[$last_idx]}"
inputs=("${positional[@]:0:$last_idx}")

if [ ! -d "$target_dir" ] || [ ! -f "$target_dir/variables.tf" ]; then
  echo "Target stage must be a directory containing variables.tf: $target_dir" >&2
  exit 1
fi

if [ "$mode" = "from-gcs" ]; then
  for uri in "${inputs[@]}"; do
    if [[ ! "$uri" =~ ^gs://[^/]+/.+ ]]; then
      echo "Invalid GCS URI: $uri" >&2
      exit 1
    fi
  done
else
  for src in "${inputs[@]}"; do
    if [ ! -d "$src" ]; then
      echo "Source stage directory does not exist: $src" >&2
      exit 1
    fi
  done
fi

target_abs="$(cd "$target_dir" && pwd)"
out_file="$target_abs/00_linked.auto.tfvars.json"

python3 - "$mode" "$target_abs" "$out_file" "$env_name" "${inputs[@]}" <<'PY'
import json
import os
from pathlib import Path
import re
import subprocess
import sys

mode = sys.argv[1]
target_dir = Path(sys.argv[2])
out_file = Path(sys.argv[3])
env_name = sys.argv[4]
sources = sys.argv[5:]

var_re = re.compile(r'^\s*variable\s+"([A-Za-z0-9_]+)"\s*\{', re.MULTILINE)
declared_vars = set(var_re.findall((target_dir / "variables.tf").read_text(encoding="utf-8")))

merged: dict[str, object] = {}

if mode == "from-gcs":
    for gcs_uri in sources:
        raw = subprocess.check_output(
            ["gcloud", "storage", "cat", gcs_uri],
            text=True,
        )
        outputs = json.loads(raw)
        if not isinstance(outputs, dict):
            raise ValueError(f"Expected JSON object in {gcs_uri}")
        for key, val in outputs.items():
            if key not in declared_vars:
                continue
            if val is not None:
                merged[key] = val
else:
    for src in [Path(p) for p in sources]:
        raw = subprocess.check_output(
            ["terraform", f"-chdir={src}", "output", "-json"],
            text=True,
        )
        outputs = json.loads(raw)
        for key, payload in outputs.items():
            if key not in declared_vars or not isinstance(payload, dict):
                continue
            if payload.get("sensitive") is True:
                continue
            val = payload.get("value")
            if val is not None:
                merged[key] = val

if env_name and "environment" in declared_vars:
    merged["environment"] = env_name

tmp_file = out_file.with_name(f".{out_file.name}.{os.getpid()}.tmp")
fd = os.open(tmp_file, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
try:
    with os.fdopen(fd, "w", encoding="utf-8") as handle:
        handle.write(json.dumps(merged, indent=2, sort_keys=True) + "\n")
    os.chmod(tmp_file, 0o600)
    os.replace(tmp_file, out_file)
except Exception:
    if tmp_file.exists():
        tmp_file.unlink()
    raise

print(f"Wrote {len(merged)} linked variable(s) to {out_file}")
PY
