#!/usr/bin/env bash

# Set strict error handling
set -euo pipefail

SECRETS_FILE="$HOME/.dotfiles/home/modules/settings/secrets/secrets.env"

# Check if secrets file exists and is readable
if [[ -f "$SECRETS_FILE" && -r "$SECRETS_FILE" ]]; then
    # Check if file has proper permissions (readable only by owner)
    if [[ "$(stat -c %a "$SECRETS_FILE")" != "600" ]]; then
        echo "Warning: Secrets file should have permissions 600 (current: $(stat -c %a "$SECRETS_FILE"))"
    fi
    
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Skip comments and empty lines
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line// }" ]] && continue
        
        # Export the variable
        export "$line"
    done < "$SECRETS_FILE"
else
    echo "Warning: Secrets file not found or not readable: $SECRETS_FILE"
fi

# README:
# To add secrets create a "secrets.env" file in this directory (~/.dotfiles/home/modules/settings/secrets/secrets.env). And add your secrets (ANTHROPIC_API_KEY=my-api-key)
# Make sure the both files have the correct permissions:
# chmod 700 ~/.dotfiles/home/modules/settings/secrets/load-secrets.sh
# chmod 600 ~/.dotfiles/home/modules/settings/secrets/secrets.env
