# project-api

## What is patched

Upstream already has `POST /data/projects` (API key required). This patch fills the gaps SCS Manager needs for one ontology project per SCS project.

**Changed**

- `CreateNewProjectActionHandler` — `CAN_MANAGE` + `PROJECT_DOWNLOADER` for **both** the API-key caller **and** `projectOwner` when they differ
- `ProjectResource` — `DELETE /data/projects/{id}` moves the project to trash; locates `collaborators`

**New**

- `ProjectCollaboratorManager` — additive role updates (does not replace the full sharing-settings set)
- `CollaboratorsResource` + `CollaboratorPermission`
  - `PUT /data/projects/{id}/collaborators/{userName}` body `{ "permission": "EDIT" }` (also `VIEW`, `COMMENT`, `MANAGE`)
  - `DELETE /data/projects/{id}/collaborators/{userName}`
- Unit tests for owner roles, collaborator grant/revoke, and the REST wrapper

The owner cannot be changed as a collaborator. The actor needs `EDIT_SHARING_SETTINGS` (the API-key user has `CAN_MANAGE` after create). Roles hang on the `UserId` **string**; the WebProtégé user does not need to exist yet. OIDC later matches the same sanitised name.

## New function

SCS Manager can:

1. Create an ontology project owned by the SCS project owner (`POST /data/projects`)
2. Grant members `EDIT` without wiping owner roles
3. Revoke a member (never the owner)
4. Trash the ontology project when the SCS project is deleted

Auth remains `Authorization: apikey <key>`. Session cookies are not enough for create.
