#!/bin/sh

set -e

echo "Beginning format check on $1..."

$HOME/.rokit/bin/stylua --check $1

echo "Format check on $1 complete!"