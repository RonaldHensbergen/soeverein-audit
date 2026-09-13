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
