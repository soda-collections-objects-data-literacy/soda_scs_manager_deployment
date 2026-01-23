#!/bin/bash

set -x

# Load environment variables.
if [ -f .env ]; then
    source .env
fi

# Download Openrefine.
echo "Downloading Openrefine..."
curl -L -o openrefine-3.9.5.tar.gz https://github.com/OpenRefine/OpenRefine/releases/download/3.9.5/openrefine-linux-3.9.5.tar.gz
tar -xzf openrefine-3.9.5.tar.gz
mv openrefine-3.9.5 openrefine

echo "Openrefine downloaded and extracted successfully."
