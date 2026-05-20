---
name: distribe
description: "Reference for the Tomitribe Distribe CLI — Jenkins orchestration, S3 release distribution, Zendesk publishing, CVE customer fan-out, Nexus/Salesforce/Zendesk integration. TRIGGER when: user runs `distribe` commands, references subcommands like `jenkins trigger`, `cve customers`, `zendesk publish`, `s3 distribute`, `s3 batch-distribute`, `nexus cve-template`, or asks how to publish a release / trigger a PR build / fan out CVE customers. DO NOT TRIGGER when: working with raw `curl` against Jenkins/Nexus, with the AWS CLI directly, or with Zendesk's web UI."
---

# Distribe — Tomitribe Release Distribution CLI

Internal Tomitribe CLI used across the release / CVE / customer-notification pipeline. Built from the `tomitribe/distribe` Maven multi-module project; the fat-jar entry point is `distribe-cli/target/distribe`.

## Discovering commands

Distribe is built on Crest, so the CLI is self-documenting. **Always prefer the built-in help over guessing**:

```bash
distribe help --all                 # flat list of every command + one-line description
distribe help <group>               # subcommands in a group (e.g. distribe help jenkins)
distribe help <group> <subcommand>  # full usage, flags, semantics, examples for one command
```

`distribe help <group> <subcommand>` is the source of truth — it ships with the build and reflects the exact flags compiled in. When unsure of an option or its default, read it from `help` rather than assuming.

## Locating the binary

Distribe ships as two executables in a `distribe` checkout:

- `distribe-cli/target/distribe` — the full CLI used by the release pipeline; this is the one referenced everywhere below as `distribe`.
- `distribe-lite-cli/target/distribe-lite` — a smaller variant for restricted environments.

If the binary is missing, the user has not built distribe yet. Ask before silently running `mvn install` — it's a long build.

## The `--config` flag

Almost every command takes `--config=<name>`. Profiles live under `~/.tribe/distribe/` and are managed via `distribe config`:

```bash
distribe config list                       # show all profiles
distribe config add <name>  --<key>=<val>  # create a new profile
distribe config set <name>  --<key>=<val>  # update a key on a profile
distribe config export <name>              # encrypted dump of a profile
distribe config import <file>              # restore from an exported profile
distribe config remove <name>
```

Profiles carry credentials for AWS, Nexus, Salesforce, Zendesk, Jenkins, GitHub. The CLI default is `--config=default`; teams typically maintain version-suffixed variants (e.g. `default-<distribe-version>`) so the right environment is paired with the right CLI build. **Ask the user which profile to use** rather than assuming. Never paste credentials into chat — refer them to `config set`.

---

## Top-level command groups

| Group         | Purpose                                                                 |
|---------------|-------------------------------------------------------------------------|
| `activity`    | Track / record release activity for reporting                           |
| `apigateway`  | AWS API Gateway helpers                                                 |
| `config`      | Manage local distribe profiles                                          |
| `customer`    | Customer / subscription operations (list, releases, mappings, extend)   |
| `cve`         | CVE customer fan-out, notifications, ticket bookkeeping                 |
| `github`      | GitHub helpers (onboard / sync forks)                                   |
| `jenkins`     | Trigger / inspect / configure Tomitribe CI jobs                         |
| `job`         | Cron-like scheduling of distribe commands                               |
| `jwt`         | Subscription JWT operations                                             |
| `lambda`      | Deploy / promote AWS Lambdas                                            |
| `license`     | License management                                                      |
| `nexus`       | Nexus repository queries + CVE template generation                      |
| `param`       | SSM Parameter Store helpers                                             |
| `patch`       | Patch utilities (e.g. stale-ref detection across poms)                  |
| `reporting`   | GA4 / BigQuery analytics & rollups                                      |
| `s3`          | Release distribution: archive, distribute, changelog, hashes, batch     |
| `sns`         | SNS notification helpers                                                |
| `stripe`      | Stripe billing helpers (coupons, codes, price/product verification)     |
| `token`       | Token generation                                                        |
| `weaver`      | Bytecode weaving runner                                                 |
| `zendesk`     | Download-page articles, tickets, orgs, segments, admin contacts         |

`distribe help <group>` lists the subcommands; `distribe help <group> <subcommand>` shows full options.

---

