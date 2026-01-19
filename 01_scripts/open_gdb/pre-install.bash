#!/bin/bash

set -x

# Load environment variables.
if [ -f .env ]; then
    source .env
fi

# Check if required environment variables are set.
if [ -z "${OPEN_GDB_DOMAIN}" ]; then
    echo "Error: OPEN_GDB_DOMAIN environment variable is not set."
    exit 1
fi

templatePath="00_custom_configs/open_gdb/opengdb_proxy/nginx.conf.tpl"
outputPath="open_gdb/opengdb_proxy/nginx.conf"

if [ ! -f "$templatePath" ]; then
    echo "Error: Template file not found at $templatePath."
    exit 1
fi

mkdir -p "$(dirname "$outputPath")"
envsubst '${OPEN_GDB_DOMAIN}' < "$templatePath" > "$outputPath"

echo "OpenGDB nginx.conf generated at $outputPath."
