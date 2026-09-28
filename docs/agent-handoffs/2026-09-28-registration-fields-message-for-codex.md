# Message for Codex — bring tournament registration/waitlist onto the new per-game fields contract

Paste everything below the line into a Codex session opened in `C:\Users\gorok\sentinelx_mobile`.

---

You're fixing a breaking-API-contract gap in the mobile app's tournament registration flow. This
was flagged by another Claude session monitoring the web repo and confirmed against this repo's
code: the web repo (`C:\Users\gorok\Videos\sentinelx`, `origin/main` as of commit `630b2b4`, feature
"Per-Game Registration Fields") replaced the old fixed `clubName`/`ignTag` registration fields with a
per-game dynamic field catalogue. **This is already live in production** (the mobile API is
versionless — there is no old-contract fallback to keep working against). This repo's registration
screen still sends the old shape, so registration/waitlist submissions from the current app build
will fail validation against the live API today.

**Read first**
1. `CLAUDE.md` and `AGENTS.md` in this repo — the production-database caution (Supabase project
   `itxubrkbropttfdackmi`, no dev/staging instance for read-only work; never test writes against
   production) and the `ApiClient`/`api/openapi.json` contract rules bind you.
2. The web spec that describes the change in full:
   `C:\Users\gorok\Videos\sentinelx\docs\superpowers\specs\2026-09-27-game-designer-registration-fields-design.md`
   (§ "Mobile impact"), and the web implementation plan
   `2026-09-27-per-game-registration-fields.md` in the same directory, if you want the server-side
   reasoning. You are not touching the web repo — this is read-only context.

## What changed on the server (verified against `origin/main` @ 630b2b4)

- **New endpoint**, public (no auth): `GET /api/mobile/v1/tournaments/{id}/registration-fields` →
  `{ data: { fields: RegistrationField[] } }` where each field is:
  ```
  { fieldKey: string, label: string, placeholder: string | null,
    inputType: 'text' | 'number' | 'url', required: boolean,
    validationPattern: string | null, validationMessage: string | null }
  ```
  This is the per-game field catalogue (e.g. Free Fire might declare `in_game_uid`, a future Roblox
  tournament might declare a Roblox username field) — render one form control per entry, in the
  array's given order.
- **Changed request bodies** on both `POST /tournaments/{id}/register` and
  `POST /tournaments/{id}/waitlist`: the old top-level `clubName` (required) / `ignTag` (optional)
  fields are **gone**, replaced by a single required `registrationDetails: Record<string, string>`
  map (default `{}` if you must send something, but always send one key per field the catalogue
  declared — omitted keys are treated as `''` server-side, which fails a `required` field's
  validation). Keys are each field's `fieldKey` from the catalogue; values are always strings
  (a `number`/`url` `inputType` is still transported as its string form — the server's own zod
  schema only ever validates strings here, there is no numeric coercion).
- **Server-side validation of `registrationDetails` no longer reports per-field errors.** The old
  `clubName`/`ignTag` were top-level body properties, so a validation failure on them came back
  through the generic `ApiError.fields` map (`{"clubName": "Club is required"}`) that this repo's
  `ApiException.fields` already parses generically
  (`lib/core/api/api_client.dart` around line 165). The new dynamic-field validation is a *business*
  validation step inside the handler (not the request-body schema), and on failure it throws a flat
  `400 validation_failed` with only a single `message` string — no `fields` map entry for the
  specific `fieldKey` that failed. **Practical consequence: don't rely on server-returned per-field
  errors for the dynamic fields.** Validate client-side against each field's own `required` /
  `validationPattern` / `validationMessage` (exactly what the catalogue gives you) before submit, and
  treat a `validation_failed` response on `registrationDetails` as a general form-level error banner,
  not a per-field one. (`displayName`/`whatsapp`/`agreedToRules`/`coinsUsed` are unaffected — those
  are still top-level body properties and still report through `ApiError.fields` normally.)
