#!/usr/bin/env bash
# Guidance only: WooCommerce must issue API keys. Random local strings are not
# registered credentials, and displaying instructions is not a completed rotation.
set -euo pipefail

case "${1:-}" in
  ''|--help|-h) ;;
  *) printf 'Usage: bash scripts/rotate_woocommerce_keys.sh [--help]\n' >&2; exit 2 ;;
esac
if [ "$#" -gt 1 ]; then
  printf 'Usage: bash scripts/rotate_woocommerce_keys.sh [--help]\n' >&2
  exit 2
fi

cat <<'EOF'
### WooCommerce API Key Rotation Instructions ###

1. Log in to WordPress admin over HTTPS.
2. Open WooCommerce > Settings > Advanced > REST API > Add key.
3. Select the integration user and minimum required permissions.
4. Click 'Generate API key'. Only WooCommerce can issue usable credentials;
   locally generated random strings are NOT registered WooCommerce API keys.
5. Store the issued Consumer key and Consumer secret securely, then update
   every integration (including n8n and scripts). Never paste secrets into logs.
6. Verify the new credentials work for every integration's required operations.
7. Revoke the old keys and verify integrations still work.
8. ONLY after completing and verifying the rotation, update the date and
   **Last rotated:** field in memory/security/woocommerce-key-rotation.md.
   Update the fingerprint to the first 12 characters of the issued key's SHA-256
   (not the key itself). Preserve the tracker's existing history.

Guidance only: no credentials generated, no tracker changed, no API calls made.
The health-check warning remains until a real rotation has been completed
and its verified completion date recorded.
EOF
