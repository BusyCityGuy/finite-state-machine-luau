#!/bin/sh

set -e

echo "Starting test runner..."

$HOME/.aftman/bin/lune run test

echo "Test runner complete!"