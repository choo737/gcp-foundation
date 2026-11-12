#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'USAGE'
Usage:
  scripts/link-stages.sh <source_stage_dir> [<source_stage_dir> ...] <target_stage_dir>
  scripts/link-stages.sh --export-gcs gs://<bucket>/<stage>.json <source_stage_dir>
  scripts/link-stages.sh --from-gcs gs://<bucket>/<stage1>.json [gs://<bucket>/<stage2>.json ...] <target_stage_dir>
USAGE
}

if [ "$#" -lt 2 ]; then
  usage
  exit 1
fi

mode="local"
if [ "$1" = "--export-gcs" ]; then
  mode="export-gcs"
  if [ "$#" -ne 3 ]; then
    usage
    exit 1
  fi
  gcs_uri="$2"
  source_dir="$3"
  if [[ ! "$gcs_uri" =~ ^gs://[^/]+/.+ ]]; then
    echo "Invalid GCS URI: $gcs_uri" >&2
    exit 1
  fi
  if [ ! -d "$source_dir" ]; then
    echo "Source stage directory does not exist: $source_dir" >&2
    exit 1
  fi
elif [ "$1" = "--from-gcs" ]; then
  mode="from-gcs"
  if [ "$#" -lt 3 ]; then
    usage
    exit 1
  fi
  shift
  args=("$@")
  target_dir="${args[$(( ${#args[@]} - 1 ))]}"
  gcs_uris=("${args[@]:0:$(( ${#args[@]} - 1 ))}")
  if [ ! -d "$target_dir" ] || [ ! -f "$target_dir/variables.tf" ]; then
    echo "Target stage must be a directory containing variables.tf: $target_dir" >&2
    exit 1
  fi
  for uri in "${gcs_uris[@]}"; do
    if [[ ! "$uri" =~ ^gs://[^/]+/.+ ]]; then
      echo "Invalid GCS URI: $uri" >&2
      exit 1
    fi
  done
else
  args=("$@")
  target_dir="${args[$(( ${#args[@]} - 1 ))]}"
  source_dirs=("${args[@]:0:$(( ${#args[@]} - 1 ))}")
  if [ ! -d "$target_dir" ] || [ ! -f "$target_dir/variables.tf" ]; then
    echo "Target stage must be a directory containing variables.tf: $target_dir" >&2
    exit 1
  fi
  for src in "${source_dirs[@]}"; do
    if [ ! -d "$src" ]; then
      echo "Source stage directory does not exist: $src" >&2
      exit 1
    fi
  done
fi

if [ "$mode" = "export-gcs" ]; then
  source_abs="$(cd "$source_dir" && pwd)"
  python3 - "$gcs_uri" "$source_abs" <<'PY'
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

gcs_uri = sys.argv[1]
source_dir = Path(sys.argv[2])

raw = subprocess.check_output(
    ["terraform", f"-chdir={source_dir}", "output", "-json"],
    text=True,
)
outputs = json.loads(raw)
exported: dict[str, object] = {}
for key, payload in outputs.items():
    if not isinstance(payload, dict):
        continue
    if payload.get("sensitive") is True:
        continue
    val = payload.get("value")
    if val is not None:
        exported[key] = val

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

print(f"Exported {len(exported)} non-sensitive output(s) to {gcs_uri}")
PY
  exit 0
fi

target_abs="$(cd "$target_dir" && pwd)"
out_file="$target_abs/00_linked.auto.tfvars.json"

if [ "$mode" = "from-gcs" ]; then
  inputs=("${gcs_uris[@]}")
else
  inputs=("${source_dirs[@]}")
fi

python3 - "$mode" "$target_abs" "$out_file" "${inputs[@]}" <<'PY'
import json
import os
from pathlib import Path
import re
import subprocess
import sys

mode = sys.argv[1]
target_dir = Path(sys.argv[2])
out_file = Path(sys.argv[3])
sources = sys.argv[4:]

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
