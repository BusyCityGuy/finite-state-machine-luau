#!/bin/sh

set -e

echo "Creating sourcemap from $1 to $2..."

$HOME/.rokit/bin/rojo sourcemap $1 --output $2

echo "Sourcemap $2 created!"