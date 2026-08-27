#!/usr/bin/env bash
#
# Self-check for run.sh's argument building. Runs it against a stub `npx` that prints what it was
# called with, so the assertions cover the real script rather than a copy of its logic.
#
# Usage: ./test.sh

set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
stub_dir="$(mktemp -d)"
trap 'rm -rf "${stub_dir}"' EXIT

cat > "${stub_dir}/npx" <<'STUB'
#!/usr/bin/env bash
echo "$*"
STUB
chmod +x "${stub_dir}/npx"

failures=0

# run <expected> <command> <version> <config> <auto-approve>
run() {
  local expected="$1" name="$2"
  shift 2

  local actual status=0
  actual="$(
    PATH="${stub_dir}:${PATH}" \
      INPUT_COMMAND="$1" INPUT_VERSION="$2" INPUT_CONFIG="$3" INPUT_AUTO_APPROVE="$4" \
      bash "${here}/run.sh" 2>&1
  )" || status=$?

  if [ "${actual}" = "${expected}" ]; then
    echo "ok   ${name}"
  else
    echo "FAIL ${name}"
    echo "       expected: ${expected}"
    echo "       actual:   ${actual}"
    failures=$((failures + 1))
  fi
}

run '--yes @stackmade/gtm-as-code@0.1.0 plan' \
  'plan, no config' \
  plan 0.1.0 '' false

run '--yes @stackmade/gtm-as-code@0.1.0 plan --config analytics/analytics.yaml' \
  'config is passed through' \
  plan 0.1.0 analytics/analytics.yaml false

run '--yes @stackmade/gtm-as-code@9.9.9 validate' \
  'version is not hardcoded' \
  validate 9.9.9 '' false

run '--yes @stackmade/gtm-as-code@0.1.0 apply --auto-approve' \
  'apply forwards auto-approve' \
  apply 0.1.0 '' true

run '--yes @stackmade/gtm-as-code@0.1.0 apply' \
  'apply without auto-approve still prompts' \
  apply 0.1.0 '' false

# The flag exists only on apply; forwarding it to plan would be a lie about what plan does.
run '--yes @stackmade/gtm-as-code@0.1.0 plan' \
  'auto-approve is ignored by plan' \
  plan 0.1.0 '' true

run '--yes @stackmade/gtm-as-code@0.2.0-rc.1 plan' \
  'a prerelease version is accepted' \
  plan 0.2.0-rc.1 '' false

run "::error::Unsupported command 'plan; rm -rf /'. Use validate, plan, or apply." \
  'an unknown command is rejected, not run' \
  'plan; rm -rf /' 0.1.0 '' false

# A dist-tag or a range would silently defeat the pin this action advertises.
run "::error::version must be an exact version like 0.1.0, not 'latest'." \
  'a dist-tag version is rejected' \
  plan latest '' false

run "::error::version must be an exact version like 0.1.0, not '^0.1.0'." \
  'a range version is rejected' \
  plan '^0.1.0' '' false

if [ "${failures}" -ne 0 ]; then
  echo "${failures} failing"
  exit 1
fi

echo 'all passing'