## `jenkins` — CI orchestration

```bash
# Trigger a PR build (manual-pr-trigger job)
distribe jenkins trigger <product> <branch> --pr=<PR_NUMBER>

# Trigger a stable branch build (post-merge smoke)
distribe jenkins trigger <product> <branch> --stable

# Snapshot a build's status (named flags, NOT positional)
distribe jenkins status --product=<product> --branch=<branch> --pr=<PR>
distribe jenkins status --product=<product> --branch=<branch> --pr=<PR> --build=<N>
distribe jenkins status --url=<full-build-url>
distribe jenkins status --product=<product> --branch=<branch> --pr=<PR> --watch  # poll until done

# Console output for a specific build
distribe jenkins console --url=<BUILD_URL>

# Read / write a job's config.xml
distribe jenkins get-config <job-path>
distribe jenkins set-config <job-path> < new.xml

# Create the standard pair of jobs (stable + manual-pr-trigger) for a new branch
distribe jenkins create-jobs <product> <branch>

# Run stable + manual-PR-trigger in parallel and apply the flaky-comparison matrix
distribe jenkins flaky-compare <product> <branch> --pr=<PR_NUMBER>
```

**Key semantics from `help`**:

- `jenkins trigger` polls the queue until the build URL appears, then returns *synchronously* with both queue and build URLs.
- With `--pr=<N>`, the Jenkins build displayName is also set to `PR #<N> - <PR title>` (fetched via `gh pr view`).
- `jenkins status` defaults to a terse snapshot (result + build-id + queued-at). Add `--watch` to poll up to ~90 minutes for completion plus a test-failure digest with an environmental-vs-test-specific heuristic.
- `jenkins flaky-compare` triggers both jobs in parallel, watches both, and applies the 4-cell decision matrix (stable green / red × PR green / red) automatically — replaces the two-window Jenkins-UI dance.

**Product / branch naming**: `<product>` is the Jenkins folder (e.g. `tomcat`, `tomee`, `activemq`). `<branch>` is the **Jenkins job basename**, which for Tomcat is prefixed `tomcat-` even when the git branch is not:

| Product | Git branch          | Jenkins branch name (what `--branch` wants) |
|---------|---------------------|---------------------------------------------|
| Tomcat  | `8.5.x-TT.x`        | `tomcat-8.5.x-TT.x`                         |
| Tomcat  | `9.0.x-TT.x`        | `tomcat-9.0.x-TT.x`                         |
| Tomcat  | `tomcat-10.0.x-TT.x`| `tomcat-10.0.x-TT.x`                        |
| Tomcat  | `tomcat-10.1.x-TT.x`| `tomcat-10.1.x-TT.x`                        |
| Tomcat  | `11.0.x-TT.x`       | `tomcat-11.0.x-TT.x`                        |

`trigger` is **positional** (`trigger <product> <branch>`); `status` and `console` are **named flags** (`--product`, `--branch`, `--pr`, `--url`). Mixing them up returns `Excess arguments: ...`.

---

## `cve` — CVE customer fan-out

The CVE flow is staged. Stage numbers below mirror the internal CVE process doc.

```bash
# Stage 3 (preparation): read a GitHub issue and build the per-CVE working directory.
# Issue-driven: product, branches, and CVE-IDs are inferred from the issue body.
distribe cve customers <ISSUE_NUMBER>

# Override the inferred branches (subset re-run, or force a branch not yet in the issue)
distribe cve customers <ISSUE_NUMBER> --branches=8.0,9.0,10.0

# Override CVE IDs / versions when the issue body doesn't carry them canonically
distribe cve customers <ISSUE_NUMBER> --cve-ids-override=CVE-2026-42402,CVE-2026-42403 --versions=8.0.17-TT.19

# Override the output directory (default: ./customers-<CVE-ID>)
distribe cve customers <ISSUE_NUMBER> --output-dir=./my-working-dir

# Stage 3 (notification): create Zendesk tickets announcing the CVE
distribe cve notify-new-cve --cve-dir=<working-dir>

# Stage 7: notify the patched binary is downloadable
distribe cve notify-download --branch=<branch> --version=<released TT version>

# Stage 8: close every ticket created earlier in the flow
distribe cve solve-tickets --cve-dir=<working-dir>

# Audit who actually has the binary in their S3 bucket (vs `customers`, which lists ELIGIBLE)
distribe cve download-customers --cve-dir=<working-dir>
```

