# Prepare and push a release

The `scs-release-prep` skill gets all pending SCS changes ready so that only the push is left. Then it names every step that no CI does. It lives in `.cursor/skills/scs-release-prep/`. `.claude/skills/` links there, so Cursor and Claude Code read the same file. Run it with `/scs-release-prep`.

For a single repo there are `/git-commit` (commit only) and `/release` (version and tag).

## What the skill does

It checks the deployment, all submodules, the `soda_scs_manager` module, the `scs_custom_theme` theme and `repos/scs-manager-image`. It shows a plan and asks once. Then:

1. It commits the changes in logical commits, innermost repo first.
2. It adds every visible change under `[Unreleased]` in the repo's `CHANGELOG.md`.
3. It releases the module (`4.x.y`) and the image (`3.x.y`) when Prime needs them, and tags JupyterHub and Voyager when their changelogs (or Voyager upstream bump) call for it. Tags have no `v` and are annotated. Voyager stays on rolling `main`, not detached at an upstream `v*` tag.
4. It commits the new submodule pointers in the deployment.
5. It writes `plans/push-plan.txt`, checks the plan with a dry run and lists the manual steps.

The skill never pushes. Prime is not part of the plan: after the push, `/prime-deploy` rolls it out from the dev host ([Steer Prime from dev](dev-to-prime.md#steer-prime-from-dev)).

## Pushing

```bash
cd /var/www/deploy/soda_scs_manager_deployment
01_scripts/global/push-release-plan.bash --dry-run
01_scripts/global/push-release-plan.bash
```

The dry run works offline from the last fetched remote state and does not ask for the passphrase. The real run loads the SSH key into an `ssh-agent` once and then pushes every plan line in order. GitHub remotes with `https://` are pushed over SSH as well.

Running it again is safe, refs that are already pushed are up to date. After the run the plan is kept as `plans/push-plan.done-<timestamp>.txt`. When the plan pushed the deployment, the script ends with a reminder to run `/prime-deploy`.

## What does not happen automatically

The skill writes these steps into the plan. For every module release it writes `plans/release-notes-soda_scs_manager-X.Y.Z.md` with a short description and HTML release notes for drupal.org. The script prints that file with `show` right before the step, stops at `pause` and prints the `todo` items as a checklist at the end.

| When | Step |
| --- | --- |
| During the push, module tag | On [drupal.org](https://www.drupal.org/project/soda_scs_manager), use *Add new release* to create the release node for the tag and paste the changelog section as release notes. Without the node drupal.org packages nothing, and the image keeps building the old module. The script waits until the version is listed and only then pushes the image tag. It gives up after 60 minutes (set `WAIT_TIMEOUT` in seconds to change that). |
| After the push, image tag | Check that [Publish SCS Manager Docker Images](https://github.com/soda-collections-objects-data-literacy/scs-manager-image/actions) is green. |
| After the push, tag in a GitHub repo | The plan line `gh-release <path> <tag>` creates the GitHub Release from the annotated tag (skipped if it already exists). |
| On Prime (`todo Prime: /prime-deploy …`) | From dev, once the image builds are green: `/prime-deploy`. `ssh prime apply` pulls the deployment, copies the overrides, recreates what changed and starts the new manager image. The skill then adds the WissKI component version and sets the default. The plan has no separate lines for these steps. See [Short recipe](dev-to-prime.md#short-recipe). |
| On Prime, by hand (`todo Prime (manual): …`) | What the wrapper cannot do: install changed systemd units with `sudo` (`apply` prints the commands), Nextcloud repair and `occ` after a version change, Keycloak realm changes in the admin console, new `.env` values (before `/prime-deploy`), new settings and API keys at `/admin/config/soda-scs-manager/settings`, drush commands from the changelog. The entrypoint runs `drush updatedb` but never `config:import`, so new config from the module needs an update hook. |

## Plan format

```text
push <repo-path> <remote> <refspec>...
gh-release <repo-path> <tag>
show <file>
pause <text>
wait-drupal <project> <version>
note <text>
todo <text>
```

Paths are relative to the deployment. Lines starting with `#` are comments.
