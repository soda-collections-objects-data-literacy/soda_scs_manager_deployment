---
name: issue-flow
description: >-
  Runs a GitHub issue of any repo developed from the SCS deployment root
  (deployment, jupyterhub, keycloak, scs-nextcloud-stack, scs-manager-stack,
  images, wisski-base-stack, …) from start to finish, with pauses for the
  user: pick the right repo → draft → user approves, Claude opens it with gh →
  solve on dev with a report first → comment (what was done, how to test) →
  user tests on dev, loop until "getestet" → checks and review → commit with
  "Refs #n" → push plan → Prime rollout via /update-stack --prime → close.
  Use when the user says issue-flow, or asks to file, solve or finish such an
  issue. The SCS Manager module and other Drupal.org projects are out of
  scope. Resumes from plans/issues and git state.
argument-hint: "[bug|feature|task … | repo#n | issue URL]"
disable-model-invocation: true
---

# Issue flow (deployment root)

Every repo has its own tracker: the `issue-tracking` rule maps paths to
GitHub repos (`$R` below). `gh` is logged in as the user, so Claude reads,
opens, comments and closes, **but writes only after the user approved the
text at a PAUSE**. Talk to the user in their language; issue and comment text
is English Markdown. Templates, commands, layout: [reference.md](reference.md).

```
- [ ] Phase 0: Which repo? (issue-tracking rule)           → Drupal.org → stop
- [ ] Phase 1: Draft issue                                  → PAUSE: open it?
- [ ] Phase 2: Solve: report, then patch + comment draft    → PAUSE: post, test on dev
- [ ] Phase 3: Dev test: problem → Phase 2; "getestet" → Phase 4
- [ ] Phase 4: Checks + review                              → PAUSE: pick findings
- [ ] Phase 5: Fix findings; behavior changed → follow-up comment → Phase 3
- [ ] Phase 6: Commit (Refs) + push plan                    → PAUSE: push
- [ ] Phase 7: Prime rollout (user) + verify                → PAUSE: Prime result
- [ ] Phase 8: Close with a short comment
```

## Hard rules

- A **PAUSE** ends the turn with one clear question. Never continue past it on
  your own; silence or an unrelated reply is not a go.
- **gh writes only on a go** for exactly that text and that repo: create,
  comment, close, labels. Reading (`gh issue view/list`) is free.
- **A posted comment is never edited.** New facts go into the next comment,
  and only when the code or the procedure changed. Comments carry no commit
  SHAs (GitHub links `Refs` commits by itself) and no push state.
- No secrets in any issue; in public repos also no `.env` values, e-mail
  addresses, personal names, real user names, internal IPs (`***`, or roles
  like "a project member"). Visibility per repo: `issue-tracking` rule.
- Containers follow the `stack-operations` rule. **Dev:** recreating the
  containers the patch touches is part of Phase 2; name them first, ask when
  it is more than the affected services. **Prime:** you change nothing; the
  user runs `/update-stack --prime` there.
- Never create, update or delete real applications, projects or users to test
  (the Manager does that for real, on dev too). The user clicks.
- Commits follow `/git-commit`: innermost repo first, explicit paths, no push;
  push lines go into `plans/push-plan.txt`.
- `/compact` is the user's command. At pauses marked *compact hint*, end with
  one line like `/compact issue-flow jupyterhub#12, Phase 3, open: …`. The
  flow resumes from `plans/issues/` and git.

## Start: find the phase

The issue key is `{repo}#{n}` (`{repo}` = GitHub repo name, e.g.
`jupyterhub#12`, `soda_scs_manager_deployment#3`). A bare `#n` means the
deployment repo; say so.

| Situation | Start at |
|---|---|
| `bug …` / `feature …` / `task …` in ARGUMENTS | Phase 0 |
| issue key/URL, no `plans/issues/{repo}/{n}/comments/` | Phase 2 |
| newest comment draft `posted: false` | the pause that wrote it |
| uncommitted change for the issue, newest draft posted | Phase 3 (ask for the dev result) |
| commits with the issue's `Refs` not on the remote yet | Phase 6 push pause |
| all those commits pushed, issue open | Phase 7 |

Say in one line which phase you picked and why. Uncommitted changes of two
issues at once → ask which files belong to which.

## Phase 0: Which repo

Find where the code that fails (or has to change) lives, then look the path up
in the `issue-tracking` rule.

- Drupal.org project (SCS Manager module, `wisski_default_data_model`,
  `nextcloud_webdav_mount`, themes) → stop: say it belongs to the Drupal
  workflow, give a short summary the user can take there. No GitHub issue.
- Another organization (`open_gdb`) or issues disabled (`gh repo view $R
  --json hasIssuesEnabled`) → ask the user.
- Several repos change → one issue per repo; say which and why. The
  deployment issue carries the rollout (pointer bump, Prime steps). Draft them
  together, pause once.
- Not sure yet (the cause is unknown) → draft in the repo of the service that
  shows the symptom, and say the issue may move once the cause is clear
  (`gh issue transfer` works only within the organization; ask first).

## Phase 1: Draft

No kind word (`bug`/`feature`/`task`) → ask. Read what the user gave: symptom,
container, log lines, host (dev or Prime). For a bug, look before you write:
`docker compose ps`, `docker compose logs --tail 200 <svc>` (or the
`log-triage` agent), the service's compose config, the script. Prime logs
cannot be read from dev: ask for them, or put it under **Not verified**.

Duplicates: `gh issue list -R $R --state all --search "<two or three words>"`.
Clear duplicate → stop, give its key, offer a comment there.

