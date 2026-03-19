#!/bin/bash
# Zscaler Virtual Service Edge — cloud-init bootstrap
# Variables are injected by Terraform templatefile().
#
# Refer to the Zscaler Deployment Guide for your cloud version for the
# authoritative provisioning key format and additional configuration options.

# Write the provisioning key so the VSE agent can register with the ZIA cloud.
cat > /etc/zscaler/provision_key <<'ZKEY'
${provision_key}
ZKEY

# Set the Zscaler cloud name the VSE should connect to.
sed -i "s|^CLOUD=.*|CLOUD=${cloud_name}|" /etc/zscaler/config 2>/dev/null || \
  echo "CLOUD=${cloud_name}" >> /etc/zscaler/config

# Start / restart the VSE service after configuration is written.
systemctl enable zscaler 2>/dev/null || true
systemctl restart zscaler 2>/dev/null || true
