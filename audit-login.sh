#!/bin/bash
#
# audit-login.sh — read-only macOS login-subsystem audit
#
# Transcribed from a real incident-triage session (April 2026): after a
# remote-support session, an unexpected "Other User" option appeared at the
# macOS login screen and survived a full OS reinstall. Rather than assume
# the worst, I audited the loginwindow preferences, the Directory Services
# user list, hidden-user flags, and root status — evidence before conclusions.
#
# Everything here is read-only. Nothing is changed, disabled, or deleted.
# Some checks need sudo to read system preferences.
#
# Tested on macOS 10.15.7. Concepts apply to later macOS releases;
# preference domains and dscl output may vary.

set -u

say() { printf '\n--- %s ---\n' "$1"; }

say "1. loginwindow preferences (what the login screen is configured to show)"
sudo defaults read /Library/Preferences/com.apple.loginwindow 2>/dev/null \
  || echo "(could not read — try running with sudo)"

say "2. real local users (UID >= 500)"
dscl . list /Users UniqueID 2>/dev/null | awk '$2 >= 500 {print}'

say "3. root account status (read-only)"
# NOTE: `dsenableroot -q` does not exist on macOS 10.15 (I tried it first —
# "illegal option"). Reading the root record directly is the working check.
dscl . -read /Users/root AuthenticationAuthority 2>/dev/null \
  || dscl . -read /Users/root 2>/dev/null \
  || echo "(no root record readable)"

say "4. hidden-user flags for every local account"
for u in $(dscl . list /Users 2>/dev/null | grep -v '^_'); do
  dscl . -read "/Users/$u" IsHidden UniqueID 2>/dev/null | paste - - 2>/dev/null
done

say "5. loginwindow plist, parsed (cross-check against step 1)"
sudo plutil -p /Library/Preferences/com.apple.loginwindow.plist 2>/dev/null \
  || echo "(could not read — try running with sudo)"

say "done — compare the user list against the accounts you expect to exist."
