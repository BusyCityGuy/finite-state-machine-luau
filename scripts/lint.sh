#!/bin/sh

set -e

echo "Beginning linting on $1..."

$HOME/.rokit/bin/selene $1

echo "Linting $1 complete!"