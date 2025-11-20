# Blinder Mac

Blinder is a small macOS menu bar helper that lets you create "focus modes". Each mode is a mix of:

- a timer that counts down however many minutes you set before hitting Start,
- an app blacklist (bundle IDs) that the engine kills whenever they launch or try to come to the foreground, and
- a domain blacklist for Safari, Chrome, Brave, and Edge where the frontmost tab is yanked back to `about:blank` (or closed) whenever you wander off to a blocked site.

## Known gaps

- Only the frontmost tab in Safari/Chrome/Brave/Edge is inspected, so background tabs or other browsers are untouched.
- Blocking an app only works if its bundle ID is in the mode you created; anything new you install must be added manually.
- Browser blocking depends on macOS Automation permissions per browser; if the permission prompt is declined the app can’t enforce sites.

https://github.com/user-attachments/assets/bf161b51-caf1-429f-aa09-69caaab2178a
