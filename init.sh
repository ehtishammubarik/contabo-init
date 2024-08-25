#!/bin/bash
set -e

# Source the environment variables from the .env file
if [ -f /etc/rancher_init.env ]; then
  source /etc/rancher_init.env
else
  echo "Error: /etc/rancher_init.env file not found."
  exit 1
fi

# Decode the base64 encoded environment variables
RANCHER_SERVER=$(echo "$BASE64_RANCHER_SERVER" | base64 --decode)
API_TOKEN=$(echo "$BASE64_API_TOKEN" | base64 --decode)
CLUSTER_ID=$(echo "$BASE64_CLUSTER_ID" | base64 --decode)

# Debugging: Print decoded values (remove these lines in production)
echo "Decoded RANCHER_SERVER: $RANCHER_SERVER"
echo "Decoded API_TOKEN: $API_TOKEN"
echo "Decoded CLUSTER_ID: $CLUSTER_ID"

# Check if environment variables are set
if [ -z "$RANCHER_SERVER" ] || [ -z "$API_TOKEN" ] || [ -z "$CLUSTER_ID" ]; then
  echo "Error: Required environment variables (RANCHER_SERVER, API_TOKEN, CLUSTER_ID) are not set."
  exit 1
fi

echo "$(date) - Updating system packages..."
sudo DEBIAN_FRONTEND=noninteractive apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y curl wget jq

echo "$(date) - Setting Rancher API details..."
echo "RANCHER_SERVER: $RANCHER_SERVER"
echo "CLUSTER_ID: $CLUSTER_ID"

echo "$(date) - Fetching Rancher cluster registration command..."
RESPONSE=$(curl -s -k -H "Authorization: Bearer $API_TOKEN" "$RANCHER_SERVER/v3/clusterregistrationtoken?clusterId=$CLUSTER_ID")
NODE_REG_CMD=$(echo $RESPONSE | jq -r '.data[0].insecureNodeCommand')

if [[ -z "$NODE_REG_CMD" || "$NODE_REG_CMD" == "null" ]]; then
    echo "$(date) - Failed to fetch node registration command or command is null"
    echo "$(date) - Response from API: $RESPONSE"
    exit 1
fi

WORKER_REG_CMD="$NODE_REG_CMD --worker"
echo "$(date) - Sleeping for 2 minutes before executing registration command..."
sleep 120
echo "$(date) - Executing registration command..."
bash -c "$WORKER_REG_CMD"
echo "$(date) - Registration process completed successfully."
