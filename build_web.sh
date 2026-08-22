#!/usr/bin/env bash
# Flutter Web Build Script - Outputs directly into ./docs
set -e

echo "Building Flutter Web into ./docs ..."
flutter build web --output docs --base-href ./
echo "Successfully built to ./docs"
