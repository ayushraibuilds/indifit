#!/usr/bin/env bash
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repository_root"

expected_application_id="com.indifit.indifit"
expected_name="IndiFit"
expected_version="1.0.0"
expected_build="1"

android_apk=""
android_aab=""
ios_app=""
evidence_path=""
allow_ci_signing=false
allow_unsigned_ios=false

usage() {
  cat <<'EOF'
Usage: tool/verify_r09_artifacts.sh [artifacts] [options]

Artifacts (at least one required):
  --android-apk PATH       Inspect an Android release APK.
  --android-aab PATH       Inspect an Android release App Bundle.
  --ios-app PATH           Inspect a built iOS .app directory.

Options:
  --evidence PATH          Write a plain-text evidence record.
  --allow-ci-signing       Allow IndiFit's known throwaway CI certificate.
  --allow-unsigned-ios     Allow an unsigned iOS app (CI/compiler proof only).
EOF
}

while (($# > 0)); do
  case "$1" in
    --android-apk)
      android_apk="${2:-}"
      shift 2
      ;;
    --android-aab)
      android_aab="${2:-}"
      shift 2
      ;;
    --ios-app)
      ios_app="${2:-}"
      shift 2
      ;;
    --evidence)
      evidence_path="${2:-}"
      shift 2
      ;;
    --allow-ci-signing)
      allow_ci_signing=true
      shift
      ;;
    --allow-unsigned-ios)
      allow_unsigned_ios=true
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 64
      ;;
  esac
done

if [[ -z "$android_apk" && -z "$android_aab" && -z "$ios_app" ]]; then
  echo "At least one artifact path is required." >&2
  usage >&2
  exit 64
fi

if [[ -n "$android_aab" && -z "$android_apk" ]]; then
  echo "--android-aab requires --android-apk so package identity and signing-key equality can be verified." >&2
  exit 64
fi

if [[ -n "$evidence_path" ]]; then
  mkdir -p "$(dirname "$evidence_path")"
  : >"$evidence_path"
fi

record() {
  printf '%s\n' "$*"
  if [[ -n "$evidence_path" ]]; then
    printf '%s\n' "$*" >>"$evidence_path"
  fi
}

fail() {
  record "FAIL: $*"
  exit 1
}

require_file() {
  [[ -f "$1" ]] || fail "Missing artifact: $1"
}

sha256_for() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  else
    sha256sum "$1" | awk '{print $1}'
  fi
}

size_for() {
  if stat -f '%z' "$1" >/dev/null 2>&1; then
    stat -f '%z' "$1"
  else
    stat -c '%s' "$1"
  fi
}

reject_nonproduction_android_certificate() {
  local certificate="$1"
  if [[ "$certificate" == *"CN=Android Debug"* ]]; then
    fail "Android artifact uses the SDK debug certificate."
  fi
  if [[ "$certificate" == *"CN=IndiFit, OU=Dev, O=IndiFit, L=Local, ST=Local, C=IN"* && "$allow_ci_signing" != true ]]; then
    fail "Android artifact uses IndiFit's throwaway CI certificate."
  fi
}

android_sdk_root() {
  if [[ -n "${ANDROID_HOME:-}" ]]; then
    printf '%s\n' "$ANDROID_HOME"
    return
  fi
  if [[ -n "${ANDROID_SDK_ROOT:-}" ]]; then
    printf '%s\n' "$ANDROID_SDK_ROOT"
    return
  fi
  if [[ -f android/local.properties ]]; then
    sed -n 's/^sdk\.dir=//p' android/local.properties | head -1
    return
  fi
  return 1
}

latest_build_tool() {
  local tool_name="$1"
  local sdk_root="$2"
  find "$sdk_root/build-tools" -type f -name "$tool_name" -print | sort | tail -1
}

record "IndiFit R09-D release artifact evidence"
record "expected.application_id=$expected_application_id"
record "expected.name=$expected_name"
record "expected.version=$expected_version"
record "expected.build=$expected_build"

