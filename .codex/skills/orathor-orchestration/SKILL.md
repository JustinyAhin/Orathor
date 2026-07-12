---
name: orathor-orchestration
description: Route Orathor work between architecture, scouting, exploration, implementation, and review agents for this macOS SwiftUI voice-dictation project.
---

# Orathor orchestration

Use the narrowest useful agent for each part of the task:

- `orathor_architect` for architecture, migrations, ambiguous planning, and cross-cutting design.
- `orathor_scout` for file and symbol lookup, simple searches, and shallow summaries.
- `orathor_explorer` for execution-path tracing and synthesis across multiple Swift files.
- `orathor_implementer` for bounded changes once the behavior and files are understood.
- `orathor_reviewer` for security, correctness, concurrency, permissions, and final validation.

Keep the main thread responsible for requirements, decisions, and synthesis.
Prefer read-only agents before write-capable agents. For changes touching more
than one or two files, establish a short plan before implementation. The
orathor_implementer must run:

```bash
xcodebuild -scheme Orathor -configuration Debug build
```

Use the existing `.claude/hooks/update-structure.sh` when repository structure
needs to be mapped. Do not modify project files from orathor_scout,
orathor_explorer, orathor_architect or orathor_reviewer.
