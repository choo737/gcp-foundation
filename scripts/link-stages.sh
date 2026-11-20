#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'USAGE'
Usage:
  scripts/link-stages.sh [--env <env>] [--tfstate-bucket <bucket>] <source_stage_dir> [<source_stage_dir> ...] <target_stage_dir>
  scripts/link-stages.sh [--env <env>] [--tfstate-bucket <bucket>] --export-gcs gs://<bucket>/<stage>.json <source_stage_dir> [<source_stage_dir> ...]
  scripts/link-stages.sh [--env <env>] --from-gcs gs://<bucket>/<stage1>.json [gs://<bucket>/<stage2>.json ...] <target_stage_dir>
  scripts/link-stages.sh [--env <env>] --export-gcs gs://<bucket>/<merged>.json --from-gcs gs://<bucket>/<stage1>.json [gs://<bucket>/<stage2>.json ...]
USAGE
}

die_usage() {
  printf 'ERROR: %s\n' "$1" >&2
  exit 2
}

require_flag_value() {
  local flag="$1"
  local remaining="$2"
  local value="${3:-}"
  if [ "$remaining" -lt 2 ] || [ -z "$value" ] || [[ "$value" == -* ]]; then
    die_usage "Missing or empty value for ${flag}"
  fi
}

BUCKET_RE='^[a-z0-9][a-z0-9._-]{1,61}[a-z0-9]$'
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

env_name=""
tfstate_bucket="${TFSTATE_BUCKET:-${GCP_TFSTATE_BUCKET:-${TF_STATE_BUCKET:-}}}"
tfstate_bucket_explicit=false
export_gcs=false
from_gcs=false
gcs_export_uri=""
positional=()

while [ "$#" -gt 0 ]; do
  case "$1" in
    --env)
      require_flag_value "$1" "$#" "${2:-}"
      env_name="$2"
      shift 2
      ;;
    --env=*)
      env_name="${1#--env=}"
      if [ -z "$env_name" ] || [[ "$env_name" == -* ]]; then
        die_usage "Missing or empty value for --env"
      fi
      shift
      ;;
    --tfstate-bucket)
      require_flag_value "$1" "$#" "${2:-}"
      tfstate_bucket="$2"
      tfstate_bucket_explicit=true
      shift 2
      ;;
    --tfstate-bucket=*)
      tfstate_bucket="${1#--tfstate-bucket=}"
      tfstate_bucket_explicit=true
      if [ -z "$tfstate_bucket" ] || [[ "$tfstate_bucket" == -* ]]; then
        die_usage "Missing or empty value for --tfstate-bucket"
      fi
      shift
      ;;
    --export-gcs)
      if [ "$#" -lt 2 ] || [ "$export_gcs" = true ] || [ -z "${2:-}" ] || [[ "${2:-}" == -* ]]; then
        usage
        exit 1
      fi
      export_gcs=true
      gcs_export_uri="$2"
      shift 2
      ;;
    --export-gcs=*)
      if [ "$export_gcs" = true ]; then
        usage
        exit 1
      fi
      export_gcs=true
      gcs_export_uri="${1#--export-gcs=}"
      if [ -z "$gcs_export_uri" ] || [[ "$gcs_export_uri" == -* ]]; then
        die_usage "Missing or empty value for --export-gcs"
      fi
      shift
      ;;
    --from-gcs)
      if [ "$from_gcs" = true ]; then
        usage
        exit 1
      fi
      from_gcs=true
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

if [ -n "$env_name" ]; then
  if [[ ! "$env_name" =~ ^(shared|dev|uat|staging|prod)$ ]]; then
    echo "Invalid --env value: $env_name" >&2
    exit 1
  fi
fi

if [ -n "$tfstate_bucket" ]; then
  if [[ ! "$tfstate_bucket" =~ $BUCKET_RE ]]; then
    die_usage "Invalid --tfstate-bucket value: ${tfstate_bucket}"
  fi
elif [ "$tfstate_bucket_explicit" = true ]; then
  die_usage "Missing or empty value for --tfstate-bucket"
fi

