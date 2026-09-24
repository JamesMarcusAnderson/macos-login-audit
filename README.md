# macOS Login Audit

A defensive, read-only runbook for triaging a suspicious macOS login screen —
transcribed from a real incident I worked in April 2026.

## The situation

After a remote-support session touched my machine, an unexpected **"Other
User"** option appeared at the macOS 10.15.7 login screen — and it survived a
full OS reinstall. That persistence is what made it worth investigating
properly instead of shrugging it off.

## The approach

Evidence before conclusions. Every step below is **read-only**: nothing is
changed, disabled, or deleted. The goal is to answer one question — *is the
login window showing something the system shouldn't have?* — with data
instead of guesses.

## The audit

**1. Read the loginwindow preferences** — what the login screen is configured
to display (guest access, hidden users, last-logged-in user):

```bash
sudo defaults read /Library/Preferences/com.apple.loginwindow
```

**2. List real local users** — every account with a UID of 500 or above:

```bash
dscl . list /Users UniqueID | awk '$2 >= 500 {print}'
```

**3. Check root account status** — read-only. (My first attempt,
`dsenableroot -q`, failed: that flag doesn't exist on 10.15. Reading the
record directly is the working check:)

```bash
dscl . -read /Users/root AuthenticationAuthority
```

**4. Check hidden-user flags** — a legitimate-looking account with `IsHidden`
set won't appear in normal user listings:

```bash
for u in $(dscl . list /Users | grep -v '^_'); do
  dscl . -read /Users/"$u" IsHidden UniqueID 2>/dev/null | paste - - 2>/dev/null
done
```

**5. Cross-check the plist** — parse the raw loginwindow plist and compare
against step 1, in case the defaults cache and the file disagree:

```bash
sudo plutil -p /Library/Preferences/com.apple.loginwindow.plist
```

## What you're looking for

- Accounts you don't recognize (especially UID ≥ 500)
- `IsHidden` set on an account you didn't hide
- `GuestEnabled` or other loginwindow settings you didn't choose
- Disagreement between the plist file and what `defaults` reports

## Script

`audit-login.sh` runs all five checks in one pass. `chmod +x` it and run it
whenever a login screen looks wrong:

```bash
chmod +x audit-login.sh
./audit-login.sh
```

## Philosophy

When a manual approach isn't trusted, gather evidence first. I triage
endpoints the same way I debug hardware: read the actual state, compare it
against what should be there, and only then decide what to do about it.

*Defensive security only. This repo contains no exploit material — just the
audit I ran on my own machine.*
