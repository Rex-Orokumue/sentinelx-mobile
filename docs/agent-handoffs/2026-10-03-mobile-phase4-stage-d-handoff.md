# Mobile Phase 4 (Community) — Stage D, Flutter build

- Repo: `sentinelx_mobile`, branch `master` (merged fast-forward from `phase4/screens`, no PR, per standing practice)
- HEAD: `b4e4617` — `feat(community): router wiring — feed, compose, post detail, statuses`
- Plan: `docs/superpowers/plans/2026-09-28-mobile-phase4-community-screens.md` (all of Tasks 0-12 built)
- Spec: `docs/superpowers/specs/2026-09-27-mobile-phase4-community-design.md` (web repo)

## Verified

- `flutter test`: **753 tests, all passing** (full run after the review fixes below; was 726 at the first
  merge, 555 before Phase 4).
- `dart analyze`: no issues, on a cold analyzer cache.
- The Stage B migration is **already applied to production** (`itxubrkbropttfdackmi`), recorded as
  version `20261003133843` / `community_content_reports` (the web repo's file is named
  `20260928120000_...`; the repo already has other migrations whose recorded version differs from the
  filename). Read-only check on 2026-10-03: 10 columns, the pkey plus 3 indexes
  (`..._post_dedupe`, `..._comment_dedupe`, `..._open_idx`), RLS on with the 3 policies from the file
  (`own_insert`, `reporter_or_staff_read`, `staff_update`), 0 rows, and `community_posts` is in the
  `supabase_realtime` publication (`post_comments` already was). **Who applied it is not recorded
  here** — it was not applied from this session.

## What was built (Tasks 7-12 this session; 0-6, 9, 10 in earlier sessions)

- **Feed** (`community_feed_screen.dart`, `post_card.dart`): status tray, weekly-challenges rail,
  Best Play voting, pinned then regular posts with load-more, a discover block (top members, upcoming
  events, gallery, stats), pull-to-refresh, realtime refetch.
