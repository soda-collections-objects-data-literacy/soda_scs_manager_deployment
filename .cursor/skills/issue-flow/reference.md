# Issue-flow reference

## Repos and paths

- Which GitHub repo: the `issue-tracking` rule (`.cursor/rules/issue-tracking.mdc`).
  `$R` = `{owner}/{repo}` from that table; pass `-R $R` on every `gh` call.
- Local drafts: `plans/issues/` in the deployment root (git-ignored, dev only),
  one folder per GitHub repo name:

```
plans/issues/{repo}/
  draft-{slug}/issue.md          before the issue exists on GitHub
  {n}/issue.md                   after gh issue create
  {n}/comments/01.md, 02.md      comment drafts, two digits, never overwritten
```

`{slug}`: lowercase, hyphens, from the title, at most ~40 characters. An
existing `draft-{slug}/` → `-2`, `-3`. An existing `{n}/` when moving → stop,
never merge directories.

Next comment number:

```bash
dir="plans/issues/{repo}/{n}/comments"; mkdir -p "$dir"
n=1; while [ -e "$dir/$(printf '%02d' $n).md" ]; do n=$((n + 1)); done; printf '%02d\n' $n
```

## gh commands

```bash
R=soda-collections-objects-data-literacy/jupyterhub      # from the issue-tracking rule
gh issue list -R $R --state all --search "spawner volume" --limit 20
gh issue view {n} -R $R --json number,title,state,labels,body,comments
gh label list -R $R
gh repo view $R --json hasIssuesEnabled,visibility

# Only after the user's go. Strip the frontmatter into the scratchpad first:
awk 'f >= 2; /^---$/ { f++ }' plans/issues/{repo}/draft-{slug}/issue.md > "$SCRATCH/body.md"
gh issue create -R $R --title "…" --label bug --body-file "$SCRATCH/body.md"
gh issue comment {n} -R $R --body-file "$SCRATCH/body.md"
gh issue close {n} -R $R --comment "…"            # or --reason "not planned"
```

`gh issue create` prints the URL; the number is its last path segment.
Cross-repo links in bodies and commits: `{owner}/{repo}#{n}`.

## Issue file template

```markdown
---
repo: soda-collections-objects-data-literacy/jupyterhub
number: null
url: null
title: "Spawner: project volume not mounted after restart"
kind: bug
labels: [bug]
host: prime            # where it was seen: dev | prime | both
related: []            # other issues of the same change, owner/repo#n
---

_Drafted with AI, checked by the reporter._

### Description
…

### Steps to reproduce
1. …

**Expected:** …
**Actual:** …

### Analysis
…

### Proposed fix
…

### Environment
- Repo commit: `git describe --always`; deployment commit if a pointer matters
- Host: dev | Prime
- Service: `<container>`, image tag

<details><summary>Logs</summary>

```
…
```
</details>

### Not verified
- …
```

- **Feature:** `kind: feature`, `labels: [enhancement]`; sections
  Description, Current behavior, Wanted behavior, Acceptance criteria
  (checkboxes), Notes.
- **Task** (a step on Prime, no code change, usually in the deployment repo):
  `kind: task`; sections Why, Steps (checkboxes, commands in a fenced block),
  Done when.
- Related issues in other repos → a `### Related` list with `owner/repo#n`.
- Drop empty sections, except **Not verified**. Code references as
  `` `01_scripts/global/update-stack.bash:233` ``.

## Report (chat, before the patch)

```markdown
# {repo}#{n}: {title}
## Cause            – steps with path:line; "Verified by: …" or "read only"
## Affected         – repos, files, services, containers to recreate, docs (en+de)
## Proposed fix     – per file, and why in this layer
## Risks            – Prime impact, data/volumes touched, sudo/systemd/.env steps
## Not verified
```

## Comment templates

Frontmatter on disk; the body after it is the post payload:

```markdown
---
repo: {owner}/{repo}
issue: {n}
comment: {nn}
posted: false
url: null
---
```

Full (first comment after the patch):

```markdown
_Drafted with AI, checked by the assignee._

### What was done
- `path` — what changed and why

### How to test on dev
1. …

**Expected:** …

### Prime
- `/update-stack --prime --check`, then `--apply`
- Manual: … (sudo, systemd, test call) | none

### Not verified
- …
```

Follow-up (after a failed dev test or code-changing review fixes, ≤ 10 lines):

```markdown
_Drafted with AI, checked by the assignee._

**Change:** … (file, reason: dev test / review finding)
**How to test:** 1–3 steps and the expected result.
```

Closing comment: `Live on Prime: {what was checked and what it showed}.` One
or two lines, no SHAs.

## Checks

| Changed | Check |
|---|---|
| `*.bash`, `*.sh` | `bash -n f`; `shellcheck -S warning f` when installed; executable bit kept (`git ls-files -s f` → `100755`; `core.fileMode` is false, so also `ls -l`) |
| compose, overrides | `docker compose config -q` from the deployment root (`.env` wires all stacks) |
| Dockerfile | `docker build --check .` when the builder supports it; otherwise read only |
| systemd units | `systemd-analyze verify f` (missing `docker.service` paths are fine on dev) |
| Python | `python3 -I -m py_compile f` |
| docs | page in `docs/en` and `docs/de`, nav in all three `zensical*.toml`, relative links resolve |
| submodule pointer | the commit is on a remote branch: `git -C <sub> branch -r --contains <sha>`, else Prime cannot fetch it |
