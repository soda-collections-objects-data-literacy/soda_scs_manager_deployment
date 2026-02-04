#!/bin/bash
set -e

echo "Configuring Varnish backend..."
echo "Backend host: ${VARNISH_BACKEND_HOST}"
echo "Backend port: ${VARNISH_BACKEND_PORT}"

# Ensure environment variables are set
if [ -z "${VARNISH_BACKEND_HOST}" ]; then
  echo "ERROR: VARNISH_BACKEND_HOST is not set!"
  exit 1
fi

if [ -z "${VARNISH_BACKEND_PORT}" ]; then
  echo "ERROR: VARNISH_BACKEND_PORT is not set!"
  exit 1
fi

# Set defaults
VARNISH_SIZE=${VARNISH_SIZE:-256M}

# Substitute environment variables in VCL template
envsubst '${VARNISH_BACKEND_HOST} ${VARNISH_BACKEND_PORT}' < /etc/varnish/default.vcl.tpl > /etc/varnish/default.vcl

echo "VCL configuration after substitution:"
grep -A 2 "backend default" /etc/varnish/default.vcl || true

echo "Starting Varnish..."
exec /usr/sbin/varnishd -F \
  -f /etc/varnish/default.vcl \
  -a :80 \
  -s malloc,${VARNISH_SIZE}
