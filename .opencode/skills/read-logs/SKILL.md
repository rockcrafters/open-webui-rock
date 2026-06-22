---
name: read-logs
description: >
  Parses the Rockcraft detailed log file to identify the failing lifecycle part,
  failing step, error category, LXD instance name, and a concrete proposed fix
  for rockcraft.yaml or project files. Covers all 10 build-time error categories:
  missing-package, missing-chisel-slice, source-fetch-failure,
  override-scriptlet-error, organize-mismatch, permission-error,
  craftctl-misuse, cyclic-dependency, plugin-build-failure, and unknown. Use
  after read-console has provided the log file path.
  WHEN: parse rockcraft log, read build log, identify build error, diagnose
  rockcraft failure, classify rockcraft error, find lxd instance name,
  rockcraft log analysis, determine fix for rockcraft build.
license: Apache-2.0
metadata:
  author: Canonical/rockcrafters
  version: "1.3.0"
  summary: Parse a Rockcraft log file, classify the build error into one of 10 categories, and produce a structured fix diagnosis.
  tags:
    - canonical
    - rockcraft
    - oci
    - debugging
    - build
    - lxd
---

## Purpose

Read and parse the detailed Rockcraft log file to produce a structured
diagnosis:

```
{
  step:               PULL | OVERLAY | BUILD | STAGE | PRIME
  part:               <part-name>
  error_category:     <one of the 10 categories below>
  proposed_fix:       <human-readable description of the exact change needed>
  lxd_instance_name:  <instance name, or "unknown">
}
```

## Reading the log file

Read the full contents of the log file at `log_file_path` from `read-console`.
The log is structured with ISO-8601 timestamped lines and clear markers for
each lifecycle step and part, e.g.:

```
2024-01-15 12:34:56,789 craft_parts.executor  Starting step BUILD for part 'my-part'
2024-01-15 12:34:57,001 craft_parts.executor  :: error :: ...
```

## Extract the LXD instance name

Scan the entire log for lines matching any of these patterns:

```
Starting container rockcraft-
lxc launch .* rockcraft-
lxc exec rockcraft-
Created instance rockcraft-
```

Extract the instance name using this pattern:

```
rockcraft-[a-z0-9]+(?:-[a-z0-9]+)*
```

The instance name is typically of the form `rockcraft-<rock-name>-<arch>`,
e.g. `rockcraft-my-rock-name-amd64`.

Store as `lxd_instance_name`. If no match is found, set to `"unknown"`.

This value is **required** by the `interactive-debug-shell` skill — always
attempt to extract it.

## Identify the failing step and part

Look for these sentinel lines:

```
Failed to run '<step>' for part '<part>'
:: error ::
Error in step <STEP> for part '<part>'
craft_parts.errors
```

Extract `step` (PULL / OVERLAY / BUILD / STAGE / PRIME) and `part` (the part
name string from `rockcraft.yaml`).

If multiple parts fail, record the **first** failure — subsequent failures are
often cascading effects.

## Intermediate directory inspection (host-side)

For BUILD step failures or later, inspect these paths on the host (relative
to the `rockcraft.yaml` working directory) to understand what was actually
produced before the failure:

```bash
ls parts/<part-name>/src/       # sources after PULL
ls parts/<part-name>/build/     # build working directory
ls parts/<part-name>/install/   # artefacts after BUILD (CRAFT_PART_INSTALL)
ls stage/                       # assembled output after STAGE
ls prime/                       # final payload after PRIME
```

Use findings from these directories to refine the `proposed_fix`, especially
for `organize-mismatch` errors.

## General reference tools

Use these tools throughout diagnosis and fix generation whenever the relevant
information is needed.

### Ubuntu codename ↔ version lookup

Whenever reasoning about Ubuntu release names (e.g. matching a `base:
ubuntu@24.04` to its codename "Noble", or verifying which packages exist in a
given suite), consult the local data file:

```bash
cat /usr/share/distro-info/ubuntu.csv
```

The CSV contains columns: `version`, `codename`, `series`, `created`,
`release`, `eol`, `eol-server`. Use `version` and `codename` columns to map
between numeric versions (`24.04`) and release codenames (`noble`).

