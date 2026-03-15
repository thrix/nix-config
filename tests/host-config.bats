#!/usr/bin/env bats
#
# Unit tests for the host-config module shell logic.
# Sources modules/host-config-lib.sh directly so tests exercise the real code.

# shellcheck source=../modules/host-config-lib.sh
source "${BATS_TEST_DIRNAME}/../modules/host-config-lib.sh"

# ---------------------------------------------------------------------------
# Setup / teardown
# ---------------------------------------------------------------------------

setup() {
  FAKE_HOME=$(mktemp -d)
  FAKE_STORE=$(mktemp -d)
  echo "content" > "$FAKE_STORE/real-file"
  mkdir -p "$FAKE_HOME/.config/sway"
  ln -s "$FAKE_STORE/real-file" "$FAKE_HOME/.config/sway/config"
}

teardown() {
  rm -rf "$FAKE_HOME" "$FAKE_STORE"
}

# ---------------------------------------------------------------------------
# _hc_create_file tests
# ---------------------------------------------------------------------------

@test "_hc_create_file: symlink becomes real file with correct content and perms" {
  local file="$FAKE_HOME/.config/sway/config"

  _hc_create_file "$file"

  # must no longer be a symlink
  [ ! -L "$file" ]
  # must be a regular file with the right content
  [ -f "$file" ]
  [ "$(cat "$file")" = "content" ]
  # must be mode 644
  [ "$(stat -c '%a' "$file")" = "644" ]
  # .lnk must hold the original symlink backup (used by _hc_restore_file before next switch)
  [ -L "${file}.lnk" ]
}

@test "_hc_create_file: idempotent — plain file is left untouched on second run" {
  local file="$FAKE_HOME/.config/sway/config"

  _hc_create_file "$file"

  local mtime_before
  mtime_before=$(stat -c '%Y' "$file")

  sleep 1
  _hc_create_file "$file"

  local mtime_after
  mtime_after=$(stat -c '%Y' "$file")

  [ "$mtime_before" = "$mtime_after" ]
}

@test "_hc_create_file: cp failure leaves symlink intact and no .lnk created" {
  local file="$FAKE_HOME/.config/sway/config"

  # make the directory non-writable so cp cannot create the .new temp file
  chmod 555 "$FAKE_HOME/.config/sway"

  run _hc_create_file "$file"
  [ "$status" -ne 0 ]

  chmod 755 "$FAKE_HOME/.config/sway"

  # symlink must still be intact
  [ -L "$file" ]
  # no .lnk backup should have been created
  [ ! -e "${file}.lnk" ]
}

# ---------------------------------------------------------------------------
# _hc_restore_file tests
# ---------------------------------------------------------------------------

@test "_hc_restore_file: restores .lnk symlink back to original path" {
  local file="$FAKE_HOME/.config/sway/config"

  # Start from the state _hc_create_file leaves: real file at $file, .lnk is symlink backup
  _hc_create_file "$file"
  [ -f "$file" ]
  [ -L "${file}.lnk" ]

  _hc_restore_file "$file"

  # .lnk must be gone
  [ ! -e "${file}.lnk" ]
  # original path must now be a symlink again
  [ -L "$file" ]
}

@test "_hc_restore_file: cleans up leftover .new temp file" {
  local file="$FAKE_HOME/.config/sway/config"

  # Simulate a leftover .new file from a previous partial run
  touch "${file}.new"

  _hc_restore_file "$file"

  [ ! -e "${file}.new" ]
}
