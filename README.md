# soverein-audit

A generic dependency and vendor-lock-in audit script for any repository.

## Usage

```bash
./repo-audit.sh [path-to-repo] [report-file]
```

Scans a target repository (default: current directory) for:

- Dependency manifests and lockfiles across common ecosystems (npm, pip,
  Poetry, uv, Go, Cargo, Maven/Gradle, .csproj, Gemfile, Dockerfiles).
- Docker base images.
- External URLs and package sources.
- Cloud, vendor, and hosted-service references (AWS, Azure, GCP, GitHub,
  Docker registries, SaaS tools, etc.).
- Potentially proprietary or restricted licensing terms.
- GitHub Actions / hosted CI dependencies.
- Runtime installation commands.
- Potential private/internal package sources.

Writes a plain-text report (default: `dependency-audit.txt`) with a
summary checklist for classifying each match (runtime dependency,
dev-only, CI/CD, optional integration, docs/example, or false positive)
and questions to assess vendor lock-in risk for each real dependency.

## Additional audit scripts

Four more targeted scripts (built on shared helpers in `lib/scan-common.sh`)
each write both a text and a JSON report:

```bash
./audit-cloud-sdk.sh   [path-to-repo] [report-basename]   # default: cloud-sdk-audit
./audit-iac-lockin.sh  [path-to-repo] [report-basename]   # default: iac-lockin-audit
./audit-saas.sh        [path-to-repo] [report-basename]   # default: saas-audit
./audit-licenses.sh    [path-to-repo] [report-basename]   # default: license-audit
```

- **`audit-cloud-sdk.sh`** — greps application code (not just manifests) for
  direct imports/calls into AWS, Azure, GCP, and other hosted-service SDKs
  (Stripe, Twilio, SendGrid, OpenAI, Auth0, Okta, Sentry, Datadog) — the code
  that would need rewriting, not just reconfiguring, to switch providers.
- **`audit-iac-lockin.sh`** — scans Terraform, CloudFormation, ARM/Bicep,
  Pulumi, and Kubernetes manifests for vendor-specific resource types and
  providers.
- **`audit-saas.sh`** — scans CI configs and general repo text for references
  to hosted SaaS products (CI/CD, observability, data/infra, comms/marketing,
  auth, hosting/CDN) that create operational/contractual lock-in.
- **`audit-licenses.sh`** — uses [`syft`](https://github.com/anchore/syft) (if
  installed) to build an SBOM and flag packages with missing or restrictive
  licenses (SSPL, BUSL, Elastic License, etc.); always also greps for
  restrictive licensing keywords and lists `LICENSE`/`COPYING`/`EULA` files.

Each script's JSON report is skipped (text-only) if `jq` is not installed.

## Installing scripts on PATH

```bash
./add-to-path.sh [bin-dir]   # default: ~/.local/bin
```

Symlinks all scripts (without the `.sh` suffix) into `bin-dir` and adds it
to `PATH` via your shell rc file if it isn't already there. Afterwards, run
e.g. `repo-audit`, `audit-cloud-sdk`, `audit-saas`, etc. from any directory.
