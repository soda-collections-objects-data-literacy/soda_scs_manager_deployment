# Developer readme
## Jupyterhub
### Shared volumes
Shared named docker volumes can be accessed with following steps:
- create a named docker volume somewhere i.e. `shared-data`
- insert the volume in ./jupyterhub/.env
 ```env
 JUPYTERHUB_SHARE=shared-data # name of the shared volume
 ```
- restart jupyterhub with
```bash
docker compose down jupyterhub
docker compose up -d jupyterhub
```