`cve customers` writes to `./customers-<CVE-ID>/` by default (e.g. `./customers-CVE-2026-42403/`) containing:

- per-tier customer lists (Annual / 3DS / Stripe / USA),
- per-(tier, branch) validation reports — failures land in `_warnings.txt` and block downstream stages,
- `meta.properties` consumed by `notify-new-cve` / `notify-download` / `solve-tickets`,
- a `template.txt` generated via `distribe nexus cve-template --cve=<id>`.

It replaces ~10 manual invocations per CVE (tier filters + per-branch validation + manual template fill).

---

## `nexus` — Repository queries & CVE template

```bash
# Latest releases for ALL default product/branch combinations
distribe nexus cve-template

# Filter to one product / branch
distribe nexus cve-template --product=tomee
distribe nexus cve-template --product=tomee --branch=8.0

# Auto-fill the description from NVD using --cve
distribe nexus cve-template --cve=CVE-2026-42403
distribe nexus cve-template --cve=CVE-2026-42403 --product=tomee

# Verbose: show source, candidate versions, priority used to pick "latest"
distribe nexus cve-template --verbose=true

# Latest release for an ad-hoc product/branch (also honours Maven Central)
distribe nexus latest-release --product=activemq --branch=23.8
distribe nexus latest-release --product=activemq --branch=23.8 --useMavenCentral=true

# Download an artifact + version from Nexus to a local directory
distribe nexus download <product> <version> <directory>
```

If a default branch is missing from `cve-template`, the recommended fix is to add it to `NexusCommand.java` in `distribe-core`; `nexus latest-release` is the no-code-change workaround.

---

## `s3` — Release distribution

```bash
# Distribute a binary already in the archive to a set of customer buckets (sync gate)
distribe s3 distribute <product> <version> --customers=<file>
distribe s3 distribute <product> <version> --customer-id=<ID> [--customer-id=<ID> ...]

# Batched per-customer fan-out via SQS + Lambda (no webhook; multi-customer CVE flow)
distribe s3 batch-distribute <product> <version> --customer-id=<ID> [--customer-id=<ID> ...]
distribe s3 batch-distribute <product> <version> --customer-id=<ID> --correlation-id=<tag>
distribe s3 batch-distribute <product> <version> --customer-id=<ID> --force        # re-weave even if present
distribe s3 batch-distribute-status <correlation-id-or-job-id>                       # poll status

# Upload a changelog text file for an existing release
distribe s3 changelog <product> <version> <changelog.txt>

# Backfill cumulative changelog.txt for every archived version of a (product, branch, variant)
distribe s3 backfill-cumulative-changelog <product> <branch> [--variant=<name>]

# Download the cumulative changelog from the archive to a local file
distribe s3 download-changelog <product> <version> <output-file>

# Read-only inspection of the archive
distribe s3 archive <product> <version>
distribe s3 list-release <product> <version>
distribe s3 releases <product>
distribe s3 generate-hashes <product> <version>
```

**Important distinction**:

- `s3 distribute` triggers the classic single-meta-file flow used by the stripe / promo-code path (one customer per webhook). Emails `downloads@tomitribe.com` at start and end — don't publish to Zendesk before the `Distribution Success` email arrives.
- `s3 batch-distribute` queues one SQS message *per customer* on `distribe-batch-distribute-queue` for the multi-customer CVE workflow. No pre-filter, no webhook; idempotency is enforced Lambda-side via an S3 HEAD on the target bucket. Pass `--force` to re-weave existing entries.

`--customers=<file>` lines are Salesforce Account IDs (start with `001…`); other lines (headers, comments starting `#`, blank lines) are safely ignored.

---

## `zendesk` — Customer-facing publishing

