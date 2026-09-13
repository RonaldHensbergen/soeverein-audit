# Copilot Instructions

## What this repo is

A single-purpose Bash tool (`repo-audit.sh`) that scans an arbitrary target
repository for dependency manifests, vendor/cloud references, and
vendor-lock-in risk indicators, then writes a plain-text report. There is no
build system, package manager, or test suite — the entire project is one
script plus the README.

## Running / validating changes

There is no build, lint, or test tooling in this repo. Validate changes by
running the relevant script directly against a repo (itself, or any other
checked-out project) and inspecting the generated report:

```bash
./repo-audit.sh                         # audits cwd, writes dependency-audit.txt
./repo-audit.sh /path/to/repo report.txt

./audit-cloud-sdk.sh   [path] [basename]  # writes <basename>.txt + .json
./audit-iac-lockin.sh  [path] [basename]
./audit-saas.sh        [path] [basename]
./audit-licenses.sh    [path] [basename]  # uses `syft` for SBOM data if installed

bash -n <script>.sh                     # syntax-check after edits
```

`*.txt` and `*-audit.json` report files are gitignored — don't commit
generated reports.

## Structure and conventions

- `repo-audit.sh` is self-contained (its own `section()`/`run_scan()`
  inline) and predates the shared library — leave it as-is unless directly
  changing it.
- The four `audit-*.sh` scripts source `lib/scan-common.sh`, which provides:
  - `scan_init TITLE ROOT TXT JSON` — resets/opens the report files and
    prints the header.
  - `scan_run TITLE PATTERN [grep-args...]` — greps with standard excludes
    (`.git`, `node_modules`, `venv`, `.venv`, `dist`, `build`), appends
    matches (or "No matches found.") to the text report, and appends a
    matching JSON section (skipped if `jq` isn't installed) to a temp JSONL
    file.
  - `scan_add_json_section JSON_STRING` — for injecting a custom JSON
    section (e.g. `audit-licenses.sh`'s `syft`-derived data) instead of one
    produced by `scan_run`.
  - `scan_finalize` — assembles the final `{title, repository,
    generated_at, sections: [...]}` JSON report from the temp JSONL file.
- All new audit scripts follow the same CLI shape: `[path-to-repo]
  [report-basename]`, writing `<basename>.txt` and `<basename>.json`. When
  adding a new audit category, add a `scan_run` call to the relevant script
  (or a new script following this same shape) rather than introducing a
  different mechanism.
- Each `audit-*.sh` script resolves its own real path with `readlink -f
  "${BASH_SOURCE[0]}"` before computing `SCRIPT_DIR` (needed to find
  `lib/scan-common.sh`) — this must be preserved so the scripts keep working
  when symlinked onto `PATH` via `add-to-path.sh`.
- Patterns are single-quoted extended-regex (`grep -E`) alternations; keep
  new patterns case-consistent with the category (vendor names lowercase,
  since matching is case-sensitive unless a pattern explicitly adds
  character classes for case).
- `repo-audit.sh`'s summary checklist and the license/SBOM logic in
  `audit-licenses.sh` are intentionally static/fixed content, not generated
  from scan results.