if [[ -n "$android_apk" ]]; then
  require_file "$android_apk"
  sdk_root="$(android_sdk_root)" || fail "Android SDK location is unavailable."
  aapt_path="$(latest_build_tool aapt "$sdk_root")"
  apksigner_path="$(latest_build_tool apksigner "$sdk_root")"
  [[ -x "$aapt_path" ]] || fail "aapt is unavailable in $sdk_root/build-tools."
  [[ -x "$apksigner_path" ]] || fail "apksigner is unavailable in $sdk_root/build-tools."

  apk_badging="$("$aapt_path" dump badging "$android_apk")"
  package_line="$(printf '%s\n' "$apk_badging" | sed -n '1p')"
  label_line="$(printf '%s\n' "$apk_badging" | sed -n "s/^application-label:'\([^']*\)'.*/\1/p" | head -1)"

  [[ "$package_line" == *"name='$expected_application_id'"* ]] || fail "APK application ID does not match."
  [[ "$package_line" == *"versionCode='$expected_build'"* ]] || fail "APK versionCode does not match."
  [[ "$package_line" == *"versionName='$expected_version'"* ]] || fail "APK versionName does not match."
  [[ "$label_line" == "$expected_name" ]] || fail "APK application label does not match."

  apk_signature="$("$apksigner_path" verify --verbose --print-certs "$android_apk")"
  reject_nonproduction_android_certificate "$apk_signature"
  apk_certificate="$(printf '%s\n' "$apk_signature" | sed -n 's/^.*certificate DN: //p' | head -1)"
  apk_certificate_sha="$(printf '%s\n' "$apk_signature" | sed -n 's/^.*certificate SHA-256 digest: //p' | head -1)"

  record "android.apk.path=$android_apk"
  record "android.apk.bytes=$(size_for "$android_apk")"
  record "android.apk.sha256=$(sha256_for "$android_apk")"
  record "android.apk.application_id=$expected_application_id"
  record "android.apk.label=$label_line"
  record "android.apk.version=$expected_version+$expected_build"
  record "android.apk.certificate=$apk_certificate"
  record "android.apk.certificate_sha256=$apk_certificate_sha"
fi

if [[ -n "$android_aab" ]]; then
  require_file "$android_aab"
  command -v jarsigner >/dev/null 2>&1 || fail "jarsigner is unavailable."
  command -v keytool >/dev/null 2>&1 || fail "keytool is unavailable."
  command -v unzip >/dev/null 2>&1 || fail "unzip is unavailable."

  aab_verification="$(jarsigner -verify "$android_aab" 2>&1)" || fail "AAB JAR signature verification failed."
  grep -Fq 'jar verified.' <<<"$aab_verification" || fail "AAB is not signed."
  aab_entries="$(unzip -Z1 "$android_aab")"
  for required_entry in BundleConfig.pb base/manifest/AndroidManifest.xml base/dex/classes.dex; do
    printf '%s\n' "$aab_entries" | grep -Fxq "$required_entry" || fail "AAB is missing $required_entry."
  done

  aab_certificate="$(keytool -printcert -jarfile "$android_aab")"
  reject_nonproduction_android_certificate "$aab_certificate"
  aab_owner="$(printf '%s\n' "$aab_certificate" | sed -n 's/^Owner: //p' | head -1)"
  aab_certificate_sha="$(printf '%s\n' "$aab_certificate" | sed -n 's/^[[:space:]]*SHA256: //p' | head -1)"

  record "android.aab.path=$android_aab"
  record "android.aab.bytes=$(size_for "$android_aab")"
  record "android.aab.sha256=$(sha256_for "$android_aab")"
  record "android.aab.certificate=$aab_owner"
  record "android.aab.certificate_sha256=$aab_certificate_sha"

  normalized_apk_certificate_sha="$(printf '%s' "$apk_certificate_sha" | tr -d ':' | tr '[:upper:]' '[:lower:]')"
  normalized_aab_certificate_sha="$(printf '%s' "$aab_certificate_sha" | tr -d ':' | tr '[:upper:]' '[:lower:]')"
  [[ -n "$normalized_apk_certificate_sha" ]] || fail "APK signing certificate digest is unavailable."
  [[ "$normalized_apk_certificate_sha" == "$normalized_aab_certificate_sha" ]] || fail "APK and AAB use different signing certificates."
  record "android.signing.same_certificate=true"
