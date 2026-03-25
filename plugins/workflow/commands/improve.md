---
description: Review recent git history and propose CLAUDE.md improvements based on what actually happened
---

Analyze the recent git history and current session to propose improvements to this project's CLAUDE.md. This is the "compounding engineering" pattern — making Claude better for next time based on what happened this time.

Follow these steps:

1. **Read the current CLAUDE.md** (if it exists) to understand what's already there.

2. **Review recent git history thoroughly** — use subagents to do this in parallel:
   - `git log --oneline -30` for the broad picture
   - `git log -20 --format="%h %s%n%b" --no-merges` for commit messages AND bodies
   - `git diff HEAD~10..HEAD --stat` for scope of changes
   - `git diff HEAD~10..HEAD` to read the actual diffs (use subagents for large diffs)
   - Look at any recent `CLAUDE.md` changes in the history: `git log -10 --all -- CLAUDE.md`

3. **Identify THREE categories of learnings:**

   **A. Mistakes to prevent** (defensive rules):
   - Reverts, fix commits, "oops" messages, corrections
   - Patterns where something was done wrong then fixed
   - Propose as "DO NOT" rules

   **B. Improvements to harden** (raised-bar rules):
   This is the most important category. Look for cases where we deliberately
   made something better — a refactor, a new convention, a quality improvement,
   a better pattern replacing an old one. These signal "from now on, always do
   it this way." Examples:
   - Refactored tests from one style to another
   - Added error handling in a specific pattern
   - Replaced a dependency or approach with a better one
   - Introduced a naming convention
   - Added a build step, CI check, or quality gate
   - Cleaned up or restructured code organization
   - Established a new API pattern or contract style

   The key signal: if a diff shows old-way to new-way, the new-way is now the standard.
   Look at the substance of the change, not just the commit message.

   **C. Workflow patterns to document** (efficiency rules):
   - Commands or sequences run repeatedly
   - File paths that come up often
   - Build/test/deploy commands that aren't documented
   - Integration points or external dependencies with non-obvious setup

4. **For each proposal, cite the evidence** — reference the specific commit hash
   and what happened. For "raised bar" rules, show the before/after briefly so
   the user can confirm the new standard is intentional, not accidental.

5. **Present proposals grouped by category** (Mistakes / Raised Bar / Workflow).
   For each:
   - The proposed CLAUDE.md rule (1-2 lines)
   - The evidence (commit hash + brief description)
   - Confidence level: HIGH (clear pattern across multiple commits), MEDIUM
     (single deliberate change), LOW (might be one-off)

6. **Ask for approval** before making any changes. The user may want to:
   - Accept all
   - Cherry-pick specific proposals
   - Adjust wording
   - Reject some as one-off changes that shouldn't become permanent rules

   Only modify CLAUDE.md after the user confirms.

Important guidelines:
- Only propose rules that are NOT obvious from reading the code
- Keep proposals concise — each rule should be 1-2 lines max
- Include a concrete example from the actual codebase when possible
- For "raised bar" rules: if there's still old-way code that wasn't migrated, note it — the user may want a follow-up task to finish the migration
- Remove any existing CLAUDE.md rules that are now obsolete or that Claude consistently follows without needing the rule
- The goal is a CLAUDE.md under 100 lines that captures only high-signal, non-obvious guidance
- Favor specific, actionable rules over vague principles
