---
name: interactive-debug-shell
description: >
  Attaches to the Rockcraft LXD build container for interactive investigation
  when log analysis alone cannot identify the root cause of a build failure.
  Covers launching Rockcraft in debug mode with `rockcraft pack --debug -v`,
  attaching parallel shells to the build container via `lxc --project rockcraft
  exec`, and a systematic 8-point inspection checklist inside the container.
  Use only after the 3-iteration fix loop is exhausted or read-logs returns
  error_category "unknown".
  WHEN: rockcraft debug shell, attach lxd container, lxc exec rockcraft,
  inspect build environment, rockcraft pack debug, interactive build debug,
  deep dive build failure, unknown rockcraft error.
license: Apache-2.0
metadata:
  author: Canonical/rockcrafters
  version: "1.0.0"
  summary: Attach an interactive shell to the Rockcraft LXD build container for hands-on investigation of unresolvable build failures.
  tags:
    - canonical
    - rockcraft
    - oci
    - debugging
    - build
    - lxd
---

## Purpose

Gain interactive access to the Rockcraft LXD build container to inspect the
build environment at the exact point of failure — beyond what the log file
alone can reveal.

## When to invoke

Only invoke this skill when **one of these conditions is true**:

1. `read-logs` returned `error_category: unknown` at any iteration, **OR**
2. All 3 fix-and-retry iterations completed without a successful `rockcraft pack`

Do **not** invoke this skill on the first or second iteration when log analysis
produced a clear, actionable diagnosis.

---

## Step 1 — Launch Rockcraft in debug mode

Run the following command:

```bash
rockcraft pack --debug -v 2>&1 | tee /tmp/rockcraft-debug-console.log
```

With the `--debug` flag, Rockcraft drops into an **interactive shell** inside
the LXD container at the **exact point of failure** — the build environment is
preserved in the state it was in when the error occurred.

The shell prompt will appear in the terminal, typically inside the container at
the failing part's working directory. You are now inside the LXD container.

---

## Step 2 — Identify and record the instance name

The LXD instance name should be available from the `lxd_instance_name` field
produced by the most recent `read-logs` invocation.

If `lxd_instance_name` is `"unknown"`, list all running Rockcraft instances:

```bash
lxc --project rockcraft list
```

Look for an instance in the `RUNNING` state. The name follows the pattern:

```
rockcraft-<rock-name>-<arch>
```

e.g. `rockcraft-my-rock-name-amd64`

Record the instance name — it is needed for Step 3.

---

## Step 3 — Attach a parallel investigation shell

**Without exiting** the debug shell from Step 1, open a second, independent
shell into the same container for parallel inspection:

```bash
lxc --project rockcraft exec <instance_name> -- bash
```

This second shell is your free-roaming investigation environment. The debug
shell from Step 1 preserves the exact failure context (environment variables,
working directory, partial state), while this second shell allows broader
exploration without risk of disrupting it.

---

## Step 4 — Systematic inspection checklist

Work through this checklist inside the parallel shell (Step 3). Document each
finding — they form the basis of the diagnosis.

### 4a. Base image verification

```bash
cat /etc/os-release
```

Confirm the Ubuntu version matches the rock's declared `base`.

### 4b. Lifecycle environment variables

```bash
env | grep -E '^CRAFT_'
```

Verify `CRAFT_PART_SRC`, `CRAFT_PART_BUILD`, `CRAFT_PART_INSTALL`,
`CRAFT_STAGE`, and `CRAFT_PRIME` are all set and point to valid paths.

### 4c. PATH verification

```bash
echo $PATH
```

Verify PATH includes `$CRAFT_PART_INSTALL/usr/bin`, `$CRAFT_PART_INSTALL/bin`,
`$CRAFT_STAGE/usr/bin`, `$CRAFT_STAGE/bin`.

### 4d. Installed package verification

```bash
apt list --installed 2>/dev/null | grep -E '<package_name>'
```

Confirm all `build-packages` were actually installed.

### 4e. Build toolchain verification

```bash
which <build_tool> && <build_tool> --version
```

Confirm cmake, go, python3, make, npm, etc. are present at compatible versions.

### 4f. Source tree inspection

```bash
ls -la "$CRAFT_PART_SRC"
ls -la "$CRAFT_PART_BUILD"
ls -la "$CRAFT_PART_INSTALL"
```

Verify sources are present after PULL. Compare INSTALL contents against
`organize:` keys.

### 4g. Manual reproduction of the failing command

Re-run the failing command manually with maximum verbosity from `$CRAFT_PART_BUILD`.

### 4h. Disk space and resource check

```bash
df -h /
free -h
```

---

## Step 5 — Exit cleanly

1. `exit` the parallel investigation shell (Step 3).
2. `exit` the debug shell (Step 1) — this terminates the Rockcraft debug
   session and stops the LXD container.

Do **not** leave a dangling debug session.

---

## Step 6 — Synthesise findings

```
DEEP DIVE DIAGNOSIS
─────────────────────────────────────────────
root_cause:     <precise description based on direct observation>
proposed_fix:   <specific changes needed in rockcraft.yaml or project files>
confidence:     high | medium | low
evidence:       <bullet list of observations from the checklist>
ruled_out:      <bullet list of confirmed non-causes>
─────────────────────────────────────────────
```

**Confidence levels:**

- `high` — root cause directly observable; fix is unambiguous
- `medium` — strongly inferred from multiple consistent observations
- `low` — partial information only; escalate to human engineer

If confidence is `high` or `medium`: apply the fix, commit, run one final pack.
If confidence is `low`: produce the ESCALATION REPORT and hand off.
