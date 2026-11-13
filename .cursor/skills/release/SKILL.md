---
name: release
description: >-
  Cut a release of one repo: decide the SemVer bump, roll the changelog's
  Unreleased section into a version, commit, create an annotated X.Y.Z tag (no v
  prefix), add the push lines to the push plan and name the manual publishing
  steps (drupal.org release node, CI check, GitHub Release). Use when the user
  asks to tag, release or bump the version of a single repo.
disable-model-invocation: true
---
# Release (version bump + tag)

One repo. For all SCS repos at once (module → image → deployment) use
`/scs-release-prep`. Uncommitted work first goes through `/git-commit`.

## Workflow

```
- [ ] 1. Clean tree + history
- [ ] 2. Decide the version
- [ ] 3. Roll the changelog
- [ ] 4. Commit + annotated tag
- [ ] 5. Push plan + manual steps
```

**1. Clean tree + history.** `git status` must be clean. Latest tag:
`git tag --sort=-v:refname | head -1`. What ships: `git log <tag>..HEAD --oneline`
and the `[Unreleased]` section. No network (`git fetch` asks for the passphrase).

**2. Version.** SemVer from the changes since the last tag:

| Bump | When | Changelog signals |
| --- | --- | --- |
| patch `x.y.Z` | fixes and typos only | only `Fixed`, trivial `Changed` |
| minor `x.Y.0` | new features, compatible additions | any `Added`, non-breaking `Changed`/`Deprecated` |
| major `X.0.0` | breaking, large or infrastructural changes | `Removed`, `**Breaking:**`, stack/architecture changes |

Unsure between two levels: ask with the concrete change list. Repo-specific:
- `soda_scs_manager`: branch `4.x`, tags `4.Y.Z`.
- `scs-manager-image`: tags `3.Y.Z`; Prime pins major `3`, so `4.0.0` only on explicit request.

**3. Changelog.** Rename `## [Unreleased]` to `## [X.Y.Z] - YYYY-MM-DD` (today),
add an empty `## [Unreleased]` above, update compare links only if the file has
them.

**4. Commit + tag.**

```bash
git add CHANGELOG.md   # plus any pinned version file
git commit -m "Release X.Y.Z."
git tag -a X.Y.Z -m "X.Y.Z" -m "<changelog section body>"
```

**5. Push plan + manual steps.** Don't push. Append to `plans/push-plan.txt`:

```text
push <repo-path> <remote> <branch> X.Y.Z
```

Then list what CI does not do:
- **Module** (`origin` = git.drupal.org): also `push … fork 4.x X.Y.Z`, then
  `pause` for the release node (https://www.drupal.org/project/soda_scs_manager →
  *Add new release*, tag `X.Y.Z`, changelog as notes) and
  `wait-drupal soda_scs_manager X.Y.Z`. Without the node nothing is packaged and
  the image keeps the old module.
- **Image**: check *Publish SCS Manager Docker Images* in GitHub Actions; the tag
  publishes `X.Y.Z`, `X.Y` and `X`. After the image `push`, add
  `gh-release <path> <tag>` so the script creates the GitHub Release from the
  annotated tag (same for other GitHub-hosted tags such as wisski-base-*).
- **Optional (local):** add a `todo Optional (local): …` with the `docker build`
  that tags `ghcr.io/soda-collections-objects-data-literacy/<image>:X.Y.Z` (and
  `:local` / `:main` as needed) so this host can test without waiting for CI.
  Exact commands: `/scs-release-prep` → *Optional — local image builds*.

The user runs `01_scripts/global/push-release-plan.bash`.

## Hard rules

- Tags are always plain `X.Y.Z`, never `vX.Y.Z`, and always annotated.
- Never tag a dirty tree. Never move or delete a tag that may be pushed — cut the
  next version instead.
- Never force-push.
