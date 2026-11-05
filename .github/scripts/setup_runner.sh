#!/usr/bin/env bash
# Setup GitHub Actions self-hosted runner on Scaleway Mac
# Usage: bash setup_runner.sh <GITHUB_TOKEN> <REPO> <RUNNER_NAME>
# Example: bash setup_runner.sh ghp_xxx tungtt2589/nxnative-create-game-iphone nxnative-scaleway-m4

set -euo pipefail

GITHUB_TOKEN="${1:?Need GITHUB_TOKEN}"
REPO="${2:?Need REPO (owner/repo)}"
RUNNER_NAME="${3:-scaleway-m4-runner}"
RUNNER_DIR="$HOME/actions-runner"

echo "=== [1/5] Install Homebrew packages ==="
export HOMEBREW_NO_AUTO_UPDATE=1
brew install xcodegen zstd glslang unar rclone 2>&1 | tail -5 || true

echo "=== [2/5] Install Python deps ==="
pip3 install lz4 "capstone>=5,<6" fonttools nsz zbic gdown backports.zstd 2>&1 | tail -5

echo "=== [3/5] Install .NET 10 ==="
if ! command -v dotnet &>/dev/null; then
  curl -fsSL https://dot.net/v1/dotnet-install.sh | bash /dev/stdin --channel 10.0
  echo 'export PATH="$HOME/.dotnet:$PATH"' >> ~/.zprofile
  export PATH="$HOME/.dotnet:$PATH"
fi
dotnet --version

echo "=== [4/5] Install GitHub Actions runner ==="
mkdir -p "$RUNNER_DIR" && cd "$RUNNER_DIR"

RUNNER_VERSION=$(curl -s https://api.github.com/repos/actions/runner/releases/latest | grep '"tag_name"' | cut -d'"' -f4 | tr -d 'v')
RUNNER_URL="https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-osx-arm64-${RUNNER_VERSION}.tar.gz"
echo "Downloading runner v$RUNNER_VERSION..."
curl -fsSL "$RUNNER_URL" -o runner.tar.gz
tar xzf runner.tar.gz
rm runner.tar.gz

echo "=== [5/5] Register runner ==="
REG_TOKEN=$(curl -s -X POST \
  -H "Authorization: Bearer $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/$REPO/actions/runners/registration-token" \
  | python3 -c "import json,sys; print(json.load(sys.stdin)['token'])")

./config.sh \
  --url "https://github.com/$REPO" \
  --token "$REG_TOKEN" \
  --name "$RUNNER_NAME" \
  --labels "scaleway-m4,xcode-27-baremetal" \
  --work "$HOME/_work" \
  --unattended \
  --replace

echo "=== Starting runner as background service ==="
./run.sh &
RUNNER_PID=$!
echo "Runner PID: $RUNNER_PID"
echo $RUNNER_PID > "$RUNNER_DIR/runner.pid"
echo "Runner started. Label: scaleway-m4,xcode-27-baremetal"
