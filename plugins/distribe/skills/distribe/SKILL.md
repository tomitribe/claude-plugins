---
name: distribe
description: "Reference for the Tomitribe Distribe CLI — Jenkins orchestration, S3 release distribution, Zendesk publishing, CVE customer fan-out. TRIGGER when: user runs `$DISTRIBE` / `distribe` commands, references `jenkins trigger`, `cve customers`, `zendesk publish`, `s3 changelog`, or asks how to publish a release / trigger a PR build / fan out CVE customers. DO NOT TRIGGER when: working with raw `curl` against Jenkins/Nexus, with the AWS CLI directly, or with Zendesk's web UI."
---

# Distribe — Tomitribe Release Distribution CLI

Internal CLI used across the release / CVE / customer-notification pipeline.

**Repo:** `~/devs/jeanouii/tomitribe/distribe` (built with Maven, multi-module).

## Locating the binary

Distribe ships as two executables. **`distribe-cli`** is the full one used in scripts. `distribe-lite-cli` is a smaller variant for restricted environments.

```bash
# Resolve once per session; fall back to a known path if $DISTRIBE is unset
DISTRIBE="${DISTRIBE:-$HOME/devs/jeanouii/tomitribe/distribe/distribe-cli/target/distribe}"
[ -x "$DISTRIBE" ] || { echo "Distribe not built. Run mvn install in ~/devs/jeanouii/tomitribe/distribe."; exit 1; }
```

