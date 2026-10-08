# Codex progress

## Waiting on the owner

- None from Codex's work yet.

## Rulings

- 2026-10-08 · Phase 6e locale save: use the signed-in viewer ID to decide whether a language choice is saved to `/me/locale`. A pending `/me` response does not establish that the player is signed out. Cost if wrong: a choice may wait for the session's first value before completing; the server still authorizes the write.

## Not verified

- Phase 5 and Phase 6e physical-device passes remain pending by the owner's choice; see `TESTING-NOTES.md`.
- No Phase 6e write endpoint has been exercised against a live server in this takeover.

## Landed slices

- 2026-10-08 · Phase 6e locale persistence · `fix/6e-locale-save` → mobile `c6ed0bd` (web: none) · mobile `flutter test`: 1,528 passed; `flutter analyze`: no issues · Ruling: viewer ID, rather than `/me` loading state, determines whether to save. Riverpod retained the previous `/me` value during an ordinary refetch, so the handoff's stated refetch bug did not reproduce; the signed-in first-load case did fail and was fixed. Open items: the remaining Phase 6e leftovers, then Phase 6d onward; device pass pending.
