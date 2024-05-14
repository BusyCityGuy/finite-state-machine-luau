#!/bin/sh

set -e

echo "Starting test runner..."

$HOME/.aftman/bin/lune run runTests

echo "Test runner complete!"