If the binary is missing, the user has not built distribe yet — ask before silently running `mvn install` (it's a long build).

## The `--config` flag

Every command takes `--config=<name>`. The configs live in `~/.distribe/config` (managed via `distribe config`). The canonical current config is **`default-0.74`** (matches distribe `0.74-SNAPSHOT`). The `usa-0.74` variant is used when fanning out to USA support customers. Older configs (`default`, `default-0.73`) exist for legacy compatibility.

```bash
$DISTRIBE config list        # show all configured profiles
```

When unsure, default to `--config=default-0.74` — that's what the team uses.

---

## Top-level commands (subcommands listed below)

| Command       | Purpose                                                                 |
|---------------|-------------------------------------------------------------------------|
| `activity`    | Track / record release activity for reporting                           |
| `apigateway`  | AWS API Gateway helpers                                                 |
| `config`      | Manage local distribe profiles (`add`, `set`, `list`, `remove`, `import`, `export`) |
| `customer`    | Customer / subscription operations (list, releases, mappings)           |
| `cve`         | CVE customer fan-out, notifications, ticket bookkeeping                 |
| `github`      | GitHub helpers (issues, PRs)                                            |
| `jenkins`     | Trigger / inspect Tomitribe CI jobs                                     |
| `job`         | Internal job orchestration (long-running async work)                    |
| `jwt` / `token` | Auth token operations                                                 |
| `lambda`      | AWS Lambda fan-out helpers                                              |
| `license`     | License generation                                                      |
| `nexus`       | Nexus repository operations                                             |
| `param`       | SSM parameter helpers                                                   |
| `patch`       | Apply patches across products                                           |
| `reporting`   | Generate activity reports                                               |
| `s3`          | S3 release distribution, changelog, hashes                              |
| `sns`         | SNS notification helpers                                                |
| `stripe`      | Stripe billing helpers                                                  |
| `weaver`      | Bytecode weaving runner                                                 |
| `zendesk`     | Zendesk article publishing, ticket creation, organization management    |

Use `$DISTRIBE <command>` (no args) to list its subcommands; `$DISTRIBE <command> <subcommand>` to see options.

---

## `jenkins` — CI orchestration

```bash
# Trigger a PR build (manual-pr-trigger job)
$DISTRIBE jenkins trigger <product> <branch> --pr=<NUMBER> --config=default-0.74
# Trigger a stable branch build (post-merge smoke)
$DISTRIBE jenkins trigger <product> <branch> --stable --config=default-0.74

# Poll a build (DO NOT pass positional args, jenkins status uses named flags)
$DISTRIBE jenkins status --product=<product> --branch=<branch> --pr=<NUMBER> --config=default-0.74
$DISTRIBE jenkins status --url=<BUILD_URL>                                  --config=default-0.74
$DISTRIBE jenkins status --build=<BUILD_NUMBER> --product=<product> --branch=<branch> --config=default-0.74

# Console output of a specific build
$DISTRIBE jenkins console --url=<BUILD_URL> --config=default-0.74

# Read / write job config XML
$DISTRIBE jenkins get-config <job-path> --config=default-0.74
$DISTRIBE jenkins set-config <job-path> < new.xml --config=default-0.74
```

**`<product>` is the Jenkins folder name** (e.g. `tomcat`, `tomee`, `activemq`).
**`<branch>` is the Jenkins job basename**, which for Tomcat starts with `tomcat-` even when the git branch doesn't:

| Product | Short id | Git branch          | Jenkins branch name (what `--branch` wants) |
|---------|----------|---------------------|---------------------------------------------|
| Tomcat  | 8.5      | `8.5.x-TT.x`        | `tomcat-8.5.x-TT.x`                         |
| Tomcat  | 9.0      | `9.0.x-TT.x`        | `tomcat-9.0.x-TT.x`                         |
| Tomcat  | 10.0     | `tomcat-10.0.x-TT.x`| `tomcat-10.0.x-TT.x`                        |
| Tomcat  | 10.1     | `tomcat-10.1.x-TT.x`| `tomcat-10.1.x-TT.x`                        |
| Tomcat  | 11.0     | `11.0.x-TT.x`       | `tomcat-11.0.x-TT.x`                        |

`trigger` is **positional** (`trigger <product> <branch>`); `status` and `console` are **named flags** (`--product`, `--branch`, `--pr`, `--url`). Mixing them up returns `Excess arguments: ...`.

---

## `cve` — CVE customer fan-out

```bash
# Build the customer fan-out from a CVE-tracking issue (parses body for product+branches+CVE-IDs)
$DISTRIBE cve customers <ISSUE_NUMBER>  --config=default-0.74

# Override the branches inferred from the issue
$DISTRIBE cve customers <ISSUE_NUMBER>  --branches=8.0,9.0,10.0 --config=default-0.74

# Override CVE IDs / versions (used when the issue body doesn't carry them in the canonical shape)
$DISTRIBE cve customers <ISSUE_NUMBER>  --cve-ids-override=CVE-2026-42402,CVE-2026-42403 --versions=8.0.17-TT.19 --config=default-0.74

# Drive the post-release flow once binaries are uploaded:
$DISTRIBE cve notify-new-cve   --cve-dir=<dir created by `cve customers`>     --config=default-0.74
$DISTRIBE cve notify-download  --branch=<branch> --version=<released TT version> --config=default-0.74
$DISTRIBE cve solve-tickets    --cve-dir=<dir>   --config=default-0.74
$DISTRIBE cve download-customers --cve-dir=<dir> --config=default-0.74
```

`cve customers` produces a working directory under `processed/<issue-id>/` (in the cve repo) with the resolved customer list, per-branch publish lists, and a `meta.properties` file used by the subsequent `notify-*` commands.

---

## `s3` — Release distribution

```bash
# Publish a changelog text file for a release (no Zendesk side effects)
$DISTRIBE s3 changelog <product> <version> <changelog.txt> --config=default-0.74

# Push binaries from local Nexus checkout to S3 support-deliverable bucket
$DISTRIBE s3 distribute <product> <version> ...           --config=default-0.74

# Generate / refresh SHA hashes for a release
$DISTRIBE s3 generate-hashes <product> <version>          --config=default-0.74

# List release artefacts already in S3
$DISTRIBE s3 list-release <product> <version>             --config=default-0.74
$DISTRIBE s3 releases <product>                           --config=default-0.74

# Per-customer batch distribution (Lambda fan-out)
$DISTRIBE s3 batch-distribute  <product> <version> ...    --config=default-0.74
$DISTRIBE s3 batch-distribute-status <job-id>             --config=default-0.74
```

`download-changelog` and `archive` are read-only helpers for inspecting historical state.

---

## `zendesk` — Customer-facing publishing

```bash
# Publish (or re-publish with --overwrite) the download page for a release
$DISTRIBE zendesk publish <product> <version> --customer-id=<ID> [--customer-id=<ID> ...] --config=default-0.74
$DISTRIBE zendesk publish <product> <version> --customers=<csv-or-txt> --changelog=<file>  --config=default-0.74
$DISTRIBE zendesk publish <product> <version> --customers=<file> --overwrite --skip-notification --config=default-0.74

# Subscription / paginated page management
$DISTRIBE zendesk publish-subscription-page <product> <version> ... --config=default-0.74
$DISTRIBE zendesk list-download-pages <customer-id> --config=default-0.74

# Notification side (after publish, send the ticket / article notification)
$DISTRIBE zendesk notify <product> <version> --customers=<file>     --config=default-0.74

# Organization management
$DISTRIBE zendesk organizations
$DISTRIBE zendesk add-new-organization <name>
$DISTRIBE zendesk get-missing-orgs / fix-missing-orgs
```

Useful flags:
- `--overwrite` — re-publish an existing download page (default: refuses to clobber)
- `--skip-notification` — publish without sending the notification ticket (useful when notifying separately later)
- `--print-body-only` — render and print the body without making any API call (dry run)
- `--variant=usa` — generate the USA-localised variant alongside the default

The changelog file passed to `--changelog=` **must be valid markdown**, and headings are level-promoted by the markdown parser (see `LeveledHeading` in `distribe-core`). Don't paste random HTML.

---

## `config` — Profile management

```bash
$DISTRIBE config list                       # show all profiles
$DISTRIBE config set <name> --<key>=<val>   # set/update a key on a profile
$DISTRIBE config add <name> --<key>=<val>   # create a new profile
$DISTRIBE config export <name>              # dump a profile as YAML
$DISTRIBE config import <file>              # restore from YAML
$DISTRIBE config remove <name>
```

Profiles carry credentials for AWS, Nexus, Salesforce, Zendesk, Jenkins, GitHub. Don't paste keys into the chat — refer the user to `config set` instead.

---

## Common Gotchas

### 1. Don't fall back to `curl` for Jenkins

`curl --user $USER:$TOKEN https://ttci.tomitribe.com/...` returns **HTTP 401** even with the right credentials — the CI uses CSRF crumbs that distribe handles internally. Always use `$DISTRIBE jenkins ...`.

### 2. `jenkins status` is named-args, `jenkins trigger` is positional

```bash
$DISTRIBE jenkins trigger tomcat tomcat-8.5.x-TT.x --pr=67 --config=default-0.74   # OK
$DISTRIBE jenkins status  --product=tomcat --branch=tomcat-8.5.x-TT.x --pr=67 ...   # OK
$DISTRIBE jenkins status  tomcat tomcat-8.5.x-TT.x --pr=67 ...                      # FAIL: "Excess arguments"
```

### 3. Tomcat git branch ≠ Jenkins branch

For Tomcat 8.5 / 9.0 / 11.0 the git branch is `<X.Y>.x-TT.x` but the Jenkins job is prefixed `tomcat-<X.Y>.x-TT.x`. Always pass the Jenkins-side name to `--branch=`. 10.0 / 10.1 happen to coincide.

### 4. `--config` is not optional in scripted use

The default profile (`default`) is the *legacy* one. For current work always pass `--config=default-0.74` (or `usa-0.74` for USA-region fan-out). Leaving `--config` off lands silently on the legacy profile.

### 5. `cve customers` writes to the cve repo working tree

The command creates `processed/<issue-id>/` with TSV state files, publish lists, and `meta.properties`. Don't run it on the wrong cve checkout — it expects to be invoked from `~/devs/jeanouii/tomitribe/cve`.

### 6. `zendesk publish` is idempotent only with `--overwrite`

Without `--overwrite` it refuses to clobber an existing download page (returns the existing article ID). With `--overwrite` it rebuilds the page. `--skip-notification` is essential when re-publishing — otherwise customers get spammed with duplicate notifications.

### 7. `s3 batch-distribute` is async — poll with `batch-distribute-status`

The batch command kicks off a Lambda fan-out and returns immediately with a job id. Local feedback says "queued", not "done". Poll until status reports `COMPLETED`.

---

## Typical workflows

### Trigger a Tomcat PR build after pushing

```bash
git push origin HEAD:refs/heads/<git-branch>          # in a worktree
$DISTRIBE jenkins trigger tomcat <jenkins-branch> --pr=<PR_NUMBER> --config=default-0.74
# → returns getBuild URL; poll:
$DISTRIBE jenkins status --product=tomcat --branch=<jenkins-branch> --pr=<PR_NUMBER> --config=default-0.74
```

### CVE customer fan-out end-to-end (read-only inspection)

```bash
$DISTRIBE cve customers <ISSUE>  --config=default-0.74
# → produces processed/<issue>/ with publish-lists/*.txt + meta.properties
ls processed/<issue>/publish-lists/
cat processed/<issue>/meta.properties
```

### Re-publish a Zendesk download page

```bash
$DISTRIBE zendesk publish <product> <version> \
    --customers=processed/<issue>/publish-lists/<version>-default.txt \
    --changelog=processed/<issue>/changelog-<version>.md \
    --overwrite --skip-notification \
    --config=default-0.74
```

### Stable-branch build after a Tomitribe release

```bash
$DISTRIBE jenkins trigger tomcat <jenkins-branch> --stable --config=default-0.74
```
