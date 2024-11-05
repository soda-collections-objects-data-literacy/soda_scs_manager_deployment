#!/bin/bash
export $(cat .env) > /dev/null 2>&1;

docker stack deploy --detach=true --with-registry-auth -c docker-compose.yml scs-manager
