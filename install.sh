#!/usr/bin/env bash
# DockerBeam Installer Script
#
# This script downloads the latest release of DockerBeam from GitHub
# and installs it under /usr/local/bin as 'dockerbeam'.
#
# It supports major Linux distributions, auto-detects your architecture,
# and fetches the correct "DockerBeam_linux_<arch>" asset.
#
# Usage:
#   chmod +x install_dockerbeam.sh
#   ./install_dockerbeam.sh

set -euo pipefail

# ----------------------------
# Configuration
# ----------------------------
REPO="dockerbeam/dockerbeam"   
BINARY_BASENAME="DockerBeam_linux"    
FINAL_BINARY_NAME="dockerbeam"       
INSTALL_DIR="/usr/local/bin"         

# ----------------------------
# Check OS
# ----------------------------
if [[ "$(uname -s)" != "Linux" ]]; then
    echo "Error: This installer only supports Linux." >&2
    exit 1
fi

# ----------------------------
# Architecture Normalization
# ----------------------------
normalize_arch() {
    local arch
    arch=$(uname -m)
    case "$arch" in
        x86_64)
            echo "x64"
            ;;
        aarch64|arm64)
            echo "aarch64"
            ;;
        *)
            # For any unrecognized architecture, just return uname output
            echo "$arch"
            ;;
    esac
}

ARCH="$(normalize_arch)"
echo "Detected architecture: $ARCH"

# ----------------------------
# Downloader Detection
# ----------------------------
if command -v curl >/dev/null 2>&1; then
    DOWNLOADER="curl"
elif command -v wget >/dev/null 2>&1; then
    DOWNLOADER="wget"
else
    echo "Error: Either curl or wget is required to download files." >&2
    exit 1
fi

download_file() {
    local url=$1
    local output=$2
    if [ "$DOWNLOADER" = "curl" ]; then
        curl -L --fail "$url" -o "$output"
    else
        wget -O "$output" "$url"
    fi
}

# ----------------------------
# Fetch Latest Release
# ----------------------------
echo "Fetching latest release info for ${REPO}..."
LATEST_JSON=$(curl -s "https://api.github.com/repos/${REPO}/releases/latest")

# Look for an asset matching "DockerBeam_linux_<ARCH>"
ASSET_NAME="${BINARY_BASENAME}_${ARCH}"
DOWNLOAD_URL=$(echo "$LATEST_JSON" | grep "browser_download_url" | grep "$ASSET_NAME" | cut -d '"' -f 4)

if [ -z "$DOWNLOAD_URL" ]; then
    echo "Error: Could not find a download URL for '${ASSET_NAME}' in the latest release." >&2
    exit 1
fi

echo "Found release asset: $DOWNLOAD_URL"

# ----------------------------
# Download & Install
# ----------------------------
TMP_DIR=$(mktemp -d)
trap "rm -rf $TMP_DIR" EXIT
TMP_BIN="${TMP_DIR}/${FINAL_BINARY_NAME}"

echo "Downloading ${ASSET_NAME}..."
download_file "$DOWNLOAD_URL" "$TMP_BIN"

echo "Making the binary executable..."
chmod +x "$TMP_BIN"

echo "Installing '${FINAL_BINARY_NAME}' to '${INSTALL_DIR}'..."
if [ "$(id -u)" -ne 0 ]; then
    if command -v sudo >/dev/null 2>&1; then
        sudo mv "$TMP_BIN" "${INSTALL_DIR}/${FINAL_BINARY_NAME}"
    else
        echo "Error: Root privileges required (sudo not found). Please run as root or install sudo." >&2
        exit 1
    fi
else
    mv "$TMP_BIN" "${INSTALL_DIR}/${FINAL_BINARY_NAME}"
fi

echo "DockerBeam has been installed successfully!"
echo "Run 'dockerbeam' to get started."
