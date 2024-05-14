#!/bin/sh

set -e

echo "Beginning linting on $1..."

$HOME/.aftman/bin/selene $1

echo "Linting complete!"