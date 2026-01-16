#!/bin/bash
set -euo pipefail

# Build Lambda layer with Python dependencies
LAYER_DIR="lambda-layer"
rm -rf "${LAYER_DIR}"
mkdir -p "${LAYER_DIR}/python"

pip3 install -r terraform/modules/github-runner/lambda/requirements.txt -t "${LAYER_DIR}/python"

cd "${LAYER_DIR}"
zip -r ../lambda-layer.zip . -q
cd ..
rm -rf "${LAYER_DIR}"

echo "Lambda layer built: lambda-layer.zip"