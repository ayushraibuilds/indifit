#!/usr/bin/env bash
# Builds the store-ready Android App Bundle and/or iOS IPA (N14-03).
#
# Unlike CI and tool/verify_r09_release.sh, this build ships the 65 RepDB
# exercise pictures, the catalogue manifest URL, Sentry and obfuscation, and
# checks the Play/App Store rules nothing else checks.
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repository_root"

readonly catalog_manifest_url='https://indifit-d5f8d.web.app/catalog/v1/manifest.json'
readonly asset_manifest='assets/third_party/asset_manifest.json'
readonly repdb_dir='assets/generated/repdb'
readonly min_target_sdk=36

build_android=false
build_ios=false
ai_mode=''
allow_no_sentry=false
check_only=false
ci_mode=false

usage() {
  cat <<'EOF'
Usage: tool/build_store_release.sh --ai on|off [--android] [--ios] [options]

Builds a store release from a clean tree, with exactly the RepDB pictures
listed in assets/third_party/asset_manifest.json (65 since N14-06), each
matching its checksum. SENTRY_DSN must be set in the
environment.

Targets (at least one unless --check):
  --android            Build the Play App Bundle (needs a real android/key.properties).
  --ios                Build the App Store IPA (needs Xcode signing).

Required:
  --ai on|off          Sets INDIFIT_CONNECTED_AI. No default on purpose.

Options:
  --allow-no-sentry    Build without SENTRY_DSN (prints a loud warning).
  --check              Run the define, keystore and picture checks only; no build.
  --ci                 With --check only: skip the keystore check (CI has no keystore).
  -h, --help           Show this help.

Always passed: INDIFIT_CATALOG_MANIFEST_URL, --obfuscate and
--split-debug-info=build/symbols/<version>. Symbols are uploaded with
sentry-cli only when it is installed and SENTRY_AUTH_TOKEN is set.
EOF
}

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

loud_warning() {
  echo >&2
  echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" >&2
  echo "!! WARNING: $*" >&2
  echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" >&2
  echo >&2
}

while (($# > 0)); do
  case "$1" in
    --android) build_android=true ;;
    --ios) build_ios=true ;;
    --ai)
      (($# >= 2)) || fail '--ai needs a value: on or off.'
      ai_mode="$2"
      shift
      ;;
    --ai=*) ai_mode="${1#--ai=}" ;;
    --allow-no-sentry) allow_no_sentry=true ;;
    --check) check_only=true ;;
    --ci) ci_mode=true ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      fail "Unknown option: $1"
      ;;
  esac
  shift
done

passed_checks=()
record_pass() {
  passed_checks+=("$1")
  echo "PASS: $1"
}

# --- Defines ------------------------------------------------------------

case "$ai_mode" in
  on) connected_ai=true ;;
  off) connected_ai=false ;;
  '') fail '--ai on|off is required (sets INDIFIT_CONNECTED_AI).' ;;
  *) fail "--ai must be on or off, not '$ai_mode'." ;;
esac

if [[ "$ci_mode" == true && "$check_only" != true ]]; then
  fail '--ci only applies to --check. Store builds always check the keystore.'
fi
if [[ "$check_only" != true && "$build_android" != true && "$build_ios" != true ]]; then
  fail 'Choose --android, --ios or both (or --check).'
fi

sentry_dsn="${SENTRY_DSN:-}"
if [[ -z "$sentry_dsn" ]]; then
  if [[ "$allow_no_sentry" == true ]]; then
    loud_warning 'SENTRY_DSN is not set. This build reports NO crashes and hides the crash-report opt-in.'
  else
    fail 'SENTRY_DSN is not set. Export it, or pass --allow-no-sentry to build without crash reporting.'
  fi
fi

