#!/bin/sh

set -e

echo "Starting test runner..."

$HOME/.rokit/bin/lune run test

echo "Test runner complete!"