if [ "$export_gcs" = true ] && [ "$from_gcs" = true ]; then
  if [ "${#positional[@]}" -lt 1 ]; then
    usage
    exit 1
  fi
  if [[ ! "$gcs_export_uri" =~ ^gs://[^/]+(/.*)?$ ]]; then
    echo "Invalid GCS URI: $gcs_export_uri" >&2
    exit 1
  fi
  for uri in "${positional[@]}"; do
    if [[ ! "$uri" =~ ^gs://[^/]+(/.*)?$ ]]; then
      echo "Invalid GCS URI: $uri" >&2
      exit 1
    fi
  done

  python3 - "$gcs_export_uri" "$env_name" "${positional[@]}" <<'PY'
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile

raw_dest_uri = sys.argv[1]
env_name = sys.argv[2]
raw_sources = sys.argv[3:]


def resolve_env_gcs_uri(uri: str, env: str) -> str:
    if not env:
        return uri
    rest = uri[len("gs://"):]
    if "/" not in rest:
        return f"gs://{rest}/{env}/foundation-outputs.json"
    bucket, obj = rest.split("/", 1)
    obj = obj.lstrip("/")
    if not obj:
        return f"gs://{bucket}/{env}/foundation-outputs.json"
    if obj == "shared" or obj.startswith("shared/"):
        return uri
    parts = obj.split("/")
    filename = parts[-1]
    if env in parts[:-1]:
        return uri
    if filename and (
        f"-{env}." in filename
        or filename.startswith(f"{env}-")
        or filename == f"{env}.json"
    ):
        return uri
    if obj.endswith("/"):
        return f"gs://{bucket}/{obj}{env}/foundation-outputs.json"
    parent = "/".join(parts[:-1])
    if parent:
        return f"gs://{bucket}/{parent}/{env}/{filename}"
    return f"gs://{bucket}/{env}/{filename}"


dest_uri = resolve_env_gcs_uri(raw_dest_uri, env_name)
if not re.match(r"^gs://[^/]+/.+", dest_uri):
    raise SystemExit(f"Invalid GCS URI (missing object path): {dest_uri}")

merged: dict[str, object] = {}
for raw_src_uri in raw_sources:
    src_uri = resolve_env_gcs_uri(raw_src_uri, env_name)
    if not re.match(r"^gs://[^/]+/.+", src_uri):
        raise SystemExit(f"Invalid GCS URI (missing object path): {src_uri}")
    raw = subprocess.check_output(
        ["gcloud", "storage", "cat", src_uri],
        text=True,
    )
    outputs = json.loads(raw)
    if not isinstance(outputs, dict):
        raise ValueError(f"Expected JSON object in {src_uri}")
    for key, payload in outputs.items():
        if isinstance(payload, dict) and "value" in payload and "sensitive" in payload:
            if payload.get("sensitive") is True:
                continue
            val = payload.get("value")
        else:
            val = payload
        if val is not None:
            merged[key] = val

if env_name:
    merged["environment"] = env_name

fd, tmp_name = tempfile.mkstemp(prefix="iac-outputs-", suffix=".json")
tmp_path = Path(tmp_name)
try:
    os.chmod(tmp_path, 0o600)
    with os.fdopen(fd, "w", encoding="utf-8") as handle:
        handle.write(json.dumps(merged, indent=2, sort_keys=True) + "\n")
    os.chmod(tmp_path, 0o600)
    subprocess.run(
        ["gcloud", "storage", "cp", str(tmp_path), dest_uri],
        check=True,
    )
finally:
    if tmp_path.exists():
        tmp_path.unlink()

print(f"Merged {len(merged)} output(s) from {len(raw_sources)} GCS object(s) to {dest_uri}")
PY
  exit 0
fi

mode="local"
if [ "$export_gcs" = true ]; then
  mode="export-gcs"
elif [ "$from_gcs" = true ]; then
  mode="from-gcs"
fi

if [ "$mode" = "export-gcs" ]; then
  if [ "${#positional[@]}" -lt 1 ]; then
    usage
    exit 1
  fi
  if [[ ! "$gcs_export_uri" =~ ^gs://[^/]+(/.*)?$ ]]; then
    echo "Invalid GCS URI: $gcs_export_uri" >&2
    exit 1
  fi
  source_abs_dirs=()
  for src in "${positional[@]}"; do
    if [ ! -d "$src" ]; then
      echo "Source stage directory does not exist: $src" >&2
      exit 1
    fi
    source_abs_dirs+=("${src}")
  done

  python3 - "$gcs_export_uri" "$env_name" "$tfstate_bucket" "$REPO_ROOT" "${source_abs_dirs[@]}" <<'PY'
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile

raw_gcs_uri = sys.argv[1]
env_name = sys.argv[2]
tfstate_bucket = sys.argv[3]
repo_root = Path(sys.argv[4]).resolve()
raw_sources = sys.argv[5:]


def resolve_env_gcs_uri(uri: str, env: str) -> str:
    if not env:
        return uri
    rest = uri[len("gs://"):]
    if "/" not in rest:
        return f"gs://{rest}/{env}/foundation-outputs.json"
    bucket, obj = rest.split("/", 1)
    obj = obj.lstrip("/")
    if not obj:
        return f"gs://{bucket}/{env}/foundation-outputs.json"
    if obj == "shared" or obj.startswith("shared/"):
        return uri
    parts = obj.split("/")
    filename = parts[-1]
    if env in parts[:-1]:
        return uri
    if filename and (
        f"-{env}." in filename
        or filename.startswith(f"{env}-")
        or filename == f"{env}.json"
    ):
        return uri
    if obj.endswith("/"):
        return f"gs://{bucket}/{obj}{env}/foundation-outputs.json"
    parent = "/".join(parts[:-1])
    if parent:
        return f"gs://{bucket}/{parent}/{env}/{filename}"
    return f"gs://{bucket}/{env}/{filename}"


def find_repo_root(stage_abs: Path) -> Path | None:
    for candidate in (stage_abs, *stage_abs.parents):
        if candidate == candidate.parent:
            break
        if (candidate / ".git").exists():
            return candidate
    for candidate in stage_abs.parents:
        if candidate == candidate.parent:
            break
        if candidate.name in ("stages", "foundation", "data", "apps"):
            return candidate.parent
    return None


def resolve_backend_prefix(raw_src: str, src_abs: Path, env: str) -> str:
    resolved_src = src_abs.resolve()
    try:
        rel_stage = resolved_src.relative_to(repo_root).as_posix()
    except ValueError:
        ext_root = find_repo_root(resolved_src)
        if ext_root is not None:
            rel_stage = resolved_src.relative_to(ext_root).as_posix()
        else:
            rel_stage = resolved_src.name
    effective_env = "shared" if rel_stage == "foundation/01-org-governance" else env
    return f"{rel_stage}/{effective_env}"


def stage_uses_gcs_backend(stage_abs: Path) -> bool:
    if (stage_abs / "envs").is_dir():
        return True
    versions_tf = stage_abs / "versions.tf"
    return versions_tf.is_file() and 'backend "gcs"' in versions_tf.read_text(encoding="utf-8")


def read_stage_outputs(raw_src: str, env: str, state_bucket: str) -> dict[str, object]:
    src_abs = Path(raw_src).resolve()
    if env and state_bucket and stage_uses_gcs_backend(src_abs):
        backend_prefix = resolve_backend_prefix(raw_src, src_abs, env)
        subprocess.run(
            [
                "terraform",
                f"-chdir={src_abs}",
                "init",
                "-reconfigure",
                "-input=false",
                f"-backend-config=bucket={state_bucket}",
                f"-backend-config=prefix={backend_prefix}",
            ],
            check=True,
            stdout=subprocess.DEVNULL,
        )

    raw = subprocess.check_output(
        ["terraform", f"-chdir={src_abs}", "output", "-json"],
        text=True,
    )
    outputs = json.loads(raw)
    if env and isinstance(outputs.get("environment"), dict):
        actual_env = outputs["environment"].get("value")
        if isinstance(actual_env, str) and actual_env.strip() and actual_env.strip() != env:
            print(
                f"ERROR: Stage {raw_src} Terraform state has environment='{actual_env.strip()}', expected '{env}'. "
                f"Re-init the stage for '{env}' or pass --tfstate-bucket.",
                file=sys.stderr,
            )
            raise SystemExit(1)
    return outputs


gcs_uri = resolve_env_gcs_uri(raw_gcs_uri, env_name)
if not re.match(r"^gs://[^/]+/.+", gcs_uri):
    raise SystemExit(f"Invalid GCS URI (missing object path): {gcs_uri}")

exported: dict[str, object] = {}
for raw_src in raw_sources:
    outputs = read_stage_outputs(raw_src, env_name, tfstate_bucket)
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

print(f"Exported {len(exported)} non-sensitive output(s) from {len(raw_sources)} stage(s) to {gcs_uri}")
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
    if [[ ! "$uri" =~ ^gs://[^/]+(/.*)?$ ]]; then
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

python3 - "$mode" "$target_abs" "$out_file" "$env_name" "$tfstate_bucket" "$REPO_ROOT" "${inputs[@]}" <<'PY'
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
tfstate_bucket = sys.argv[5]
repo_root = Path(sys.argv[6]).resolve()
sources = sys.argv[7:]


def resolve_env_gcs_uri(uri: str, env: str) -> str:
    if not env:
        return uri
    rest = uri[len("gs://"):]
    if "/" not in rest:
        return f"gs://{rest}/{env}/foundation-outputs.json"
    bucket, obj = rest.split("/", 1)
    obj = obj.lstrip("/")
    if not obj:
        return f"gs://{bucket}/{env}/foundation-outputs.json"
    if obj == "shared" or obj.startswith("shared/"):
        return uri
    parts = obj.split("/")
    filename = parts[-1]
    if env in parts[:-1]:
        return uri
    if filename and (
        f"-{env}." in filename
        or filename.startswith(f"{env}-")
        or filename == f"{env}.json"
    ):
        return uri
    if obj.endswith("/"):
        return f"gs://{bucket}/{obj}{env}/foundation-outputs.json"
    parent = "/".join(parts[:-1])
    if parent:
        return f"gs://{bucket}/{parent}/{env}/{filename}"
    return f"gs://{bucket}/{env}/{filename}"


def find_repo_root(stage_abs: Path) -> Path | None:
    for candidate in (stage_abs, *stage_abs.parents):
        if candidate == candidate.parent:
            break
        if (candidate / ".git").exists():
            return candidate
    for candidate in stage_abs.parents:
        if candidate == candidate.parent:
            break
        if candidate.name in ("stages", "foundation", "data", "apps"):
            return candidate.parent
    return None


def resolve_backend_prefix(raw_src: str, src_abs: Path, env: str) -> str:
    resolved_src = src_abs.resolve()
    try:
        rel_stage = resolved_src.relative_to(repo_root).as_posix()
    except ValueError:
        ext_root = find_repo_root(resolved_src)
        if ext_root is not None:
            rel_stage = resolved_src.relative_to(ext_root).as_posix()
        else:
            rel_stage = resolved_src.name
    effective_env = "shared" if rel_stage == "foundation/01-org-governance" else env
    return f"{rel_stage}/{effective_env}"


def stage_uses_gcs_backend(stage_abs: Path) -> bool:
    if (stage_abs / "envs").is_dir():
        return True
    versions_tf = stage_abs / "versions.tf"
    return versions_tf.is_file() and 'backend "gcs"' in versions_tf.read_text(encoding="utf-8")


var_re = re.compile(r'^\s*variable\s+"([A-Za-z0-9_]+)"\s*\{', re.MULTILINE)
declared_vars = set(var_re.findall((target_dir / "variables.tf").read_text(encoding="utf-8")))

merged: dict[str, object] = {}
all_source_outputs: dict[str, object] = {}

if mode == "from-gcs":
    for raw_uri in sources:
        gcs_uri = resolve_env_gcs_uri(raw_uri, env_name)
        if not re.match(r"^gs://[^/]+/.+", gcs_uri):
            raise SystemExit(f"Invalid GCS URI (missing object path): {gcs_uri}")
        raw = subprocess.check_output(
            ["gcloud", "storage", "cat", gcs_uri],
            text=True,
        )
        outputs = json.loads(raw)
        if not isinstance(outputs, dict):
            raise ValueError(f"Expected JSON object in {gcs_uri}")
        for key, val in outputs.items():
            if val is not None:
                all_source_outputs[key] = val
            if key not in declared_vars:
                continue
            if val is not None:
                merged[key] = val
else:
    for raw_src in sources:
        src_abs = Path(raw_src).resolve()
        if env_name and tfstate_bucket and stage_uses_gcs_backend(src_abs):
            backend_prefix = resolve_backend_prefix(raw_src, src_abs, env_name)
            subprocess.run(
                [
                    "terraform",
                    f"-chdir={src_abs}",
                    "init",
                    "-reconfigure",
                    "-input=false",
                    f"-backend-config=bucket={tfstate_bucket}",
                    f"-backend-config=prefix={backend_prefix}",
                ],
                check=True,
                stdout=subprocess.DEVNULL,
            )

        raw = subprocess.check_output(
            ["terraform", f"-chdir={src_abs}", "output", "-json"],
            text=True,
        )
        outputs = json.loads(raw)
        if env_name and isinstance(outputs.get("environment"), dict):
            actual_env = outputs["environment"].get("value")
            if isinstance(actual_env, str) and actual_env.strip() and actual_env.strip() != env_name:
                print(
                    f"ERROR: Stage {raw_src} Terraform state has environment='{actual_env.strip()}', expected '{env_name}'. "
                    f"Re-init the stage for '{env_name}' or pass --tfstate-bucket.",
                    file=sys.stderr,
                )
                raise SystemExit(1)
        for key, payload in outputs.items():
            if not isinstance(payload, dict):
                continue
            if payload.get("sensitive") is True:
                continue
            val = payload.get("value")
            if val is not None:
                all_source_outputs[key] = val
            if key not in declared_vars:
                continue
            if val is not None:
                merged[key] = val

target_posix = target_dir.as_posix()
if "subnet_id" in declared_vars:
    if target_posix.endswith("/apps/enterprise") and all_source_outputs.get("app_subnet_id"):
        merged["subnet_id"] = all_source_outputs["app_subnet_id"]
    elif target_posix.endswith("/03-data-science") and all_source_outputs.get("ai_subnet_id"):
        merged["subnet_id"] = all_source_outputs["ai_subnet_id"]
    elif target_posix.endswith("/01-platform") and all_source_outputs.get("data_subnet_id"):
        merged["subnet_id"] = all_source_outputs["data_subnet_id"]

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
