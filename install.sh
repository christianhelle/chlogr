#!/usr/bin/env bash
set -euo pipefail

REPO="christianhelle/chlogr"
INSTALL_DIR="${INSTALL_DIR:-$HOME/.local/bin}"
tmp_dir=""

cleanup() {
  if [ -n "${tmp_dir:-}" ] && [ -d "$tmp_dir" ]; then
    rm -rf -- "$tmp_dir"
  fi
}

detect_platform() {
  local os arch
  os="$(uname -s)"
  arch="$(uname -m)"

  case "$os" in
  Linux) os="linux" ;;
  Darwin) os="macos" ;;
  *)
    echo "Unsupported OS: $os" >&2
    exit 1
    ;;
  esac

  case "$arch" in
  x86_64 | amd64) arch="x86_64" ;;
  aarch64 | arm64) arch="aarch64" ;;
  *)
    echo "Unsupported architecture: $arch" >&2
    exit 1
    ;;
  esac

  echo "${os}-${arch}"
}

main() {
  local platform artifact_name url

  platform="$(detect_platform)"
  artifact_name="chlogr-${platform}.tar.gz"

  echo "Detecting platform: ${platform}"

  url="$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" |
    grep -o "\"browser_download_url\": *\"[^\"]*${artifact_name}\"" |
    head -1 |
    cut -d'"' -f4)"

  if [ -z "$url" ]; then
    echo "Error: could not find release asset ${artifact_name}" >&2
    exit 1
  fi

  tmp_dir="$(mktemp -d)"
  trap cleanup EXIT

  echo "Downloading ${url}..."
  curl -fsSL "$url" -o "${tmp_dir}/${artifact_name}"

  echo "Installing to ${INSTALL_DIR}..."
  tar xzf "${tmp_dir}/${artifact_name}" -C "$tmp_dir"
  install -d "$INSTALL_DIR"
  install -m 755 "${tmp_dir}/chlogr" "$INSTALL_DIR/chlogr"

  echo "chlogr installed to ${INSTALL_DIR}/chlogr"
}

main