Title `{Area}: {what fails or what to add}` (Area: service or tool, e.g.
`Spawner`, `update-stack`, `Mount sidecar`). Labels only from `gh label list
-R $R`; no new labels without a go.

Write `plans/issues/{repo}/draft-{slug}/issue.md` (template in reference.md).
Show repo, title, labels and the body in one ```markdown block. **PAUSE:**
"Soll ich das Issue in `{owner}/{repo}` so anlegen?" On "anlegen":
`gh issue create`, move the directory to `plans/issues/{repo}/{n}/`, set
`number`/`url`. Changes requested → edit the draft, pause again.

Existing issue without a local copy: `gh issue view` → write
`plans/issues/{repo}/{n}/issue.md`; never overwrite one.

## Phase 2: Solve

1. **State.** `git status -sb`, `git log --oneline -3` in the repo of the issue
   and in the deployment root when a pointer will move. Foreign uncommitted
   changes → list them, ask; never revert. A submodule on a detached HEAD that
   needs a commit → ask which branch (`git branch -a --contains HEAD`).
2. **Trace.** Read the path end to end: compose file → override → script or
   unit → the container's entrypoint/config. Compare with a service that works
   when the issue names one. Check read-only first: `docker compose config`,
   `docker inspect`, `systemctl cat`, `git log -S`. State which checks ran and
   which you only read.
3. **Report in chat, before any edit** (template in reference.md): Cause,
   Affected, Proposed fix, Risks, Not verified. **Stop and ask** when the
   cause is not proven, several fixes behave differently, the fix deletes or
   overwrites data or volumes, changes `.env`/secrets/Traefik routing for all
   services, or needs a sudo step on the host.
4. **Patch.** Only the fix, following the `docker`, `documentation`,
   `logging`, `python`, `clean-code` rules. Repo with a `CHANGELOG.md` →
   `[Unreleased]` entry ending with `Related: {owner}/{repo}#{n}` (`changelog`
   rule). Deployment docs in `docs/en` **and** `docs/de` (the `docs-sync`
   agent translates); a new host step (sudo, systemd, `.env` key) goes into
   `docs/en/technical/initial-setup/pre-start-steps.md` or the
   post-configuration checklist, a new key into `example-env`.
5. **On dev:** apply what the patch needs to show (the narrowest
   `docker compose up -d [--force-recreate|--build] <svc>` from the root,
   after naming it), then `docker compose ps <svc>`. Never `down`, never
   `docker restart`. An image repo (`repos/*-image`) → local build only when
   the user wants it; say how dev gets the image otherwise.
6. **Comment draft** `plans/issues/{repo}/{n}/comments/{nn}.md`: what was
   done, how to test on dev, what Prime will need. **PAUSE** with: what
   changed (two or three sentences), the draft in one ```markdown block, which
   test steps touch real data, and "Soll ich den Kommentar posten? Teste auf
   dev und sag *getestet* oder was nicht stimmt." *compact hint*.

On "posten": `gh issue comment`, set `posted: true` and the comment `url`.

## Phase 3: Dev test

- **Something is off** → Phase 2 with the report. Newest draft unposted →
  update it; posted → a follow-up draft (reference.md).
- **"getestet"** → Phase 4.

## Phase 4: Checks and review

Run the checks for the changed file types (reference.md#checks). A tool
missing → say which check did not run.

Then review the diff against the rules (`docker`, `clean-code`,
`stack-operations`): `${SCS_ROOT_PATH}` paths, no `-f` in commands, no secret
in git, idempotent scripts, error branches that stop before a destructive
step, Prime impact named. Numbered findings `F1`, `F2`, … with severity and
one line each. **PAUSE:** "Welche Findings soll ich beheben? (*F1 F3*,
*alle*, *keine*)". No findings → say so, go to Phase 6.

## Phase 5: Fix

Fix exactly the picked findings, re-run the affected checks. Behavior on dev
changed (anything beyond wording or comments) → follow-up comment draft,
**PAUSE** as in Phase 2, then Phase 3. Only wording → Phase 6, no comment.

## Phase 6: Commit

`/git-commit` rules: innermost first (submodule commit, then the pointer in
the deployment root), plain English imperative subject with a period. Last
body line: `Refs #{n}.` in the issue's own repo, `Refs {owner}/{repo}#{n}.`
everywhere else (the pointer bump too). No `Fixes`/`Closes`: issues close
after Prime.

Append the push lines to `plans/push-plan.txt` (innermost first, the
deployment root last) and the Prime steps as `todo` lines; run
`01_scripts/global/push-release-plan.bash --dry-run` and show its tail.
**PAUSE:** "Führ den Push-Plan aus und sag Bescheid."

## Phase 7: Prime

Check each pushed repo: `git ls-remote <remote> refs/heads/<branch>` against
`git rev-parse HEAD` (no fetch). Missing → name the push line, PAUSE again.

All pushed → give the Prime steps: `/update-stack --prime --check`, then
`--apply`, plus the manual steps from the comment (sudo, systemd, a test
call). An image repo → the image build/tag first (`/release` or
`/scs-release-prep`). **PAUSE:** "Wie sieht es auf Prime aus?" Something off
→ Phase 2 (Prime-only: compare `.env`, overrides, unit files; ask for the
output, you cannot read Prime).

## Phase 8: Close

Draft the closing comment (reference.md: one or two lines, what Prime shows
now; no SHAs) for each issue of the change. **PAUSE:** "Kommentar posten und
Issue(s) schließen?" On a go: `gh issue close {n} -R $R --comment "…"` (or
`--reason "not planned"`). Releases are separate: `/scs-release-prep`.
