---
name: read-console
description: >
  Runs `rockcraft pack -v`, captures the full combined terminal output
  (stdout + stderr), and extracts the detailed log file path that Rockcraft
  prints to the console. Also performs the mandatory rockcraft.yaml precondition
  check before any build attempt. Use as the first step in every Rockcraft
  build debugging workflow, before reading the detailed log or entering a debug
  shell.
  WHEN: run rockcraft pack, capture rockcraft output, find rockcraft log file,
  extract log path, rockcraft precondition check, start rockcraft debug,
  rockcraft build first step, collect build output.
license: Apache-2.0
metadata:
  author: Canonical/rockcrafters
  version: "1.0.0"
  summary: Run `rockcraft pack -v`, capture output, and extract the detailed log file path for downstream debug steps.
  tags:
    - canonical
    - rockcraft
    - oci
    - debugging
    - build
---

## Purpose

Run `rockcraft pack -v` and collect everything needed for subsequent debug
steps:

- The full combined console output (stdout + stderr)
- The path of Rockcraft's detailed log file
- The command exit code

## Precondition — verify rockcraft.yaml exists

Before running anything, check that `rockcraft.yaml` is present in the current
working directory:

```bash
ls rockcraft.yaml
```

If the file does **not** exist, STOP immediately and report exactly:

```
rock-build-debugger: No rockcraft.yaml found in <CWD>.
Please cd to the directory containing rockcraft.yaml and invoke me again,
or provide the correct path.
```

Do not proceed to any other step.

## Running the command

Capture both console output and exit code with:

```bash
rockcraft pack -v 2>&1 | tee /tmp/rockcraft-console.log; echo "EXIT:$?"
```

The `tee` ensures output is visible in the terminal **and** saved to the
capture file. The `EXIT:$?` suffix records the exit code inline so it
survives the pipe.

Parse the final line of output for the exit code:

```
EXIT:0   → pack succeeded
EXIT:1   → pack failed (proceed with debugging)
```

If exit code is **0**, stop the debugging workflow immediately and report
success — do not proceed to read-logs or any fix loop.

## Extracting the log file path

### Primary method — parse console output

Search `/tmp/rockcraft-console.log` for a line of the form:

```
Log file is located at /path/to/rockcraft-<timestamp>.log
```

Use this regex to extract the absolute path:

```
Log file is located at (.+\.log)
```

The captured group is the full path to the detailed Rockcraft log file.

To extract it from the shell:

```bash
grep -oP 'Log file is located at \K.+\.log' /tmp/rockcraft-console.log | tail -1
```

### Fallback method — glob by modification time

If the primary method yields no result (the line is absent from console
output), find the most recently modified Rockcraft log file:

```bash
ls -t ~/.local/state/rockcraft/log/rockcraft-*.log 2>/dev/null | head -1
```

Use the resulting path as `log_file_path`.

If **neither** method yields a path, report:

```
Could not locate Rockcraft log file. Manual inspection required.
```

and skip to the DEEP DIVE phase.

## Output to carry forward

Pass the following values to the next skill (`read-logs`):

| Field           | Value                                                   |
|-----------------|---------------------------------------------------------|
| `log_file_path` | Absolute path to the detailed Rockcraft log file        |
| `exit_code`     | Integer exit code from the pack command                 |
| `console_tail`  | Last 30 lines of `/tmp/rockcraft-console.log`           |

The `console_tail` is included verbatim in the final human-readable report
for quick context.
