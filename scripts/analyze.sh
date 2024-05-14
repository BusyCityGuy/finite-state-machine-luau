#!/bin/sh

set -e

TYPES_FILE=globalTypes.d.lua
SETTINGS_FILE=.luau-lsp.json

if [ ! -f "$TYPES_FILE" ]; then
    curl https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/main/scripts/globalTypes.d.lua > $TYPES_FILE
fi

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