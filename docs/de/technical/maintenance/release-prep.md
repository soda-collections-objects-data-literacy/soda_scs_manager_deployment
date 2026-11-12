# Release vorbereiten und pushen

Der Skill `scs-release-prep` bereitet alle offenen SCS-Änderungen so vor, dass nur noch gepusht werden muss. Danach nennt er jeden Schritt, den keine CI erledigt. Er liegt in `.cursor/skills/scs-release-prep/`. `.claude/skills/` verlinkt dorthin, damit Cursor und Claude Code dieselbe Datei lesen. Aufruf: `/scs-release-prep`.

Für ein einzelnes Repo gibt es `/git-commit` (nur committen) und `/release` (Version und Tag).

## Was der Skill macht

Er prüft das Deployment, alle Submodule, das Modul `soda_scs_manager`, das Theme `scs_custom_theme` und `repos/scs-manager-image`. Er zeigt einen Plan und fragt einmal nach. Danach:

1. Er committet die Änderungen in logischen Commits, das innerste Repo zuerst.
2. Er trägt jede sichtbare Änderung unter `[Unreleased]` im `CHANGELOG.md` des Repos ein.
3. Er released das Modul (`4.x.y`) und das Image (`3.x.y`), wenn Prime sie braucht. Tags haben kein `v` und sind annotiert.
4. Er committet die neuen Submodule-Zeiger im Deployment.
5. Er schreibt `plans/push-plan.txt`, prüft den Plan mit einem Dry Run und listet die Handgriffe.

Der Skill pusht nie.

## Pushen

```bash
cd /var/www/deploy/soda_scs_manager_deployment
01_scripts/global/push-release-plan.bash --dry-run
01_scripts/global/push-release-plan.bash
```

Der Dry Run arbeitet offline mit dem zuletzt geholten Stand der Remotes und fragt nicht nach der Passphrase. Der echte Lauf lädt den SSH-Key einmal in einen `ssh-agent` und pusht danach alle Zeilen des Plans der Reihe nach. GitHub-Remotes mit `https://` werden ebenfalls über SSH gepusht.

Ein zweiter Lauf ist ungefährlich, schon gepushte Refs sind aktuell. Nach dem Lauf liegt der Plan als `plans/push-plan.done-<Zeitstempel>.txt` daneben.

## Was nicht automatisch passiert

Der Skill schreibt diese Schritte in den Plan. Für jedes Modul-Release legt er `plans/release-notes-soda_scs_manager-X.Y.Z.md` an, mit Kurzbeschreibung und HTML-Release-Notes für drupal.org. Das Skript zeigt die Datei mit `show` direkt vor dem Schritt an, hält bei `pause` an und gibt die `todo`-Punkte am Ende als Checkliste aus.

| Wann | Schritt |
| --- | --- |
| Während des Pushs, Modul-Tag | Auf [drupal.org](https://www.drupal.org/project/soda_scs_manager) mit *Add new release* das Release-Node für den Tag anlegen und den Changelog-Abschnitt als Release Notes einfügen. Ohne das Node packt drupal.org nichts, und das Image baut weiter das alte Modul. Das Skript wartet, bis die Version gelistet ist, und pusht erst dann den Image-Tag. Nach 60 Minuten bricht es ab (`WAIT_TIMEOUT` in Sekunden ändert das). |
| Nach dem Push, Image-Tag | Prüfen, ob [Publish SCS Manager Docker Images](https://github.com/soda-collections-objects-data-literacy/scs-manager-image/actions) grün ist. |
| Nach dem Push, Tag in einem GitHub-Repo | Die Planzeile `gh-release <pfad> <tag>` legt das GitHub-Release aus der annotierten Tag-Message an (überspringt, wenn es schon existiert). |
| Auf Prime | `./01_scripts/global/update-stack.bash --prime --check`, dann `--apply`. Siehe [Kurzablauf](dev-to-prime.md#kurzablauf). |
| Auf Prime, Drupal | Der Entrypoint führt `drush updatedb` aus, aber nie `config:import`. Neue Config aus dem Modul braucht ein Update-Hook. Neue Einstellungen und API-Keys unter `/admin/config/soda-scs-manager/settings` setzen. Drush-Befehle aus dem Changelog von Hand ausführen. |

## Planformat

```text
push <repo-pfad> <remote> <refspec>...
gh-release <repo-pfad> <tag>
show <datei>
pause <text>
wait-drupal <projekt> <version>
note <text>
todo <text>
```

Pfade sind relativ zum Deployment. Zeilen, die mit `#` beginnen, sind Kommentare.
