---
description: Before /clear, dump session state to a handoff doc so the next session picks up cleanly
---

Create a handoff document for session continuity. Write a file called `HANDOFF.md` in the current project root with the following sections:

## What was done this session
- List all changes made, files modified, and features implemented
- Note any commits created

## Key decisions made
- Architecture or design decisions and their rationale
- Trade-offs that were considered

## What's next
- Remaining work items and priorities
- Any blockers or open questions

## Gotchas / things to watch out for
- Anything surprising discovered during the session
- Edge cases or known issues

## How to continue
- Specific instructions for the next session to pick up where this left off
- Key files to read first

Keep it concise — aim for 30-50 lines. This file is meant to cold-start the next session, not be comprehensive documentation.

After writing HANDOFF.md, tell the user they can now run `/clear` and start fresh. The next session should start by reading HANDOFF.md.