```bash
# Publish download pages (Articles). Customer set: --customer-id (repeat) or --customers=<file>;
# falling back to whoever has the release in their S3 download area.
distribe zendesk publish <product> <version> --customer-id=<ID> [--customer-id=<ID> ...]
distribe zendesk publish <product> <version> --customers=<file> --changelog=<file>
distribe zendesk publish <product> <version> --customers=<file> --overwrite --skip-notification
distribe zendesk publish <product> <version> --customers=<file> --print-body-only    # dry run
distribe zendesk publish <product> <version> --customers=<file> --variant=usa        # localised variant

# Search Zendesk for download pages already published for a customer
distribe zendesk list-download-pages <customer-id>

# Subscription page management
distribe zendesk publish-subscription-page <product> <version> ...

# Notify customers after pages are published (adds ONE comment per matched ticket)
distribe zendesk notify <product> <version> --customers=<file>

# Tickets
distribe zendesk create-ticket   --customers=<file> --subject=<...> --body=<file>
distribe zendesk update-ticket   --query=<search>    --status=solved
distribe zendesk solve-tickets   --query=<search>

# Organizations & admin contacts
distribe zendesk organizations
distribe zendesk add-new-organization <name>
distribe zendesk get-missing-orgs    /    distribe zendesk fix-missing-orgs
distribe zendesk list-admin-contacts
```

**Behavioural notes**:

- `zendesk publish` is **idempotent only with `--overwrite`** — without it, existing download pages are skipped (existing article IDs returned). With `--overwrite`, pages are rebuilt **but the article ID stays stable** so links don't churn.
- `--skip-notification` is essential when re-publishing; otherwise customers get duplicate notifications.
- `--allow-empty` lets the command succeed even if the customer set resolves to zero.
- Changelog files passed to `--changelog=` use a markdown-like format: `#` headings (no nesting), paragraphs separated by blank lines, dash-prefixed bullets (no nesting), four-space code blocks.

---

## `customer` — Salesforce-backed customer ops

```bash
# Listings & mapping
distribe customer list
distribe customer mapping                          # Salesforce ↔ Zendesk org mapping
distribe customer users                            # Zendesk users for the SF customer list

# Per-customer release ops
distribe customer add-release    <product> <version> <customer-id>
distribe customer remove-release <product> <version> <customer-id>
distribe customer list-release   <product> <version> <customer-id>
distribe customer releases       <customer-id>
distribe customer download-links <customer-id>
distribe customer allowed        <product> <version>
distribe customer validate-customers <product> <version> --customer-id=<id> [--customer-id=<id> …]  # eligibility + 3DS coherence

# Subscription overrides
distribe customer extend         <customer-id> --date=<YYYY-MM-DD>
distribe customer unextend       <customer-id>
distribe customer extension      <customer-id>
distribe customer generate-subscription <customer-id> ...
distribe customer admin-contacts-summary
```

Customer IDs are Salesforce Account IDs (`001…`).

---

## `lambda` — Deploy & promote

```bash
distribe lambda deploy        <lambda-name> <jar>          # deploy a new version
distribe lambda deploy-layer  <layer-name>  <zip>
distribe lambda promote       <lambda-name> <version> --alias=<env>
```

`lambda deploy` embeds the matching `~/.tribe/distribe/<lambda-name>.properties` into the jar before upload — keep those files in sync.

---

## Other useful groups

```bash
# Patch utilities — detect stale <product>-X.Y.Z-TT.N-SNAPSHOT literals in poms
distribe patch check-stale-refs [--fix]

# Reporting (GA4 + Salesforce + BigQuery)
distribe reporting downloads
distribe reporting licences-accepted
distribe reporting audit-instances
distribe reporting list-instances-running
distribe reporting compute-empty-branches      # one-shot recomputation

# Job scheduler (cron-like wrapping of distribe commands)
distribe job create / list / get / delete

# Stripe billing
distribe stripe list-prices / list-products / list-coupons / list-codes
distribe stripe verify-products-prices

# Parameter Store
distribe param list / store / delete / list-system-properties

# Weaver (bytecode instrumentation for customer-bound binaries)
distribe weaver weave / get-weaving-artifacts
```

---

## Common Gotchas

### 1. Don't fall back to `curl` for Jenkins

`curl --user $USER:$TOKEN https://ttci.tomitribe.com/...` returns **HTTP 401** even with the right credentials — the CI uses CSRF crumbs that distribe handles internally. Always go through `distribe jenkins …`.

### 2. `jenkins trigger` is positional, `jenkins status` is named-args

