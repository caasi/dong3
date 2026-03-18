#!/usr/bin/env bash
set -euo pipefail

REPO="caasi/ocaml-compose-dsl"
BINARY_NAME="ocaml-compose-dsl"
INSTALL_DIR="${HOME}/.local/bin"

# Detect platform
OS="$(uname -s)"
ARCH="$(uname -m)"

case "${OS}-${ARCH}" in
  Linux-x86_64)   ASSET="${BINARY_NAME}-linux-x86_64" ;;
  Darwin-x86_64)  ASSET="${BINARY_NAME}-macos-x86_64" ;;
  Darwin-arm64)   ASSET="${BINARY_NAME}-macos-arm64" ;;
  *)
    echo "Error: unsupported platform ${OS}-${ARCH}" >&2
    exit 1
    ;;
esac

# Get latest release tag
TAG="$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" | grep '"tag_name"' | sed 's/.*"tag_name": *"\([^"]*\)".*/\1/')"

if [ -z "${TAG}" ]; then
  echo "Error: failed to fetch latest release tag" >&2
  exit 1
fi

URL="https://github.com/${REPO}/releases/download/${TAG}/${ASSET}"

echo "Installing ${BINARY_NAME} ${TAG} for ${OS} ${ARCH}..."
echo "  from: ${URL}"
echo "  to:   ${INSTALL_DIR}/${BINARY_NAME}"

mkdir -p "${INSTALL_DIR}"
curl -fsSL -o "${INSTALL_DIR}/${BINARY_NAME}" "${URL}"
chmod +x "${INSTALL_DIR}/${BINARY_NAME}"

echo "Done. Make sure ${INSTALL_DIR} is in your PATH."