- **Cosmetic, not breaking, but worth doing in the same pass:** the bracket/standings row shape
  (`GET .../bracket` or wherever `lib/core/api/match_models.dart`'s `StandingRow.clubName` is parsed
  from) keeps the **same wire field name** `clubName` for backward compatibility, but it is no longer
  literally a club name — server-side it's now `pickDisplayValue()`, the first non-empty field in
  the tournament's own game-declared order. If this repo's bracket/standings UI ever labels that
  column "Club" anywhere, that label is now wrong for non-football games. Check
  `lib/features/bracket/*` for such a label; fix it to something generic ("ID" or no label at all,
  matching whatever web does) only if you find one — don't invent UI that isn't there today.

## What to change in this repo

Work in a new worktree, not the primary checkout: `git worktree add ..\sentinelx_mobile-regfields -b
fix/tournament-registration-fields-contract origin/master` (per `AGENTS.md`'s parallel-work rule).

Strict TDD — failing test first, watch it fail, minimal code, green, repeat.

1. **`api/openapi.json`** — copy the real, current contract from the web repo
   (`C:\Users\gorok\Videos\sentinelx\openapi\mobile-v1.json`) over this repo's copy, exactly as
   `CLAUDE.md`/`AGENTS.md` require (never hand-edit it, never merge its text — straight copy). This
   file is a shared hotspot; if another worktree has touched it concurrently, coordinate/rebase, don't
   silently clobber unrelated changes. `test/core/api_contract_test.dart` checks `ApiClient` against
   this file — it will start failing the moment you copy it in, which is expected until step 2 is
   done.

2. **`lib/core/api/api_client.dart`**
   - Add `getTournamentRegistrationFields(String tournamentId)` calling
     `GET /tournaments/{id}/registration-fields`, parsing into a new model (step 3). Register its
     operationId (`getTournamentRegistrationFields`) in `ApiClient.usedOperations`, appended, not
     reformatting the existing map.
   - Change `postTournamentRegister` and `postTournamentWaitlist`'s body construction: replace
     `RegistrationDetails.toJson()`'s `clubName`/`ignTag` keys with a `registrationDetails` map built
     from whatever the dynamic form collected. Keep `Idempotency-Key` header handling on register
     exactly as-is (idempotency policy is unchanged by this feature).

3. **New model, don't cram into `lib/core/api/compete_models.dart`** (per `AGENTS.md`'s "new API
   models go in a new file" rule) — e.g. `lib/core/api/registration_fields_models.dart`:
   - `RegistrationField` (`fieldKey`, `label`, `placeholder`, `inputType` enum `text|number|url`,
     `required`, `validationPattern`, `validationMessage`), with `fromJson`.
   - A client-side validator that mirrors the server's `buildRegistrationSchema` logic closely enough
     to catch what the server would reject: trim, required→non-empty, `validationPattern` (if
     present) compiled with `RegExp` and matched, falling back to `validationMessage` or a generic
     "$label is invalid" message — and **must not crash on an unparseable pattern** (the server's own
     comment in `lib/tournaments/registration-fields.ts` notes a bad pattern can reach the DB via raw
     SQL seeding; wrap `RegExp(pattern)` in a try/catch and skip that one field's pattern check on
     failure, same defensive posture the server takes).

4. **`lib/core/api/compete_models.dart`** — `RegistrationDetails` currently hardcodes `clubName`
   (required) / `ignTag` (optional). Replace with a `Map<String, String> registrationDetails` field
   (or restructure however fits — you own this shape now); `toJson()` emits
   `{'registrationDetails': registrationDetails, ...}` instead of the flat `clubName`/`ignTag` keys.
   `displayName`, `whatsapp`, `agreedToRules` are unchanged.

5. **`lib/features/compete/registration_sheet.dart`** — this is the real work. Replace the two fixed
   `TextFormField`s (`reg-club`, `reg-ign`, lines ~189–202 today) with a **dynamically rendered list**
   built from `getTournamentRegistrationFields()`'s response: one `TextFormField` per catalogue entry,
   in order, with:
   - `keyboardType` chosen from `inputType` (`number` → `TextInputType.number`, `url` →
     `TextInputType.url`, `text` → default).
   - `labelText`/`hintText` (placeholder) taken directly from the field's own `label`/`placeholder` —
     **this is legitimately server-sourced copy, not a CLAUDE.md ARB violation**, the same way a
     tournament's own title or rules text isn't ARB'd. Only the surrounding UI chrome (a loading
     state while the fields fetch is in flight, a fetch-failure retry state, any static heading you
     add) needs ARB keys (en + fr), sourced via `tool/gen_l10n_from_web.dart`'s `app_en.arb`
     if the web repo's `messages/en.json` has an equivalent namespace, otherwise add directly to
     `app_en.arb` per `CLAUDE.md`'s copy rule, then `flutter gen-l10n`.
   - `validator:` wired to the client-side validator from step 3, using that field's own `required`/
     `validationPattern`/`validationMessage`.
   - Loading/error handling for the fields fetch itself: show a loading indicator while it's in
     flight (this is a new async dependency the sheet doesn't have today — `_prefill()` is the
     closest existing pattern for a fire-and-forget async call in `initState`, but this one gates
     form usability, so don't silently swallow a failure the way `_prefill()` does — show a retry
     affordance if the fetch fails, since a broken registration form with no fields is worse than an
     explicit error).
   - Update `_submit()` to build the `registrationDetails` map from the dynamic controllers instead of
     the two fixed ones.
   - Remove `RegistrationValidators.club`/`.ign` (dead code once the fixed fields are gone) — keep
     `.displayName`/`.whatsapp` as-is.

