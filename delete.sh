#!/bin/bash
docker compose down
docker compose build
rm -rf ./volumes