- **Post detail** (`post_detail_screen.dart`): comments (flat, capped at the API's 50 with a notice),
  comment compose, delete post/comment with confirm, boost, inline match result, realtime.
- **Report** (`report_sheet.dart`): one sheet, post or comment target. Entry points on post cards,
  post detail and each comment, signed-in players only.
- **Router** (`app_router.dart`, `web_links.dart`): `/community`, `/community/compose`,
  `/community/:id`, `/community/statuses/compose`, `/community/statuses/:playerId`,
  `/community/statuses/:statusId/viewers`; web `/community/<id>` links resolve to the post.

## Rulings made in Tasks 7-12

1. **Realtime providers emit an incrementing tick, not `void`.** A `StreamProvider<void>` notifies
   listeners on the first event only (every `null` equals the last), so the plan's Task 4 design
   would have dropped every realtime refresh after the first. `tickSignal()` in
   `community_realtime.dart` numbers events; `communityFeedRealtimeProvider` and
   `communityPostDetailRealtimeProvider` are now `StreamProvider<int>`. Has its own test.
2. **Screens render the last good value during a refetch** (`.value`, not `.when`), so a realtime or
   pull refresh never swaps the list for a spinner or loses scroll/draft.
3. **Side rails hide when loading, empty or failed** rather than showing per-rail placeholders; one
   rail failing never blanks the feed or another rail. Best Play with a non-null banner but no
   nominations does show `cmtBestPlayEmpty`.
4. **Signed-out challenges rail** shows `cmtChallengesSignedOut` and never calls the API; the
   status tray's "add yours" and the compose FAB call `onLogin` when signed out.
5. **Best Play:** once the player has voted, every vote button is disabled and the chosen one reads
   "Voted". Errors (`voting_closed`, `already_voted`) show inline with their own copy.
6. **Report entry gating:** signed-in only, own content included (the spec has no self-report block).
   The post-card menu therefore appears for any signed-in player; it is absent signed out unless the
   server grants delete/boost.
7. **`PostDetailScreen` is a `ConsumerStatefulWidget`** (plan said `ConsumerWidget`) because it owns the
   comment draft controller. Deleting the viewed post invalidates the feed provider (not
   `removePost`, which needs a live feed state) and then calls `onDeleted`.
8. **Added optional `onEventTap`** to `CommunityFeedScreen` (not in the plan's interface) so an
   upcoming event's CTA does something; the router resolves `ctaHref` through `resolveWebLink` and
   ignores hrefs it can't map.
9. **Cold `/community/statuses/:playerId` with no `extra`** redirects to `/community`: no endpoint
   hydrates a ring by id, so there is nothing to load. A ring tapped in-app always carries `extra`.
10. **Dates** render as a formatted local date-time; there is no relative-time helper in the codebase.
11. **`PostView.imageUrls` may or may not include `imageUrl`**, so the thumbnail strip shows every URL
    that isn't the main image rather than assuming `skip(1)`.

Rulings from Tasks 0-6, 9 and 10 were made in earlier sessions and live in their commits and the plan.

## Known gaps and honest caveats

- **No device or end-to-end pass has been run.** Everything above is verified against fakes. Report
  submission and `community_posts` INSERT realtime are now *unblocked* but not *verified live*.
  **A staging database exists** (`sentinelx-staging`, `ofxmoxpvwbemfouaowoa`, behind the web repo's
  staging preview deployment; see `AGENTS.md`) and is the place for write-path testing. Read-only check
  on 2026-10-03: it already has `community_content_reports`, `community_posts` is in its
  `supabase_realtime` publication, latest migration `20261003133937`, 0 posts, 10 profiles. This note
  originally (wrongly) said no staging database exists, following CLAUDE.md's older wording. The app's
  defaults point at production; running against staging needs `SUPABASE_URL`,
  `SUPABASE_PUBLISHABLE_KEY` and `API_BASE_URL` (the preview deployment) via `--dart-define`; there is
  no committed `config/staging.json`. Never run the write-path pass against production.
- **The plan's fresh-context review pass was not done.** Recommend running it before relying on this.
- `PostCard.compact` (in the plan) was removed as dead code: the gallery renders `GalleryItem` (not
  `PostView`), so it draws plain thumbnails and nothing ever used it.
- Not built, by design (spec): all staff moderation and the report review queue (Phase 8), threaded
  comments (no `parent_comment_id`), a player "submit challenge progress" action (none exists), and
  editing posts/comments (no endpoint).
- Phase 3b's staging device test (from the earlier handoff) is still pending and is independent of this.

## Process notes

- **Encoding hazard on this machine:** Python's default text encoding on Windows is cp1252. Scripted
  edits that add non-ASCII text (em dashes) write invalid UTF-8, which the analyzer reports as
  `uri_does_not_exist` for the file while the test compiler tolerates it. Two files were hit and
  repaired (`post_card.dart`, `app_router.dart`). Use `open(..., encoding='utf-8', newline='')` or the
  editor tools for edits.
- The shared Dart analyzer cache (`%LOCALAPPDATA%\.dartServer\.analysis-driver`) was reset during
  diagnosis and has been rebuilt; this was not the cause.
- No code changed in this handoff commit; docs only.

## Code review (run 2026-10-03 over `f28928a..HEAD`) and what was done

Ten findings; each verified against the code before acting. Nine were real and are fixed (with tests
written first); one was a false positive.

| # | Finding | Outcome |
|---|---|---|
| 1 | Viewer-specific reads (feed, post, comments, statuses, best-play) sent with `publicRequest: true`, which strips the bearer token. The web handlers read `ctx?.userId` (optional auth) for `myReaction`, `canDelete`/`canBoost`, `isSelf`/`hasUnseen`, `myVoteNominationId`. | **Real, most serious.** A signed-in player would never have seen Delete/Boost or their own reaction. Fixed: token now sent on those five; the four caller-independent reads stay anonymous. Both pinned by tests. Untestable against fakes before; first live pass should confirm. |
| 2 | Feed/detail/rings/best-play providers didn't depend on the session, so login/logout left the previous viewer's answer on screen. | **Real.** New `communityViewerIdProvider` (user id, not token) watched by all four; a token refresh for the same user does not refetch. |
| 3 | Every realtime tick invalidated the feed, resetting a scrolled-through list to page one and racing an in-flight load-more. | **Real.** `refreshInPlace()` re-reads the loaded window in chunks of at most 50 (the contract max); refresh and load-more never overlap (a refresh during load-more is queued); load-more dedupes by id. |
| 4 | `context.pop()` after deleting a post fails on a cold deep link. | **False positive.** go_router stacks the parent `/community` page under the nested child route, so the pop lands on the feed. Regression tests added for both entry paths. |
| 5 | A viewed story's ring never refreshed; `deleteStatus` had no UI. | **Real.** Authors can delete their own story from the viewer; view/delete refresh the tray. |
| 6 | Unknown post type / reaction threw and failed the whole feed page. | **Real.** `PostType.unknown`; unrecognised `myReaction` reads as no highlight. |
| 7 | Reaction rollback used a disposed card's `ref` and restored a stale snapshot over fresher counts. | **Real.** Rollback now reverts only the viewer's own slot on the current post; the card resolves the feed notifier at build time; notifier mutators no-op once unmounted. |
| 8 | Count strings had no plural ("1 comments"). | **Real.** ICU plurals in en and fr, generated output committed. |
| 9 | Pull-to-refresh threw on a network error. | **Real.** `refresh()` returns a bool, keeps the list, and the screen says so. |
| 10 | Any `/community/<x>` web link opened the post screen. | **Real.** Only a post UUID does; an external non-post page lands on the tab; in-app paths (compose, statuses) pass through the router redirect untouched. Care needed here: `resolveWebLink` is the router's redirect for every location. |

Residual risk for the first live pass: sending the bearer token to optional-auth reads means an
expired/invalid token could be rejected rather than treated as anonymous. supabase_flutter refreshes
tokens, so this should not arise, but it is the thing to watch.

## Branding (same session)

App name is **SentinelX Esports** (Android label, iOS display/bundle name, app title, Home app bar).
Launcher icons come from the web repo's `public/logo.png` using the web icons' proportions (mark on
`#0B0B0F`; 80% of canvas for the full icon, adaptive foreground matching the web maskable icon).
`logo-icon.png` is deliberately not used (it has "ICON ONLY" baked into its pixels). Regenerate with
`python tool/gen_app_icons.py` then `dart run flutter_launcher_icons`; **revert the
`ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS` change the tool makes to
`ios/Runner.xcodeproj/project.pbxproj`** (it writes an invalid value). The source logo is only
412x384 px, so the 1024px iOS icon is an upscale; a higher-resolution master would be sharper. A debug
APK builds with the new resources; iOS was not built (no macOS here).