fi

plist_value() {
  /usr/libexec/PlistBuddy -c "Print :$2" "$1"
}

if [[ -n "$ios_app" ]]; then
  [[ -d "$ios_app" ]] || fail "Missing iOS app directory: $ios_app"
  ios_plist="$ios_app/Info.plist"
  require_file "$ios_plist"
  [[ -f "$ios_app/Assets.car" ]] || fail "iOS Assets.car is missing."
  [[ -d "$ios_app/Base.lproj/LaunchScreen.storyboardc" ]] || fail "Compiled iOS launch screen is missing."

  ios_identifier="$(plist_value "$ios_plist" CFBundleIdentifier)"
  ios_name="$(plist_value "$ios_plist" CFBundleDisplayName)"
  ios_version="$(plist_value "$ios_plist" CFBundleShortVersionString)"
  ios_build="$(plist_value "$ios_plist" CFBundleVersion)"

  [[ "$ios_identifier" == "$expected_application_id" ]] || fail "iOS bundle identifier does not match."
  [[ "$ios_name" == "$expected_name" ]] || fail "iOS display name does not match."
  [[ "$ios_version" == "$expected_version" ]] || fail "iOS marketing version does not match."
  [[ "$ios_build" == "$expected_build" ]] || fail "iOS build number does not match."

  ios_signing="unsigned"
  if codesign --verify --deep --strict "$ios_app" >/dev/null 2>&1; then
    ios_signing="signed"
    codesign_details="$(codesign -dv --verbose=4 "$ios_app" 2>&1)"
    codesign_entitlements="$(codesign -d --entitlements :- "$ios_app" 2>/dev/null)"
    codesign_identifier="$(printf '%s\n' "$codesign_details" | sed -n 's/^Identifier=//p' | head -1)"
    ios_data_protection="$(plutil -extract com.apple.developer.default-data-protection raw -o - - <<<"$codesign_entitlements" 2>/dev/null || true)"
    ios_healthkit="$(plutil -extract com.apple.developer.healthkit raw -o - - <<<"$codesign_entitlements" 2>/dev/null || true)"
    [[ "$codesign_identifier" == "$expected_application_id" ]] || fail "Signed iOS identifier does not match."
    [[ "$ios_data_protection" == "NSFileProtectionCompleteUntilFirstUserAuthentication" ]] || fail "Signed iOS app is missing the required default data-protection entitlement."
    [[ "$ios_healthkit" == "true" ]] || fail "Signed iOS app is missing the HealthKit entitlement."
    record "ios.codesign.team=$(printf '%s\n' "$codesign_details" | sed -n 's/^TeamIdentifier=//p' | head -1)"
    record "ios.codesign.authority=$(printf '%s\n' "$codesign_details" | sed -n 's/^Authority=//p' | head -1)"
    record "ios.codesign.cdhash=$(printf '%s\n' "$codesign_details" | sed -n 's/^CDHash=//p' | head -1)"
    record "ios.codesign.data_protection=$ios_data_protection"
    record "ios.codesign.healthkit=$ios_healthkit"
  elif [[ "$allow_unsigned_ios" != true ]]; then
    fail "iOS app is unsigned. Pass --allow-unsigned-ios only for CI/compiler evidence."
  fi

  record "ios.app.path=$ios_app"
  record "ios.app.application_id=$ios_identifier"
  record "ios.app.name=$ios_name"
  record "ios.app.version=$ios_version+$ios_build"
  record "ios.app.signing=$ios_signing"
  record "ios.assets.bytes=$(size_for "$ios_app/Assets.car")"
  record "ios.assets.sha256=$(sha256_for "$ios_app/Assets.car")"
fi

record "result=PASS"
