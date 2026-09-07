#!/usr/bin/env bash
#
# Builds the gtm-code invocation from the action's inputs and runs it.
#
# Inputs arrive through the environment rather than being interpolated into the script by the
# workflow runner, so a value containing shell metacharacters cannot escape into the command.
# Kept in its own file, rather than inline in action.yml, so that test.sh can exercise it.

set -euo pipefail

case "${INPUT_COMMAND}" in
  validate | plan | apply) ;;
  *)
    echo "::error::Unsupported command '${INPUT_COMMAND}'. Use validate, plan, or apply."
    exit 1
    ;;
esac

# An exact version is the whole point of the pin: a range or a dist-tag would make this action's
# own tag guarantee nothing about which CLI actually runs.
if ! [[ "${INPUT_VERSION}" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$ ]]; then
  echo "::error::version must be an exact version like 0.1.0, not '${INPUT_VERSION}'."
  exit 1
fi

args=("${INPUT_COMMAND}")

if [ -n "${INPUT_CONFIG}" ]; then
  args+=(--config "${INPUT_CONFIG}")
fi

# Every command reads the config, so every command needs to know which environment to read it as.
# The CLI rejects --env against a config with no environments: block, so this stays unset by
# default rather than guessing a name.
if [ -n "${INPUT_ENVIRONMENT}" ]; then
  args+=(--env "${INPUT_ENVIRONMENT}")
fi

# apply is the only command that prompts, so the flag is meaningless — and misleading — elsewhere.
if [ "${INPUT_COMMAND}" = "apply" ] && [ "${INPUT_AUTO_APPROVE}" = "true" ]; then
  args+=(--auto-approve)
fi

# Two separate gates in the CLI: --auto-approve skips the prompt, --allow-destroy authorizes the
# kind of change. An apply whose plan contains a delete refuses to run without this one, so without
# the input there was no way to apply a deletion through this action at all.
if [ "${INPUT_COMMAND}" = "apply" ] && [ "${INPUT_ALLOW_DESTROY}" = "true" ]; then
  args+=(--allow-destroy)
fi

exec npx --yes "@stackmade/gtm-as-code@${INPUT_VERSION}" "${args[@]}"
