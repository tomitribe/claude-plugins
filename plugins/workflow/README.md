# Workflow Commands

Four commands for working effectively with Claude Code.

## `/design [topic]`

Starts a structured design session. Claude discusses, tracks decisions, captures
rejected alternatives, and documents open questions — all before any code is written.
Creates a working document at `docs/dev/<topic>-working-doc.md`.

Use for problems that cross system boundaries, have multiple interconnected decisions,
or where the first solution that comes to mind probably isn't the best one.

## `/improve`

Reviews recent git history and proposes CLAUDE.md improvements based on what
actually happened. Identifies three categories:

- **Mistakes to prevent** — reverts, fix commits, corrections → "DO NOT" rules
- **Improvements to harden** — refactors, new conventions, quality improvements → "always do it this way" rules
- **Workflow patterns** — repeated commands, undocumented build steps → efficiency rules

Run after completing significant work to make Claude permanently better for
the next session.

## `/handoff`

Before `/clear`, dumps session state to `HANDOFF.md` so the next session picks
up cleanly. Covers what was done, decisions made, what's next, gotchas, and
how to continue.

## `/recap`

Quick "where was I?" for when you return to an open session. Summarizes what
you were working on, what got done, where you left off, and what's next.

## Enable

After adding the tomitribe marketplace, enable the workflow plugin:

```
/plugins → workflow@tomitribe → Enable
```
