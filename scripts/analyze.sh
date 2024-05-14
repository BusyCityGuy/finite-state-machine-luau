#!/bin/sh

set -e

TYPES_FILE=globalTypes.d.lua
SETTINGS_FILE=.luau-lsp.json

if [ ! -f "$TYPES_FILE" ]; then
    echo "Fetching global types..."
    curl https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/main/scripts/globalTypes.d.lua > $TYPES_FILE
    echo "Wrote global types to $TYPES_FILE"
fi

echo "Beginning analysis with settings from $SETTINGS_FILE and global types from $TYPES_FILE..."
if [ -n "$2" ]; then
    $HOME/.aftman/bin/luau-lsp analyze \
        --settings=$SETTINGS_FILE \
        --definitions=$TYPES_FILE \
        --sourcemap "$1" \
        --ignore "*Packages/**" \
        "$2"
else
    $HOME/.aftman/bin/luau-lsp analyze \
        --settings=$SETTINGS_FILE \
        --definitions=$TYPES_FILE \
        --ignore "*Packages/**" \
        "$1"
fi

echo "Analysis complete!"