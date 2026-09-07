#!/usr/bin/env bash
# Check that the AgentIDE Linux sandbox is installed and that a
# harmless enter … -- /bin/true succeeds. Skips gracefully when the
# helper is missing, sudoers is absent, or this process cannot use
# passwordless sudo to the sandvault user.
set -euo pipefail

HOST="${1:-${SUDO_USER:-${USER:-}}}"
if [[ -z "${HOST}" || "${HOST}" == root ]]; then
  echo "verify: pass the GUI login name: $0 <host-user>" >&2
  exit 2
fi

LIBEXEC_ENTER="/usr/libexec/agentide/enter"
SUDOERS="/etc/sudoers.d/agentide-${HOST}"
SANDBOX_USER="sandvault-${HOST}"
HOME_DIR="/home/${SANDBOX_USER}"
SHARED="/var/lib/agentide/${HOST}"

skip() {
  echo "verify: $*"
  echo "verify: skipped (install with contrib/agentide-sandbox/install.sh)"
  exit 0
}

if [[ ! -x "${LIBEXEC_ENTER}" ]]; then
  skip "${LIBEXEC_ENTER} is not installed"
fi
echo "verify: found ${LIBEXEC_ENTER}"

if [[ ! -f "${SUDOERS}" ]]; then
  skip "${SUDOERS} is not present"
fi
echo "verify: found ${SUDOERS}"

if ! id -u "${SANDBOX_USER}" >/dev/null 2>&1; then
  skip "sandbox user ${SANDBOX_USER} does not exist"
fi

if [[ ! -d "${HOME_DIR}" || ! -d "${SHARED}" ]]; then
  skip "expected directories missing (${HOME_DIR} or ${SHARED})"
fi

# Passwordless sudo to the sandvault user is what the app relies on.
if ! sudo -n --login --set-home --user="${SANDBOX_USER}" \
  /bin/true >/dev/null 2>&1; then
  skip "cannot run passwordless sudo as ${SANDBOX_USER} (not root / no NOPASSWD)"
fi

echo "verify: running enter … -- /bin/true"
if ! sudo -n --login --set-home --user="${SANDBOX_USER}" \
  "${LIBEXEC_ENTER}" \
  --home="${HOME_DIR}" \
  --shared="${SHARED}" \
  --workdir="${SHARED}" \
  --session-id=verify \
  --session-name=verify \
  -- /bin/true; then
  echo "verify: enter failed" >&2
  exit 1
fi

echo "verify: sandbox ok for ${HOST}"
