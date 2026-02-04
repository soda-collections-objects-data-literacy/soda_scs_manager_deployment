#!/bin/bash
# Download the openrefine linux distro tar.gz

set -euo pipefail

repo="OpenRefine/OpenRefine"
current_tag=$JUPYTERHUB_OPENREFINE_RELEASE_TAG
echo "Current selected OpenRefine version: $current_tag"

latest_tag=$(curl -s "https://api.github.com/repos/$repo/releases/latest" | jq -r '.tag_name')
if [ $current_tag != "latest" ]; then
  echo "Checking for newer versions..."
  if [ $latest_tag != $current_tag ]; then
    echo "Newer version found: $latest_tag". Consider upgrading.
  fi
else
  current_tag="$latest_tag"
fi

tgz_name="openrefine-linux-$current_tag.tar.gz"
download_link="https://github.com/$repo/releases/download/$current_tag/$tgz_name"
lib_name="openrefine-$current_tag" # Extracted dirname

# Download Openrefine into /tmp so it does not clatter...
if [ -f "/tmp/$tgz_name" ]; then
  echo "Found $tgz_name in /tmp. Taking that one..."
else
  echo "Downloading $tgz_name into /tmp..."
  curl -sL -o "/tmp/$tgz_name" "$download_link"
fi

tmpdir="/tmp/$lib_name"
echo "Extracting to $tmpdir..."
mkdir -p "$tmpdir"
tar -xzf "/tmp/$tgz_name" -C "$tmpdir"

# Check for old installation and potentially remove.
if [ -d "$JUPYTERHUB_OPENREFINE_DIR" ]; then
  echo "Removing old OpenRefine installation..."
  rm -r "$JUPYTERHUB_OPENREFINE_DIR"
fi
echo "Moving $tmpdir/$lib_name into $JUPYTERHUB_OPENREFINE_DIR..."
mv "$tmpdir/$lib_name" "$JUPYTERHUB_OPENREFINE_DIR"
rm -r "$tmpdir"
echo "Openrefine downloaded and extracted successfully!"
