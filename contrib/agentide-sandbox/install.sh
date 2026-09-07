#!/usr/bin/env bash
# Install the AgentIDE Linux sandbox helper for the invoking user.
# Requires root (via sudo) and bubblewrap (`bwrap`).
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run as root: sudo $0" >&2
  exit 1
fi

if [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != root ]]; then
  HOST="${SUDO_USER}"
else
  HOST="${1:-}"
fi

if [[ -z "${HOST}" || "${HOST}" == root ]]; then
  echo "Usage: sudo $0 [host-user]" >&2
  echo "Pass the GUI login name when not installing through sudo." >&2
  exit 2
fi

if ! id -u "${HOST}" >/dev/null 2>&1; then
  echo "Host user ${HOST} does not exist." >&2
  exit 1
fi

if ! command -v bwrap >/dev/null 2>&1; then
  echo "bubblewrap (bwrap) is required; install it first." >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SANDBOX_USER="sandvault-${HOST}"
SHARED="/var/lib/agentide/${HOST}"
HOME_DIR="/home/${SANDBOX_USER}"
LIBEXEC="/usr/libexec/agentide"
SUDOERS="/etc/sudoers.d/agentide-${HOST}"

if ! id -u "${SANDBOX_USER}" >/dev/null 2>&1; then
  useradd --create-home --home-dir "${HOME_DIR}" \
    --shell /bin/bash --user-group "${SANDBOX_USER}"
fi

mkdir -p "${SHARED}/tmp/agentide" "${LIBEXEC}"
chown "${HOST}:${SANDBOX_USER}" "${SHARED}"
chmod 2770 "${SHARED}"

if command -v setfacl >/dev/null 2>&1; then
  setfacl -m "u:${HOST}:rwx,u:${SANDBOX_USER}:rwx" "${SHARED}"
  setfacl -d -m "u:${HOST}:rwx,u:${SANDBOX_USER}:rwx" "${SHARED}"
fi

install -m 0755 "${SCRIPT_DIR}/enter" "${LIBEXEC}/enter"

sed "s/\$HOST/${HOST}/g" "${SCRIPT_DIR}/sudoers" >"${SUDOERS}"
chmod 0440 "${SUDOERS}"
if command -v visudo >/dev/null 2>&1; then
  if ! visudo -cf "${SUDOERS}"; then
    rm -f "${SUDOERS}"
    echo "sudoers failed visudo; not installed." >&2
    exit 1
  fi
fi

mkdir -p "${SHARED}/tmp/agentide"
chown "${HOST}:${SANDBOX_USER}" "${SHARED}/tmp" "${SHARED}/tmp/agentide" || true
chmod 2770 "${SHARED}/tmp" || true

echo "Installed AgentIDE sandbox for ${HOST} -> ${SANDBOX_USER}"
echo "Shared workspace: ${SHARED}"
echo "Entry helper: ${LIBEXEC}/enter"
echo "Verify: ${SCRIPT_DIR}/verify.sh ${HOST}"
