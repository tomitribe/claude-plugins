---
description: Start a design session — discussion first, decisions tracked, no code until we're ready
---

We're entering a design session. Discussion first, decisions tracked, code last.

**Set up the working document.** Create `docs/dev/$ARGUMENTS-working-doc.md` (or `.adoc` if the project uses AsciiDoc) with this structure:

```
# [Topic] — Working Document

## Goal
[To be filled as we discuss]

## Decisions Made
| # | Decision | Rationale | Alternatives Considered |
|---|----------|-----------|------------------------|

## Open Questions
- [ ] ...

## Rejected Alternatives
| Alternative | Why Rejected |
|-------------|-------------|

## Action Items
| # | Item | Dependencies | Issue |
|---|------|-------------|-------|
```

**Rules for this session:**

1. **No code.** Do not write implementation code, enter plan mode, or offer to implement anything. We are designing, not building.
2. **Discuss freely.** Bring opinions. Push back. Propose alternatives. Challenge assumptions. This is co-creation, not instruction-following.
3. **Capture as we go.** Update the working doc with each decision, rejected alternative, and open question as the conversation progresses. Don't wait until the end.
4. **Push ideas to their edges.** For each decision, ask: "What if we expand this? What does this mean for [adjacent concern]? Does this create a problem we don't see yet?"
5. **Document the why.** Every decision and rejection needs a rationale. People will propose the rejected alternatives later — the documented reasoning saves that future debate.
6. **Track open questions explicitly.** When something comes up that we can't resolve yet, add it to the open questions list rather than letting it drift.
7. **I'll say when we're done designing.** Don't ask "shall I implement this?" — I'll tell you when we're ready to move to implementation.

**When the design is done** (I'll say so), then:
- Consolidate and order action items by dependency
- File GitHub issues (if the project uses them)
- Extract ADRs for the most significant decisions
- Only then move to implementation

Start by asking me: **What are we designing today, and what does the end result look like?**

If $ARGUMENTS was provided, use that as the topic name. If not, ask me.
