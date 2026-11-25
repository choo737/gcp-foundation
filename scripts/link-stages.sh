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
  if [[ ! "$env_name" =~ ^(shared|dev|uat|prod)$ ]]; then
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
  mode="merge-gcs"
elif [ "$export_gcs" = true ]; then
  mode="export-gcs"
elif [ "$from_gcs" = true ]; then
  mode="from-gcs"
else
  mode="local"
fi

target_abs=""
out_file=""
inputs=()

if [ "$mode" = "merge-gcs" ]; then
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
  inputs=("${positional[@]}")
elif [ "$mode" = "export-gcs" ]; then
  if [ "${#positional[@]}" -lt 1 ]; then
    usage
    exit 1
  fi
  if [[ ! "$gcs_export_uri" =~ ^gs://[^/]+(/.*)?$ ]]; then
    echo "Invalid GCS URI: $gcs_export_uri" >&2
    exit 1
  fi
  for src in "${positional[@]}"; do
    if [ ! -d "$src" ]; then
      echo "Source stage directory does not exist: $src" >&2
      exit 1
    fi
  done
  inputs=("${positional[@]}")
else
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
fi

python3 - "$mode" "$env_name" "$tfstate_bucket" "$REPO_ROOT" "$gcs_export_uri" "$target_abs" "$out_file" "${inputs[@]}" <<'PY'
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile

mode = sys.argv[1]
env_name = sys.argv[2]
tfstate_bucket = sys.argv[3]
repo_root = Path(sys.argv[4]).resolve()
raw_gcs_export_uri = sys.argv[5]
target_dir = Path(sys.argv[6]) if sys.argv[6] else None
out_file = Path(sys.argv[7]) if sys.argv[7] else None
sources = sys.argv[8:]

OUTPUT_ALIASES = {
    "core_storage_project_id": "core_project_id",
    "subnet_id": "egress_connector_subnet_id",
    "notification_channel_ids": "alert_notification_channel_ids",
    "kms_key_name": "kms_key_id",
    "network_id": "vpc_id",
    "environment_data_platform_folder_ids": "environment_data_folder_ids",
}


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


def resolve_backend_prefix(src_abs: Path, env: str) -> str:
    resolved_src = src_abs.resolve()
    try:
        rel_stage = resolved_src.relative_to(repo_root).as_posix()
    except ValueError:
        ext_root = find_repo_root(resolved_src)
        rel_stage = resolved_src.relative_to(ext_root).as_posix() if ext_root is not None else resolved_src.name
    effective_env = "shared" if rel_stage == "foundation/01-org-governance" else env
    return f"{rel_stage}/{effective_env}"


def stage_uses_gcs_backend(stage_abs: Path) -> bool:
    if (stage_abs / "envs").is_dir():
        return True
    versions_tf = stage_abs / "versions.tf"
    return versions_tf.is_file() and 'backend "gcs"' in versions_tf.read_text(encoding="utf-8")


def unwrap_outputs(raw_obj: dict[str, object]) -> dict[str, object]:
    values: dict[str, object] = {}
    for key, payload in raw_obj.items():
        if isinstance(payload, dict) and "value" in payload:
            if payload.get("sensitive") is True:
                continue
            val = payload.get("value")
        else:
            val = payload
        if val is not None:
            values[key] = val
    return values


def read_gcs_values(raw_uri: str) -> dict[str, object]:
    gcs_uri = resolve_env_gcs_uri(raw_uri, env_name)
    if not re.match(r"^gs://[^/]+/.+", gcs_uri):
        raise SystemExit(f"Invalid GCS URI (missing object path): {gcs_uri}")
    raw = subprocess.check_output(["gcloud", "storage", "cat", gcs_uri], text=True)
    outputs = json.loads(raw)
    if not isinstance(outputs, dict):
        raise ValueError(f"Expected JSON object in {gcs_uri}")
    return unwrap_outputs(outputs)


def read_local_stage_values(raw_src: str) -> dict[str, object]:
    src_abs = Path(raw_src).resolve()
    if env_name and tfstate_bucket and stage_uses_gcs_backend(src_abs):
        backend_prefix = resolve_backend_prefix(src_abs, env_name)
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
    raw = subprocess.check_output(["terraform", f"-chdir={src_abs}", "output", "-json"], text=True)
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
    return unwrap_outputs(outputs)


def upload_json_to_gcs(payload: dict[str, object], raw_dest_uri: str) -> str:
    dest_uri = resolve_env_gcs_uri(raw_dest_uri, env_name)
    if not re.match(r"^gs://[^/]+/.+", dest_uri):
        raise SystemExit(f"Invalid GCS URI (missing object path): {dest_uri}")
    fd, tmp_name = tempfile.mkstemp(prefix="iac-outputs-", suffix=".json")
    tmp_path = Path(tmp_name)
    try:
        os.chmod(tmp_path, 0o600)
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            handle.write(json.dumps(payload, indent=2, sort_keys=True) + "\n")
        os.chmod(tmp_path, 0o600)
        subprocess.run(["gcloud", "storage", "cp", str(tmp_path), dest_uri], check=True)
    finally:
        if tmp_path.exists():
            tmp_path.unlink()
    return dest_uri


def write_local_json_atomic(payload: dict[str, object], dest_file: Path) -> None:
    tmp_file = dest_file.with_name(f".{dest_file.name}.{os.getpid()}.tmp")
    fd = os.open(tmp_file, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            handle.write(json.dumps(payload, indent=2, sort_keys=True) + "\n")
        os.chmod(tmp_file, 0o600)
        os.replace(tmp_file, dest_file)
    except Exception:
        if tmp_file.exists():
            tmp_file.unlink()
        raise


if mode in ("merge-gcs", "export-gcs"):
    exported: dict[str, object] = {}
    reader = read_gcs_values if mode == "merge-gcs" else read_local_stage_values
    for src in sources:
        exported.update(reader(src))
    if env_name:
        exported["environment"] = env_name
    dest_uri = upload_json_to_gcs(exported, raw_gcs_export_uri)
    noun = "GCS object(s)" if mode == "merge-gcs" else "stage(s)"
    verb = "Merged" if mode == "merge-gcs" else "Exported"
    extra = "" if mode == "merge-gcs" else "non-sensitive "
    print(f"{verb} {len(exported)} {extra}output(s) from {len(sources)} {noun} to {dest_uri}")
    raise SystemExit(0)

assert target_dir is not None and out_file is not None
var_re = re.compile(r'^\s*variable\s+"([A-Za-z0-9_]+)"\s*\{', re.MULTILINE)
declared_vars = set(var_re.findall((target_dir / "variables.tf").read_text(encoding="utf-8")))

merged: dict[str, object] = {}
all_source_outputs: dict[str, object] = {}
reader = read_gcs_values if mode == "from-gcs" else read_local_stage_values

for src in sources:
    source_vals = reader(src)
    all_source_outputs.update(source_vals)
    for key, val in source_vals.items():
        alias = OUTPUT_ALIASES.get(key)
        if alias and alias in declared_vars and alias not in source_vals:
            merged[alias] = val
    for key, val in source_vals.items():
        if key in declared_vars:
            merged[key] = val

target_posix = target_dir.as_posix()
if "subnet_id" in declared_vars:
    if target_posix.endswith("/apps/enterprise") and all_source_outputs.get("app_subnet_id"):
        merged["subnet_id"] = all_source_outputs["app_subnet_id"]
    elif target_posix.endswith("/03-data-science") and all_source_outputs.get("ai_subnet_id"):
        merged["subnet_id"] = all_source_outputs["ai_subnet_id"]
    elif target_posix.endswith("/01-platform") and all_source_outputs.get("data_subnet_id"):
        merged["subnet_id"] = all_source_outputs["data_subnet_id"]
    elif "egress_connector_subnet_id" in declared_vars and isinstance(all_source_outputs.get("ai_subnet_id"), str) and all_source_outputs["ai_subnet_id"].strip():
        merged["subnet_id"] = all_source_outputs["ai_subnet_id"]

if "egress_connector_subnet_id" in declared_vars:
    ai_subnet = all_source_outputs.get("ai_subnet_id")
    explicit_egress = all_source_outputs.get("egress_connector_subnet_id")
    if isinstance(ai_subnet, str) and ai_subnet.strip() and not (isinstance(explicit_egress, str) and explicit_egress.strip()):
        merged["egress_connector_subnet_id"] = ai_subnet

if env_name and "environment" in declared_vars:
    merged["environment"] = env_name

write_local_json_atomic(merged, out_file)
print(f"Wrote {len(merged)} linked variable(s) to {out_file}")
PY
