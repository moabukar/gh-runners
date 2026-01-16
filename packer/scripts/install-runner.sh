#!/bin/bash
set -euo pipefail

RUNNER_VERSION="${RUNNER_VERSION:-2.320.0}"

sudo useradd -m -s /bin/bash runner || true
sudo usermod -aG docker runner 2>/dev/null || true

cd /home/runner
sudo -u runner mkdir -p actions-runner && cd actions-runner
sudo -u runner curl -fsSL -o actions-runner.tar.gz \
  "https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz"
sudo -u runner tar xzf actions-runner.tar.gz
sudo -u runner rm -f actions-runner.tar.gz
sudo ./bin/installdependencies.sh
sudo chown -R runner:runner /home/runner/actions-runner

echo "GitHub runner ${RUNNER_VERSION} installed"
