---
description: Build a rock — gather context from the user and kick off the build
agent: rock-builder
---

The user wants to build an OCI rock. Your job right now is to understand what they want and collect everything needed before work begins.

## GATHER

Read `$ARGUMENTS` as free-form natural language. Extract any fields already stated. For every required field that is still missing, use the Question tool to ask — group related questions together so the user is not asked one field at a time.

Required fields:
- **name** — rock name, lowercase, hyphen-separated
- **version** — semantic version string, e.g. `1.0`
- **build-base** — e.g. `ubuntu@24.04`
- **platforms** — default `amd64` if not specified
- **what to package** — the application, binary, or packages this rock should contain

Optional fields (ask only if not inferable from context):
- **service command + port** — if the rock runs a long-lived service via Pebble

Once all required fields are known, hand off to the build loop with a concise summary of what was gathered.

When all the process is done and a `.rock` file is produced, ask the user whether they want to add tests for the rock. If so, run the `test-command` and pass the `rockcraft.yaml` path as context.
