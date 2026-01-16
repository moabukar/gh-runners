#!/bin/bash
set -euo pipefail

# Build Lambda layer with Python dependencies
LAYER_DIR="lambda-layer"
OUTPUT_FILE="${1:-lambda-layer.zip}"

echo "Building Lambda layer..."

# Clean previous build
rm -rf "${LAYER_DIR}" "${OUTPUT_FILE}"

# Create layer structure
mkdir -p "${LAYER_DIR}/python"

# Install dependencies
pip3 install -r terraform/modules/github-runner/lambda/requirements.txt -t "${LAYER_DIR}/python" --no-cache-dir

# Remove unnecessary files to reduce size
find "${LAYER_DIR}/python" -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
find "${LAYER_DIR}/python" -type f -name "*.pyc" -delete 2>/dev/null || true
find "${LAYER_DIR}/python" -type f -name "*.pyo" -delete 2>/dev/null || true

# Create zip
cd "${LAYER_DIR}"
zip -r "../${OUTPUT_FILE}" . -q
cd ..

# Clean up
rm -rf "${LAYER_DIR}"

# Show size
SIZE=$(du -h "${OUTPUT_FILE}" | cut -f1)
echo "✓ Lambda layer built: ${OUTPUT_FILE} (${SIZE})"
echo ""
echo "To use this layer in Terraform, set:"
echo "  lambda_layer_zip_path = \"$(pwd)/${OUTPUT_FILE}\""