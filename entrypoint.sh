#!/usr/bin/env bash
set -euo pipefail

: "${PLUGIN_SITE:?site is required}"
: "${PLUGIN_HOST:?host is required}"
: "${PLUGIN_SSH_KEY:?ssh_key is required}"
: "${PLUGIN_KNOWN_HOSTS:?known_hosts is required}"
: "${CI_COMMIT_SHA:?CI_COMMIT_SHA is not set}"
SOURCE="${PLUGIN_SOURCE:-_site}"
USER_="${PLUGIN_USER:-deploy}"
PORT="${PLUGIN_PORT:-22}"
RELEASE="$(date -u +%Y%m%d%H%M%S)-${CI_COMMIT_SHA:0:7}"

mkdir -p ~/.ssh && chmod 700 ~/.ssh
printf '%s\n' "$PLUGIN_SSH_KEY" > ~/.ssh/id_ed25519
printf '%s\n' "$PLUGIN_KNOWN_HOSTS" > ~/.ssh/known_hosts
chmod 600 ~/.ssh/id_ed25519

# HostKeyAlias makes ssh look up the host key under the plain host, so the
# known_hosts line doesn't need the [host]:port form on other ports.
SSH="ssh -o BatchMode=yes -o HostKeyAlias=$PLUGIN_HOST -p $PORT"
DEST="$USER_@$PLUGIN_HOST"

echo "Uploading $SOURCE → $PLUGIN_SITE/releases/$RELEASE"
# Compare by checksum, not mtime: a fresh CI build touches every file, so
# without it --link-dest would never hardlink anything. Paths are relative to
# the rrsync root (/srv/sites), and rrsync rejects "..", so link-dest is
# anchored with a leading slash.
rsync -rlpz --checksum --chmod=D755,F644 -e "$SSH" \
  --link-dest="/$PLUGIN_SITE/current/" \
  "$SOURCE/" "$DEST:$PLUGIN_SITE/releases/$RELEASE/"

$SSH "$DEST" activate "$PLUGIN_SITE" "$RELEASE"