```bash
distribe jenkins trigger tomcat tomcat-8.5.x-TT.x --pr=67          # OK
distribe jenkins status  --product=tomcat --branch=tomcat-8.5.x-TT.x --pr=67   # OK
distribe jenkins status  tomcat tomcat-8.5.x-TT.x --pr=67          # FAIL: "Excess arguments"
```

### 3. Tomcat git branch ≠ Jenkins branch

For Tomcat 8.5 / 9.0 / 11.0 the git branch is `<X.Y>.x-TT.x` but the Jenkins job is prefixed `tomcat-<X.Y>.x-TT.x`. Always pass the Jenkins-side name to `--branch=`. 10.0 / 10.1 happen to coincide.

### 4. `--config` matters

The CLI default is `--config=default`, which is usually the *legacy* profile. Most teams maintain version-suffixed variants (e.g. `default-<distribe-version>`, plus `usa-…` for the USA fan-out). When in doubt, ask which profile to use rather than dropping `--config` silently.

### 5. `s3 distribute` vs `s3 batch-distribute`

They are **not interchangeable**. `s3 distribute` uses the classic synchronous flow with a `distribute.meta` SQS trigger and emails on completion — required for the stripe / promo-code path. `s3 batch-distribute` queues per-customer SQS messages for the multi-customer CVE flow and returns immediately; poll with `s3 batch-distribute-status`. Idempotency on `batch-distribute` is per-customer Lambda-side; use `--force` to re-weave.

### 6. `zendesk publish` is idempotent only with `--overwrite`

Without `--overwrite`, existing pages are skipped. With `--overwrite`, content is rebuilt but the article ID stays stable so download links don't break. Always pair `--overwrite` with `--skip-notification` unless you want every customer re-pinged.

### 7. `zendesk publish` changelog format is *not* full markdown

It's a markdown-*like* shape (see the help text): single-level headings (`#`), no nested bullets, four-space indented code blocks. Don't paste arbitrary HTML or GFM extras.

### 8. `cve customers` writes to `./customers-<CVE-ID>/` by default

Default working dir is `./customers-<CVE-ID>/` (resolved from the issue title, e.g. `./customers-CVE-2026-42403/`). Override with `--output-dir=<path>` when needed. Validation failures populate `_warnings.txt` and block downstream stages until the SF data is fixed or the file is manually emptied.

### 9. `customer` files (`--customers=<file>`) ignore non-001 lines

Lines that don't start with `001` (Salesforce Account ID prefix) are silently ignored — comments (`#`), headers, and blanks are safe. Don't over-engineer the file format.

---

## Typical workflows

### Trigger a Tomcat PR build after pushing

```bash
git push origin HEAD:refs/heads/<git-branch>
distribe jenkins trigger tomcat <jenkins-branch> --pr=<PR_NUMBER>
distribe jenkins status  --product=tomcat --branch=<jenkins-branch> --pr=<PR_NUMBER> --watch
```

### Decide if a flaky CI run is the patch's fault

```bash
distribe jenkins flaky-compare tomcat <jenkins-branch> --pr=<PR_NUMBER>
# Exits 0 (clean / flaky upstream / fix) or 2 (PATCH IS THE CAUSE)
```

### CVE customer fan-out, end to end

```bash
distribe cve customers <ISSUE_NUMBER>
ls customers-<CVE-ID>/
cat customers-<CVE-ID>/meta.properties
# (operator inspects _warnings.txt, fixes data if needed)
distribe cve notify-new-cve  --cve-dir=customers-<CVE-ID>/
# ... after binaries are released ...
distribe s3 batch-distribute <product> <version> --customer-id=001…  --correlation-id=cve-<id>
distribe s3 batch-distribute-status cve-<id>
distribe cve notify-download --branch=<branch> --version=<TT version>
distribe cve solve-tickets   --cve-dir=customers-<CVE-ID>/
```

### Re-publish a Zendesk download page without notifying

```bash
distribe zendesk publish <product> <version> \
    --customers=customers-<CVE-ID>/publish-lists/<version>-default.txt \
    --changelog=customers-<CVE-ID>/changelog-<version>.md \
    --overwrite --skip-notification
```

### Generate a CVE notification template auto-filled from NVD

```bash
distribe nexus cve-template --cve=CVE-2026-42403 --product=tomee --branch=8.0
```

### Stable-branch build after a Tomitribe release

```bash
distribe jenkins trigger tomcat <jenkins-branch> --stable
```