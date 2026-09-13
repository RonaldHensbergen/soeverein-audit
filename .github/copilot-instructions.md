# Copilot Instructions

## What this repo is

A single-purpose Bash tool (`repo-audit.sh`) that scans an arbitrary target
repository for dependency manifests, vendor/cloud references, and
vendor-lock-in risk indicators, then writes a plain-text report. There is no
build system, package manager, or test suite — the entire project is one
script plus the README.

## Running / validating changes

There is no build, lint, or test tooling in this repo. Validate changes by
running the script directly against a repo (itself, or any other checked-out
project) and inspecting the generated report:

```bash
./repo-audit.sh                # audits the current directory, writes dependency-audit.txt
./repo-audit.sh /path/to/repo report.txt   # custom target + output file
bash -n repo-audit.sh           # syntax-check the script after edits
```

`*.txt` report files are gitignored — don't commit generated reports.

## Structure and conventions

- `section()` prints a banner and appends to the report via `tee -a`.
- `run_scan(title, pattern, [paths...])` is the core building block: it
  wraps `grep -RInI` with standard excludes (`.git`, `node_modules`, `venv`,
  `.venv`, `dist`, `build`) and prints "No matches found." if the grep finds
  nothing — this fallback matters because the script uses `set -uo pipefail`
  without `-e`, so scans must not fail the whole run on no-match (grep exits
  non-zero on no matches).
- Each audit category (manifests, Docker base images, external URLs, cloud
  vendor references, licensing terms, CI dependencies, install commands,
  private package sources) is its own `run_scan`/`section` block appended in
  sequence to the same report file — when adding a new audit category,
  follow this same pattern rather than introducing a different mechanism.
- Patterns are single quoted extended-regex alternations (`grep -E` style,
  passed as the whole `-I` pattern argument); keep new patterns
  case-consistent with the category (e.g. vendor names lowercase since
  `grep` here is not `-i`).
- The script ends with a fixed "Summary" checklist (classification +
  vendor-lock-in questions) — this is intentionally static output, not
  generated from scan results.
