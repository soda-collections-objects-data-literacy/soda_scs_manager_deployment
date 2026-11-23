---
name: prime-deploy
description: >-
  Update Prime (production) from the dev host over the restricted SSH key:
  plan with update-stack --prime --check, apply after the user's yes, follow
  the logs, run the Drupal checks and add or switch the WissKI component
  version. Use when the user asks to deploy to, update or check Prime from dev.
disable-model-invocation: true
---
# Deploy to Prime from dev

Every call goes through `ssh prime <command>`. On Prime the key may only run
`/usr/local/bin/scs-prime-remote` (source: `01_scripts/global/prime-remote.bash`),
so there is no shell: never try `ssh prime bash`, `sudo`, `docker exec` or
anything that `ssh prime help` does not list. Setup and the security model:
`docs/en/technical/maintenance/dev-to-prime.md`, section "Steer Prime from dev".
What the update does, and how to read its output, is the Prime part of the
`update-stack` skill; this skill only replaces "run it on Prime" with
`ssh prime …`.

```
- [ ] 0. Access and preconditions
- [ ] 1. ssh prime check
- [ ] 2. Show the plan, wait for the user's yes
- [ ] 3. ssh prime apply
- [ ] 4. Verify
- [ ] 5. WissKI component version (ask before each write)
- [ ] 6. Manual steps and issues
```

**0. Access.** `ssh -o BatchMode=yes prime help`.

- `Permission denied (publickey)` / agent empty: the key is not loaded. Ask the
  user to run `ssh-add -t 2h ~/.ssh/scs-prime` **on their workstation** (the
  agent is forwarded to dev). Never handle a passphrase, never look for keys.
- The help lacks a command this skill needs, or differs from
  `01_scripts/global/prime-remote.bash`: the wrapper on Prime is outdated. Ask
  the user to reinstall it on Prime (command in the script header).
- Is everything pushed? Prime follows the pointers on `origin/main` of the
  deployment: `git status -sb` here must not show `ahead`. Unpushed work →
  `/scs-release-prep` and `push-release-plan.bash` first.

**1. Check.** `ssh prime check` (add `--since <sha>` / `--offline` only on
request). Read it as in `update-stack`, Prime step 1. Git on Prime runs without
an agent (`restrict`): public repos come over HTTPS; a private repo that cannot
be fetched is reported, not fixed from here.

**2. Review.** Summarise: what moves, what is built and recreated, the snapshot,
systemd units, every `BLOCKED` line, the WissKI values. Blockers need the user
on Prime (no shell from here). **No apply without an explicit yes.**

**3. Apply.** `ssh prime apply` with a long timeout (or `run_in_background`):
builds take minutes, the manager start up to 15. The run is detached on
Prime and survives a dropped connection: reattach with
`ssh prime apply-log --follow`, state with `ssh prime apply-status`. The SSH
exit code is the update's exit code. `--no-snapshot` only when the user asks.

**4. Verify.** Exit 0 and the script's own checks green. Otherwise, and for a
second look: `ssh prime status`, `ssh prime drush-checks`,
`ssh prime logs <container> [lines]`, `ssh prime follow <container> [seconds]`,
`ssh prime timers`, `ssh prime git-status`. Hand bulky log reading to the
`log-triage` agent with these commands. Report with excerpts; never claim
success on a red check.

**5. WissKI version.** Values come from the check/apply output ("WissKI component
version for Manager settings"). `ssh prime wisski-versions` shows what exists.

1. Not there yet: show the six values, ask, then
   `ssh prime wisski-version-add <version> <stack> <image> <packages> <default-data-model-recipe> <starter-recipe>`.
   Unknown values (`(unknown)`) are never guessed; ask.
2. Default: separate question ("new WissKIs from now on get X"), then
   `ssh prime wisski-set-default <id>` (id = version with `.` → `_`, e.g. `5_11_0`;
   the wrapper prints it).
3. `ssh prime wisski-versions` again to confirm.

**6. Manual steps and issues.** Pass the remaining checklist on verbatim. `sudo`
commands (systemd units), Nextcloud repair, Keycloak console work and settings
pages stay with the user on Prime. Issues: as in `update-stack`, Prime step 6,
but `gh` runs here on dev; the checks behind each comment use the read-only
commands above.