6. **ARB cleanup** — `cmpFieldClub`, `cmpFieldIgn`, `cmpValClub`, `cmpValIgn` (both `app_en.arb` and
   the French equivalent) become dead once the fixed fields are removed. Delete them (grep first to
   confirm nothing else references them) and run `flutter gen-l10n`, committing the regenerated
   output.

7. **Tests** — update every test currently asserting the old shape (found via
   `grep -rn "clubName\|ignTag" test/`): `test/core/compete_models_test.dart`,
   `test/core/api_client_compete_test.dart`, `test/features/compete/registration_sheet_test.dart`,
   `test/features/compete/registration_flow_test.dart`. Add new tests for: rendering N dynamic fields
   from a fixture catalogue, submitting builds the right `registrationDetails` map, a required-field
   validation failure blocks submit client-side, an unparseable `validationPattern` in the fixture
   doesn't crash the form, the fields-fetch-failure retry state. `test/core/match_models_test.dart`'s
   `clubName` assertions on standings rows are unaffected (wire field name unchanged) — leave those.

## Hard rules

- Never test writes against production. This whole flow is a live production write path
  (tournament registration) — verify with unit/widget tests and mocked `ApiClient` responses only.
- No copy hard-coded in Flutter widgets except the server-sourced field label/placeholder/validation
  message, which is data, not UI copy — see step 5.
- `flutter analyze` clean and `flutter test` passing before every commit. After `flutter pub get` /
  `flutter test`, run `git checkout -- linux macos windows` before committing (per `CLAUDE.md`).
- Shared hotspot files (`api_client.dart`, `api/openapi.json`, ARB + generated l10n) — minimal,
  append-only hunks. Do not reformat or rewrap existing code you're not otherwise changing.
- Don't touch other worktrees (`-p2a`, `-p2b`, `-p3a`, `-p3b`, `-integration`, `-auth-hardening`) or
  reset/delete anything without asking.
- Log any deviation from this message as a **Ruling** (what, why, cost if wrong) in your progress
  notes — don't deviate silently.

## When done

Get this reviewed (fresh-context review pass, same as every other phase's changes in this project),
fix findings, re-verify `flutter analyze` / `flutter test`. Once green and reviewed: **merge and push
directly to `origin/master` immediately — no PR.** This is now a standing project rule, not a
one-off: finished work does not sit unmerged. Write a handoff note in `docs/agent-handoffs/` (this
repo) matching the naming/depth of the existing ones: branch, HEAD, test counts, what changed, any
Rulings, and what's explicitly **not** verified (live-server/device behavior — same disclaimer every
prior phase's handoff carries, since this can only be verified against production reads, never a
production write, during development).

Start by copying `openapi.json` and watching `api_contract_test.dart` fail — that's your starting
signal for what `ApiClient` needs.
