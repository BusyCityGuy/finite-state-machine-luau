#!/bin/sh

set -e

TYPES_FILE=globalTypes.d.lua
SETTINGS_FILE=.luau-lsp.json

if [ ! -f "$TYPES_FILE" ]; then
    echo "Fetching global types..."
    curl https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/main/scripts/globalTypes.d.lua > $TYPES_FILE
    echo "Wrote global types to $TYPES_FILE"
fi

if [ -n "$2" ]; then
    echo "Beginning analysis on $2 with sourcemap from $1, settings from $SETTINGS_FILE, and global types from $TYPES_FILE..."
    $HOME/.aftman/bin/luau-lsp analyze \
        --settings=$SETTINGS_FILE \
        --definitions=$TYPES_FILE \
        --sourcemap "$1" \
        --ignore "*Packages/**" \
        "$2"
else
    echo "Beginning analysis on $1 with settings from $SETTINGS_FILE and global types from $TYPES_FILE..."
    $HOME/.aftman/bin/luau-lsp analyze \
        --settings=$SETTINGS_FILE \
        --definitions=$TYPES_FILE \
        --ignore "*Packages/**" \
        "$1"
fi

echo "Analysis complete!"