# gtm-as-code-action

GitHub Action for [`@stackmade/gtm-as-code`](https://github.com/StackMade/gtm-as-code). It runs
`validate`, `plan`, or `apply` against your Google Tag Manager container and GA4 property from a
workflow.

## Status

Usable, and as young as the CLI it runs. `@stackmade/gtm-as-code` is published, and this action
pins `0.1.1` by default. The major tag is `v0` on purpose: the CLI is pre-1.0, so its output and
flags may still change, and the action's version line should say so rather than imply a stability
the tool underneath has not earned.

Two limits of the CLI apply to any run of this action. GA4 ownership lives in a local, gitignored
state file, so `apply` on a fresh runner tries to re-create GA4 resources that already exist; GTM
is unaffected, because its ownership marker lives in the container. And there is no workspace
conflict detection yet, so an `apply` can overwrite edits someone made in the GTM UI. Both are
being addressed in the CLI's 0.2, and both are described in the
[CLI's README](https://github.com/StackMade/gtm-as-code#cicd). Running `plan` in CI is safe today.
Keep `apply` to GTM, or to a local machine, until 0.2 lands.

## Usage

```yaml
jobs:
  plan:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      id-token: write        # for Workload Identity Federation
    steps:
      - uses: actions/checkout@v7

      - uses: google-github-actions/auth@v3
        with:
          workload_identity_provider: ${{ secrets.WIF_PROVIDER }}
          service_account: ${{ secrets.WIF_SERVICE_ACCOUNT }}

      - uses: StackMade/gtm-as-code-action@v0
        with:
          command: plan
        env:
          GTM_ACCOUNT_ID: ${{ secrets.GTM_ACCOUNT_ID }}
          GTM_CONTAINER_ID: ${{ secrets.GTM_CONTAINER_ID }}
          GA4_PROPERTY_ID: ${{ secrets.GA4_PROPERTY_ID }}
```

Applying on merge is the same step with `command: apply` and `auto-approve: true`.

## Authentication is the caller's job

This action does not authenticate. It reads Google credentials from the environment, exactly as the
CLI does, through the standard Application Default Credentials chain. Run
[`google-github-actions/auth`](https://github.com/google-github-actions/auth), or set
`GOOGLE_APPLICATION_CREDENTIALS` yourself, in a step before this one.

There is deliberately no input for a service-account key. Passing a credential as an action input
writes it into the workflow's input record, and from there into logs and forks. Use Workload
Identity Federation, or a secret consumed by an auth action that knows how to mask it.

## Inputs

| Input | Default | Description |
|---|---|---|
| `command` | `plan` | `validate`, `plan`, or `apply`. Anything else fails the step. |
| `version` | `0.1.1` | Exact version of the `@stackmade/gtm-as-code` npm package to run. A range or a dist-tag such as `latest` is rejected. See below. |
| `config` | *(empty)* | Path to the config file, relative to `working-directory`. Empty lets the CLI discover `analytics.yaml` or `analytics/analytics.yaml`. |
| `working-directory` | `.` | Directory to run in. For monorepos. |
| `node-version` | `22` | Node.js to set up first. The CLI needs 22 or newer. Empty skips setup and uses the job's existing Node. |
| `auto-approve` | `false` | Skips `apply`'s confirmation prompt. Ignored by `validate` and `plan`. |

`auto-approve` defaults to `false` on purpose. An apply step that auto-approves unless told
otherwise is a footgun in precisely the environment it runs in.

There are no outputs yet. `has-changes`, the create/update/delete counts, and a rendered plan for
posting as a PR comment all need the CLI's `--format json` and `--format markdown`, which arrive in
its 0.2 milestone.

## Why the version is pinned

`uses: StackMade/gtm-as-code-action@v0` checks *this* repository out at that tag. There is no build
step and no `node_modules` in that checkout, so the action installs the CLI from npm instead of
running any source it ships with. Two independent version lines therefore exist: this action's tags,
and the CLI's npm releases.

If the action ran `@latest`, `@v0` would pin nothing, and one breaking CLI release would break every
consumer who had correctly pinned a major version. So the `version` input carries a hard-pinned
default, bumped deliberately when a new tag of this action is cut, and it accepts only an exact
version. A range or a dist-tag is rejected before anything is installed. Overriding the default with
a different exact version is supported and occasionally useful.

This is also why the action lives in its own repository instead of alongside the CLI. One git
repository has one tag namespace, and `npm version` in the CLI repo would write into it.

## Development

The argument building lives in `run.sh` rather than inline in `action.yml` so it can be exercised
directly. `./test.sh` runs it against a stub `npx` and asserts what would have been invoked,
including that an unrecognised `command` is rejected instead of reaching a shell. CI runs the same
script.

There is no end-to-end test yet. One is possible now that the CLI is on npm: a job that uses this
action against a fixture config and asserts on `validate`. That is the obvious next addition.

## Releasing

Tag `vX.Y.Z`. `.github/workflows/release.yml` then force-moves the `vX` tag onto it, which is the
convention consumers expect. Bump the pinned `version` default in `action.yml` in the same commit
whenever the CLI has published a new release.

## License

MIT, see [LICENSE](./LICENSE).
