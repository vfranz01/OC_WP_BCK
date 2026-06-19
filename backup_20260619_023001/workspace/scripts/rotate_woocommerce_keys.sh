#!/bin/bash
# This script documents the steps to rotate WooCommerce API keys and generates a new key pair

echo "### WooCommerce API Key Rotation Instructions ###"
echo ""
echo "1. Log in to your WordPress admin panel."
echo "2. Navigate to WooCommerce > Settings > Advanced > REST API."
echo "3. Click 'Add key'."
echo "4. Provide a description (e.g., 'Rotated API key')."
echo "5. Choose the user you want to generate the key for."
echo "6. Select permissions (Read or Read/Write)."
echo "7. Click 'Generate API key'."
echo "8. Securely store the Consumer key and Consumer secret that are generated."
echo ""
echo "### Generated API key pair ###"
NEW_CONSUMER_KEY=$(openssl rand -hex 16)
NEW_CONSUMER_SECRET=$(openssl rand -hex 32)
echo "New Consumer Key: $NEW_CONSUMER_KEY"
echo "New Consumer Secret: $NEW_CONSUMER_SECRET"
echo ""
echo "### IMPORTANT ###"
echo "After generating the new API keys:"
echo "- Update the keys in any integrations that use the WooCommerce API, such as n8n workflows, custom scripts, etc."
echo "- Once you have confirmed that all integrations are working with the new keys, revoke the old API keys from the WooCommerce REST API settings page."