If the file is not present, install the package first:

```bash
sudo apt-get install -y distro-info
```

Then retry. Do **not** guess or hardcode codename↔version mappings from
memory — the CSV is the authoritative source.

### Version consistency check

**Run this check on every diagnosis, regardless of error category.**

Compare the `version` field at the top of `rockcraft.yaml` against the actual
version of the primary content being packed into the rock.

### Granularity rule for `version:`

The `version:` field **must be set to at most the minor version** (`XX.YY`),
not the full patch version (`XX.YY.ZZ`). Exception: when `source-tag:` carries
a full semver (e.g. `v1.2.3`), match it exactly.

---

## Error taxonomy

Apply the **first matching category** from the list below.
If none match, set `error_category: unknown`.

---

### Category 1 — `missing-package`

**Log patterns:**
```
E: Unable to locate package <pkg>
E: Package '<pkg>' not found
Couldn't find package <pkg>
```

**Fix strategy:** Correct the package name in `build-packages` or
`stage-packages`. Verify against `https://packages.ubuntu.com`.

---

### Category 2 — `missing-chisel-slice`

**Log patterns:**
```
error: no slice named <pkg_slice>
could not find slice <name>
chisel: unknown package
```

**Fix strategy:** Correct the `<package>_<slice>` format. Check
`https://github.com/canonical/chisel-releases` for the target Ubuntu release.

---

### Category 3 — `source-fetch-failure`

**Log patterns:**
```
Failed to pull part
git clone .* failed
fatal: repository '...' not found
Unable to connect to
Could not resolve host
```

**Fix strategy:** Verify `source` URL, `source-branch`/`source-tag`/`source-commit`.
Consider `source-depth: 1` for large repos.

---

### Category 4 — `override-scriptlet-error`

**Log patterns:**
```
Failed to run 'override-build'
Failed to run 'override-pull'
+ <command>
<command>: command not found
Exited with code <N>
```

**Fix strategy:** Identify the failing command from `+`-prefixed trace lines.
Add missing `build-packages`. Add `set -ex` as the first scriptlet line.
Fix paths using `$CRAFT_*` variables.

---

### Category 5 — `organize-mismatch`

**Log patterns:**
```
Failed to organize
No such file or directory.*organize
```

**Fix strategy:** Inspect `parts/<part-name>/install/`. Update `organize:` source
keys to match actual output paths.

---

### Category 6 — `permission-error`

**Log patterns:**
```
Permission denied
Operation not permitted
chown: changing ownership of
```

**Fix strategy:** Use valid UID/GID (e.g. `_daemon_` = 584792). Fix `mode` to
valid octal. Verify `path` globs match files in `$CRAFT_PRIME`.

---

### Category 7 — `craftctl-misuse`

**Log patterns:**
```
craftctl: command not found
/bin/sh: craftctl: not found
```

**Fix strategy:** Ensure `craftctl default` only appears inside `override-*`
scriptlets. Verify `plugin:` key is set.

---

### Category 8 — `cyclic-dependency`

**Log patterns:**
```
Cyclic dependency
circular dependency
```

**Fix strategy:** Map all `after:` entries. Remove the entry that closes the cycle.

---

### Category 9 — `plugin-build-failure`

**Log patterns:**
```
make: *** [...] Error <N>
go build: cannot load
npm ERR!
mvn: BUILD FAILURE
```

**Fix strategy:** Scroll past the top-level error to find the root cause.
Add missing `build-packages`. Verify snap versions with `snap info`.

---

### Category 10 — `unknown`

No pattern from categories 1–9 matched. Set `error_category: unknown`.
The calling agent **must** proceed to `interactive-debug-shell` immediately.

---

## Structured output

After analysis, produce:

```
DIAGNOSIS
─────────────────────────────────────────────
step:               <PULL|OVERLAY|BUILD|STAGE|PRIME>
part:               <part-name>
error_category:     <category name>
proposed_fix:       <specific, actionable description>
lxd_instance_name:  <instance name or "unknown">
─────────────────────────────────────────────
```
