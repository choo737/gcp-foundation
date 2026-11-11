#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 2 ]; then
  echo "Usage: $0 <source_stage_dir> [<source_stage_dir> ...] <target_stage_dir>" >&2
  exit 1
fi

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

target_abs="$(cd "$target_dir" && pwd)"
out_file="$target_abs/00_linked.auto.tfvars.json"

python3 - "$target_abs" "$out_file" "${source_dirs[@]}" <<'PY'
import json
import os
from pathlib import Path
import re
import subprocess
import sys

target_dir = Path(sys.argv[1])
out_file = Path(sys.argv[2])
source_dirs = [Path(p) for p in sys.argv[3:]]

var_re = re.compile(r'^\s*variable\s+"([A-Za-z0-9_]+)"\s*\{', re.MULTILINE)
declared_vars = set(var_re.findall((target_dir / "variables.tf").read_text(encoding="utf-8")))

merged: dict[str, object] = {}

for src in source_dirs:
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