version_line="$(grep -E '^version:' pubspec.yaml | head -1 | awk '{print $2}')"
[[ "$version_line" =~ ^([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+)$ ]] ||
  fail "pubspec.yaml version '$version_line' is not <name>+<build>."
version_name="${BASH_REMATCH[1]}"
build_number="${BASH_REMATCH[2]}"
symbols_dir="build/symbols/${version_name}+${build_number}"

defines=(
  "--dart-define=INDIFIT_CONNECTED_AI=${connected_ai}"
  "--dart-define=INDIFIT_CATALOG_MANIFEST_URL=${catalog_manifest_url}"
  "--dart-define=SENTRY_DSN=${sentry_dsn}"
)
record_pass "defines (AI ${ai_mode}, catalogue URL, Sentry $([[ -n "$sentry_dsn" ]] && echo set || echo MISSING))"

# --- Keystore -----------------------------------------------------------

check_keystore() {
  local properties='android/key.properties'
  [[ -f "$properties" ]] ||
    fail "$properties is missing. Copy android/key.properties.example and point it at the upload keystore."
  local store_file
  store_file="$(grep -E '^storeFile=' "$properties" | head -1 | cut -d= -f2- | tr -d '[:space:]')"
  [[ -n "$store_file" ]] || fail "$properties has no storeFile."
  case "$(basename "$store_file")" in
    dummy.keystore | ci-release.keystore)
      fail "$properties points at a throwaway keystore ($store_file). Use the real upload key."
      ;;
  esac
  # Gradle resolves storeFile relative to android/app.
  local resolved="$store_file"
  [[ "$resolved" == /* ]] || resolved="android/app/$store_file"
  [[ -f "$resolved" ]] || fail "Keystore $resolved (from $properties) does not exist."
  record_pass 'upload keystore configured'
}

if [[ "$ci_mode" == true ]]; then
  echo 'SKIP: keystore check (--ci).'
elif [[ "$check_only" == true || "$build_android" == true ]]; then
  check_keystore
fi

# --- Pictures -----------------------------------------------------------

verify_pictures() {
  python3 - "$asset_manifest" "$repdb_dir" <<'PY'
import hashlib, json, os, sys

manifest_path, root = sys.argv[1], sys.argv[2]
with open(manifest_path) as handle:
    assets = json.load(handle)["assets"]
wanted = {
    a["local_destination"]: a["sha256"].split(":", 1)[1].lower()
    for a in assets
    if a["local_destination"].startswith(root + "/")
}
problems = []
if not wanted:
    problems.append("manifest lists no RepDB pictures")
present = set()
if os.path.isdir(root):
    for name in os.listdir(root):
        if name.lower().endswith(".webp"):
            present.add(f"{root}/{name}")
for path in sorted(present - wanted.keys()):
    problems.append(f"unexpected file {path}")
for path, digest in sorted(wanted.items()):
    if path not in present:
        problems.append(f"missing {path}")
        continue
    with open(path, "rb") as handle:
        actual = hashlib.sha256(handle.read()).hexdigest()
    if actual != digest:
        problems.append(f"checksum mismatch {path}")
if problems:
    print("\n".join(problems[:20]), file=sys.stderr)
    sys.exit(1)
print(len(wanted))
PY
}

ensure_pictures() {
  if picture_count="$(verify_pictures 2>/dev/null)"; then
    echo "RepDB pictures already present and verified."
  else
    echo "Fetching RepDB pictures with tool/acquire_r08_repdb_assets.dart ..."
    # Only the pictures: the directory keeps its tracked .gitkeep.
    find "$repdb_dir" -type f -name '*.webp' -delete 2>/dev/null || true
    dart run tool/acquire_r08_repdb_assets.dart ||
      fail 'RepDB picture acquisition failed. The store build must ship all pictures.'
    picture_count="$(verify_pictures)" ||
      fail "RepDB pictures failed verification (every file in $asset_manifest must be present with its checksum, and nothing else)."
  fi
  record_pass "$picture_count RepDB pictures match their checksums"
}

if [[ "$check_only" == true ]]; then
  flutter pub get >/dev/null
  ensure_pictures
  echo
  echo 'Check passed (no build):'
  printf '  - %s\n' "${passed_checks[@]}"
  exit 0
fi

# --- Build --------------------------------------------------------------

echo "Starting from flutter clean ..."
flutter clean
flutter pub get
ensure_pictures

build_flags=(
  --release
  --obfuscate
  "--split-debug-info=${symbols_dir}"
  "--build-name=${version_name}"
  "--build-number=${build_number}"
  "${defines[@]}"
)

check_target_sdk() {
  local target_sdk=''
  if command -v bundletool >/dev/null 2>&1; then
    target_sdk="$(bundletool dump manifest --bundle "$1" \
      --xpath /manifest/uses-sdk/@android:targetSdkVersion 2>/dev/null || true)"
  fi
  if [[ -z "$target_sdk" ]]; then
    local merged
    merged="$(find build/app/intermediates -path '*release*' -name AndroidManifest.xml \
      \( -path '*merged_manifest*' -o -path '*bundle_manifest*' \) 2>/dev/null | head -1)"
    [[ -n "$merged" ]] || fail 'Could not find the built release manifest to read targetSdk.'
    target_sdk="$(grep -oE 'android:targetSdkVersion="[0-9]+"' "$merged" | head -1 | grep -oE '[0-9]+')"
  fi
  [[ "$target_sdk" =~ ^[0-9]+$ ]] || fail "Could not read targetSdk from the built manifest."
  ((target_sdk >= min_target_sdk)) ||
    fail "targetSdk is $target_sdk; Play requires >= $min_target_sdk."
  record_pass "targetSdk $target_sdk >= $min_target_sdk"
}

check_16kb_alignment() {
  local aab="$1" extract
  extract="$(mktemp -d)"
  unzip -q "$aab" '*.so' -d "$extract" 2>/dev/null || true
  local result
  result="$(python3 - "$extract" <<'PY'
import os, struct, sys

bad, count = [], 0
for root, _, files in os.walk(sys.argv[1]):
    for name in files:
        if not name.endswith(".so"):
            continue
        path = os.path.join(root, name)
        rel = os.path.relpath(path, sys.argv[1])
        with open(path, "rb") as f:
            data = f.read()
        if data[:4] != b"\x7fELF":
            bad.append(f"{rel}: not ELF")
            continue
        is64, little = data[4] == 2, data[5] == 1
        e = "<" if little else ">"
        if is64:
            phoff, = struct.unpack_from(e + "Q", data, 0x20)
            phentsize, phnum = struct.unpack_from(e + "HH", data, 0x36)
        else:
            phoff, = struct.unpack_from(e + "I", data, 0x1C)
            phentsize, phnum = struct.unpack_from(e + "HH", data, 0x2A)
        count += 1
        if not is64:
            continue  # 32-bit ABIs are exempt from the 16 KB rule.
        for i in range(phnum):
            off = phoff + i * phentsize
            p_type, = struct.unpack_from(e + "I", data, off)
            if p_type != 1:  # PT_LOAD
                continue
            p_align, = struct.unpack_from(e + "Q", data, off + 0x30)
            if p_align < 16384:
                bad.append(f"{rel}: LOAD align {p_align}")
                break
if bad:
    print("\n".join(bad), file=sys.stderr)
    sys.exit(1)
print(count)
PY
)" || {
    rm -rf "$extract"
    fail 'Native libraries are not 16 KB aligned (see above).'
  }
  rm -rf "$extract"
  ((result > 0)) || fail "No .so files found in $aab."
  record_pass "16 KB alignment of $result .so files"
}

check_ios_platforms() {
  local app="$1" bad=() checked=0 binary platforms
  local binaries=("$app/$(basename "$app" .app)")
  while IFS= read -r framework; do
    binaries+=("$framework/$(basename "$framework" .framework)")
  done < <(find "$app/Frameworks" -maxdepth 1 -name '*.framework' 2>/dev/null)
  for binary in "${binaries[@]}"; do
    [[ -f "$binary" ]] || { bad+=("$binary: missing"); continue; }
    platforms="$(xcrun vtool -show-build "$binary" 2>/dev/null |
      awk '$1 == "platform" {print $2}' | sort -u | tr '\n' ' ')"
    checked=$((checked + 1))
    [[ "$platforms" == 'IOS ' ]] || bad+=("$(basename "$binary"): platform '${platforms:-none}'")
  done
  if ((${#bad[@]} > 0)); then
    printf '  %s\n' "${bad[@]}" >&2
    fail 'Some binaries are not built for iOS devices (stale native assets, UR-30). Run flutter clean and rebuild.'
  fi
  record_pass "$checked iOS binaries are device (IOS) builds"
}

artifacts=()

if [[ "$build_android" == true ]]; then
  flutter build appbundle "${build_flags[@]}"
  aab='build/app/outputs/bundle/release/app-release.aab'
  [[ -f "$aab" ]] || fail "Expected $aab after the build."
  check_target_sdk "$aab"
  check_16kb_alignment "$aab"
  artifacts+=("$aab")
fi

if [[ "$build_ios" == true ]]; then
  [[ "$(uname)" == Darwin ]] || fail 'iOS builds need macOS.'
  flutter build ipa "${build_flags[@]}"
  app="$(find build/ios/archive -path '*Products/Applications/*.app' -maxdepth 5 -type d | head -1)"
  [[ -n "$app" ]] || fail 'Could not find the archived .app.'
  check_ios_platforms "$app"
  ipa="$(find build/ios/ipa -name '*.ipa' | head -1)"
  [[ -n "$ipa" ]] || fail 'Expected an IPA under build/ios/ipa (check Xcode signing).'
  artifacts+=("$ipa")
fi

# --- Symbols ------------------------------------------------------------

echo "Dart symbols: $symbols_dir (keep them; obfuscated stack traces need them)."
symbols_uploaded='no (sentry-cli or SENTRY_AUTH_TOKEN missing)'
if command -v sentry-cli >/dev/null 2>&1 && [[ -n "${SENTRY_AUTH_TOKEN:-}" ]]; then
  sentry-cli debug-files upload "$symbols_dir"
  if [[ "$build_ios" == true ]]; then
    sentry-cli debug-files upload build/ios/archive
  fi
  symbols_uploaded='yes'
fi

# --- Summary ------------------------------------------------------------

echo
echo '================ Store release summary ================'
echo "Version:        $version_name"
echo "Build number:   $build_number"
echo 'Defines:'
echo "  INDIFIT_CONNECTED_AI=$connected_ai"
echo "  INDIFIT_CATALOG_MANIFEST_URL=$catalog_manifest_url"
echo "  SENTRY_DSN=$([[ -n "$sentry_dsn" ]] && echo '<redacted>' || echo '<EMPTY - no crash reports>')"
echo "Pictures:       $picture_count RepDB WebPs"
echo "Symbols:        $symbols_dir (uploaded: $symbols_uploaded)"
echo 'Artifacts:'
printf '  %s\n' "${artifacts[@]}"
echo 'Checks passed:'
printf '  - %s\n' "${passed_checks[@]}"
