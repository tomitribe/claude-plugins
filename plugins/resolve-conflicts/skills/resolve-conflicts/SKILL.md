---
name: resolve-conflicts
description: "Surgical merge conflict resolution. TRIGGER when: encountering merge conflicts during cherry-pick, merge, or rebase — handle conflicts cleanly by understanding the original commit's intent, applying the minimum necessary changes, and preserving all untouched content. DO NOT TRIGGER when: there are no conflict markers in the working tree, or the user is asking about conflicts conceptually rather than resolving them."
---

# Conflict Resolution Skill

Resolve merge conflicts by **understanding what changed and why**, then applying only those changes — nothing more. The most common mistake is changing too much. Your job is surgical, not editorial.

**Announce at start:** "I'm using resolve-conflicts to handle these merge conflicts."

---

## Critical: Understand Your Operation First

The meaning of conflict markers differs depending on the operation. Get this wrong and you'll resolve conflicts backwards.

### In a cherry-pick:
```
<<<<<<< HEAD          ← the branch you are ON (destination/base)
...existing content...
=======
...incoming content...
>>>>>>> <sha> (commit message)   ← the commit being cherry-picked (source)
```
The cherry-picked commit's changes are on the **bottom** (after `=======`).

### In a merge or rebase:
```
<<<<<<< HEAD          ← your branch (current)
...your content...
=======
...their content...
>>>>>>> branch-name   ← the branch being merged in
```

**Before touching any file, run:**
```bash
# Confirm what operation is in progress
git status

# For cherry-pick: study the original commit FIRST
git show <sha>

# Understand what files it touched and exactly what it added/removed
# This is your ground truth. The conflict resolution must achieve the same net result.
```

---

## The Resolution Process

```
STOP: Read the original commit diff completely
      │
      ▼
Sanity-check: does this cherry-pick still make sense?
      │
      ▼
Identify ONLY the lines the commit intended to add/change/remove
      │
      ▼
For each conflicted file:
  - Reproduce the commit's intended net change
  - Preserve ALL other content from HEAD unchanged
      │
      ▼
Verify: diff the result against what the commit intended
      │
      ▼
Continue the operation
```

---

## Step 1: Read the Original Commit (Cherry-pick)

This is the most important step. Do not skip it.

```bash
git show <sha>
```

Read the diff carefully:
- Which lines were **added** (prefixed with `+`)?
- Which lines were **removed** (prefixed with `-`)?
- What is the **smallest meaningful unit of change** in each file?

For changelog files (XML, MD, CHANGELOG, CHANGES, etc.) the commit typically adds a small block of entries. The rest of the file is irrelevant to the cherry-pick.

---

## Step 1.5: Sanity-check Before Resolving (Cherry-pick only)

Before touching any file, compare what the commit intended to change against what HEAD already contains. If the cherry-pick doesn't make sense, **stop and ask the user** rather than resolving.

Concrete checks:

```bash
# For each file the commit touched, compare commit intent vs HEAD reality
git show <sha> -- <file>           # what the commit adds/changes
git log --all --oneline -S'<distinctive string from the commit>' -- <file>
git log HEAD --oneline -- <file>   # has HEAD's history already touched this?
```

**STOP and surface the situation to the user if any of these are true:**

- HEAD already contains the logic the commit is trying to add (search for a distinctive method name, string literal, or test assertion from `git show <sha>`). The cherry-pick may be redundant or superseded by a later commit.
- HEAD's version of the relevant code is **more sophisticated** than the cherry-pick's version (e.g. handles more cases, has additional validation). Applying the cherry-pick would be a regression.
- Resolving the conflict would produce a **net deletion** or near-zero net change for a commit whose message describes adding a feature.
- The conflict markers span large regions that don't correspond to anything in `git show <sha>` — suggests the branches have diverged structurally and a cherry-pick may not be the right tool (consider a manual port or a different source commit).

**How to stop:** Do not run `git add`. Do not continue the cherry-pick. Report findings like this:

> "Before resolving, I want to flag something: HEAD already appears to contain `validateAllowedScheme` (see `BrokerView.java:580`), which is the method this commit is trying to add. A related commit may have landed already. Options:
> 1. Abort the cherry-pick (`git cherry-pick --abort`) — likely correct if this is a duplicate
> 2. Proceed and keep HEAD's version (effectively a no-op cherry-pick, empty commit)
> 3. Proceed and overwrite with the commit's version (regression — HEAD's is more complete)
>
> How would you like to proceed?"

Only continue to Step 2 once the user confirms the cherry-pick should go ahead, or explicitly says "resolve anyway."

---

## Step 2: Categorise Each Conflicted File

Before editing, classify the conflict type:

