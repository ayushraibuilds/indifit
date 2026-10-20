#!/usr/bin/env bash
# Stages every catalogue pack version for Firebase Hosting (N14-03).
#
# A Hosting deploy replaces the whole site, so it must always carry every
# pack version an installed app might still ask for, not just the newest.
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repository_root"

readonly packs_dir='tool/catalog/packs'
readonly stage_dir='public/catalog/v1'
readonly project='indifit-d5f8d'
readonly deploy_command="firebase deploy --only hosting --project $project"

deploy=false

usage() {
  cat <<EOF
Usage: tool/stage_hosting.sh [--deploy]

Copies every pack version in $packs_dir into $stage_dir, validates the
manifest against the staged files and prints the deploy command.

  --deploy     Also run: $deploy_command
               and delete public/ afterwards.
  -h, --help   Show this help.
EOF
}

while (($# > 0)); do
  case "$1" in
    --deploy) deploy=true ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      echo "ERROR: Unknown option: $1" >&2
      exit 1
      ;;
  esac
  shift
done

rm -rf public
mkdir -p "$stage_dir"
cp "$packs_dir/manifest.json" "$stage_dir/"
for version_dir in "$packs_dir"/v*/; do
  cp -R "$version_dir" "$stage_dir/$(basename "$version_dir")"
done

python3 - "$stage_dir" <<'PY'
import hashlib, json, os, sys

root = sys.argv[1]
with open(os.path.join(root, "manifest.json")) as handle:
    manifest = json.load(handle)
problems = []
if manifest.get("format") != 1:
    problems.append(f"unsupported manifest format {manifest.get('format')!r}")
packs = manifest.get("packs") or []
versions = {p.get("version") for p in packs}
latest = manifest.get("latest")
if not any(p.get("version") == latest and p.get("kind") == "full" for p in packs):
    problems.append(f"no full pack for latest version {latest}")
referenced = set()
for pack in packs:
    url = pack.get("url", "")
    path = os.path.normpath(os.path.join(root, url))
    referenced.add(path)
    if not path.startswith(os.path.normpath(root) + os.sep) or not os.path.isfile(path):
        problems.append(f"missing {url}")
        continue
    with open(path, "rb") as handle:
        data = handle.read()
    if len(data) != pack.get("bytes"):
        problems.append(f"{url}: {len(data)} bytes, manifest says {pack.get('bytes')}")
    if hashlib.sha256(data).hexdigest() != pack.get("sha256"):
        problems.append(f"{url}: sha256 mismatch")
    if pack.get("kind") == "delta" and pack.get("base") not in versions:
        problems.append(f"{url}: delta base {pack.get('base')} is not staged")
for dirpath, _, files in os.walk(root):
    for name in files:
        path = os.path.normpath(os.path.join(dirpath, name))
        if name != "manifest.json" and path not in referenced:
            print(f"note: {os.path.relpath(path, root)} is staged but not in the manifest")
if problems:
    print("\n".join(problems), file=sys.stderr)
    sys.exit(1)
print(f"Manifest OK: latest v{latest}, {len(packs)} packs across {len(versions)} versions.")
PY

echo "Staged $(find "$stage_dir" -type f | wc -l | tr -d ' ') files in $stage_dir."
echo 'This deploy replaces the whole Hosting site with what is under public/.'

if [[ "$deploy" != true ]]; then
  echo
  echo 'To deploy:'
  echo "  $deploy_command"
  echo 'Then delete public/ (or rerun with --deploy, which does both).'
  exit 0
fi

trap 'rm -rf public' EXIT
$deploy_command
echo 'Deployed; public/ removed.'
