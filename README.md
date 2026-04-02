# Claude Plugins

This repository contains plugins for Tomitribe's open source libraries and team workflow commands.

## Setup

Add the Tomitribe marketplace to Claude Code:

```
/plugins → Marketplace → +Add Marketplace → tomitribe/claude-plugins
```

Then enable the plugins you want from the list.

## Library Reference Plugins

Skills that auto-activate when you're working with Tomitribe libraries:

| Plugin | Library |
|--------|---------|
| `churchkey` | Cryptographic key parsing/export (PEM, JWK, OpenSSH, SSH2) |
| `crest` | Annotation-driven CLI framework |
| `pixie` | Lightweight dependency injection, configuration, and events |
| `jaws` | Typed S3 proxy interfaces |
| `tomitribe-util` | Encoding, I/O, duration/size, templates, collections, reflection |
| `tomitribe-util-dir` | Strongly-typed filesystem manipulation with Dir proxies |
| `archie` | Streaming archive transformation |
| `checkmate` | Fluent validation |
| `http-signatures` | HTTP message signing (HMAC, RSA, ECDSA) |
| `swizzle` | Stream manipulation and lexing |
| `java-conventions` | Tomitribe Java coding standards (`final` keyword, etc.) |

## Workflow Commands

Commands for working effectively with Claude Code. Enable via `workflow@tomitribe`.

### `/design [topic]`

Starts a structured design session. Claude discusses, tracks decisions, captures
rejected alternatives, and documents open questions — all before any code is written.
Creates a working document at `docs/dev/<topic>-working-doc.md`.

Use for problems that cross system boundaries, have multiple interconnected decisions,
or where the first solution that comes to mind probably isn't the best one.

### `/improve`

Reviews recent git history and proposes CLAUDE.md improvements based on what
actually happened. Identifies three categories:

- **Mistakes to prevent** — reverts, fix commits, corrections become "DO NOT" rules
- **Improvements to harden** — refactors, new conventions, quality improvements become "always do it this way" rules
- **Workflow patterns** — repeated commands, undocumented build steps become efficiency rules

Run after completing significant work to make Claude permanently better for
the next session.

### `/handoff`

Before `/clear`, dumps session state to `HANDOFF.md` so the next session picks
up cleanly. Covers what was done, decisions made, what's next, gotchas, and
how to continue.

### `/recap`

Quick "where was I?" for when you return to an open session. Summarizes what
you were working on, what got done, where you left off, and what's next.

