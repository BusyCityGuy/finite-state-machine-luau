#!/bin/sh

set -e

echo "Creating sourcemap from $1 to $2..."

$HOME/.aftman/bin/rojo sourcemap $1 --output $2

echo "Sourcemap created!"