| Type | Description | Strategy |
|------|-------------|----------|
| **Pure addition** | Commit adds new content, HEAD also has new content at the same location | Find correct insertion point, add the new block |
| **Overlapping edit** | Both sides modified the same lines | Manually merge the logic from both |
| **Ordering conflict** | Both sides added entries to a list in different positions | Insert the cherry-picked entries at a semantically correct position |
| **Structural conflict** | File format or surrounding code changed | Reproduce the commit's logical change within the new structure |

---

## Step 3: Resolve with Minimum Footprint

### The Golden Rule
**Change only what the commit changed. Leave everything else exactly as it is in HEAD.**

If the commit added 8 lines to a 700-line file, your resolved file should differ from HEAD by approximately 8 lines — not 700.

### For changelog / release note files (common conflict source):

These files grow with every commit. Cherry-pick conflicts are almost always **insertion conflicts**: both HEAD and the cherry-picked commit added entries near the same location.

Resolution strategy:
1. Find the section in HEAD where the commit's entries belong
2. Insert *only* the lines from the cherry-picked commit's diff
3. Do not reorder, reformat, or include any other sections from the commit's version

Example — if `git show <sha>` shows the commit added this to changelog.xml:
```xml
<add>
  Add support for new algorithms provided by JPA providers to the
  <code>EncryptInterceptor</code>. (markt)
</add>
```

Then your resolution inserts exactly those lines in the right `<subsection>` in HEAD's version. The hundreds of other lines that appeared between conflict markers from the cherry-picked side are **not part of this commit** — they are pre-existing content from the source branch that accumulated before the cherry-pick sha. Discard them.

### For source code files:

```bash
# See exactly what the commit changed in this specific file
git show <sha> -- path/to/file.java
```

Apply that diff manually to the HEAD version of the file. If the surrounding code in HEAD has changed, adapt the patch to fit — but only change what the commit intended to change.

---

## Step 4: Verify Your Resolution

```bash
# After staging all resolved files, check your work
git diff --cached

# The diff should show approximately the same changes as git show <sha>
# If it shows dramatically more changes, you've taken too much from one side
```

### Red flags — redo the resolution if you see:
- Hundreds of lines changed in a file the commit only touched lightly
- Content from other releases or sections that weren't in the original commit
- Duplicate entries (the same change appearing twice)
- Missing content from HEAD that was not removed by the commit
- **Net deletion for a feature-add commit.** If the commit message describes adding functionality but `git diff --cached` shows a net line decrease (or near-zero change), the cherry-pick is likely redundant — HEAD probably already has the change. Stop and consult the user before running `git cherry-pick --continue`.

### Check for leftover markers:
```bash
grep -rn "<<<<<<\|=======\|>>>>>>" .
```

---

## Step 5: Continue the Operation

```bash
# Stage all resolved files
git add <file1> <file2> ...

# Continue the cherry-pick
git cherry-pick --continue

# Or abort if something is wrong
git cherry-pick --abort
```

---

## Common Mistakes to Avoid

### Taking the entire "theirs" side in a changelog
The cherry-picked commit's version of changelog.xml contains **all entries from the source branch up to that point** — not just what the commit added. Never use `git checkout --theirs` on a changelog file. Always manually insert only the specific entries from `git show <sha>`.

### Using `git checkout --theirs` or `--ours` blindly
Only appropriate when the commit genuinely replaced an entire file. For partial changes, always edit manually.

### Resolving without reading the original commit
Without reading `git show <sha>`, you cannot know what change was intended. You're guessing. Always read it first.

### Reformatting or reorganising surrounding code
Your resolution must not introduce style changes, reorderings, or refactoring beyond what the commit itself did. This makes review harder and can break things.

### Resolving a redundant cherry-pick silently
If HEAD already contains the change the commit is trying to introduce, resolving the conflict and continuing produces an empty or near-empty commit that adds nothing and obscures history. When you detect this, stop and ask — do not "resolve" by keeping HEAD and committing.

---

## Conflict Marker Reference

```
<<<<<<< HEAD
[content as it exists on your current branch — keep this as the base]
=======
[content from the incoming commit/branch — extract only what's new]
>>>>>>> <identifier>
```

The resolved content should be: HEAD's content + only the additions/changes the incoming commit intended to make.

---

## Checklist

- [ ] Identified the operation type (cherry-pick / merge / rebase)
- [ ] Read `git show <sha>` (for cherry-pick) or equivalent to understand original intent
- [ ] Sanity-checked that the cherry-pick is not redundant (HEAD doesn't already contain the change)
- [ ] If redundant or regressive, surfaced to user and got confirmation before proceeding
- [ ] Classified each conflict (pure addition, overlapping edit, etc.)
- [ ] Resolved each file with minimum footprint
- [ ] Verified `git diff --cached` matches the original commit's intent
- [ ] No conflict markers remain (`grep -rn "<<<<<<" .`)
- [ ] Operation continued (`git cherry-pick --continue` etc.)
