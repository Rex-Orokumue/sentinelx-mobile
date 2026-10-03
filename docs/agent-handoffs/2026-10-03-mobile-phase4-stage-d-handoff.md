# Mobile Phase 4 (Community) — Stage D, Flutter build

- Repo: `sentinelx_mobile`, branch `master` (merged fast-forward from `phase4/screens`, no PR, per standing practice)
- HEAD: `b4e4617` — `feat(community): router wiring — feed, compose, post detail, statuses`
- Plan: `docs/superpowers/plans/2026-09-28-mobile-phase4-community-screens.md` (all of Tasks 0-12 built)
- Spec: `docs/superpowers/specs/2026-09-27-mobile-phase4-community-design.md` (web repo)

## Verified

- `flutter test`: **726 tests, all passing** (last full run, before a comment-only byte repair
  described below; the router, web-link and community suites were re-run after it and passed).
  Baseline before Phase 4 was 555.
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
  submission and `community_posts` INSERT realtime are now *unblocked* (migration applied) but not
  *verified live*. There is no staging database; a live pass writes to production, so use `zzqa_`
  accounts and log them in `TESTING-NOTES.md` per CLAUDE.md, and clean up (`anonymise_account`;
  also delete any `community_content_reports` rows the pass creates).
- **The plan's fresh-context review pass was not done.** Recommend running it before relying on this.
- `PostCard.compact` exists per the plan but nothing uses it: the gallery renders `GalleryItem`
  (not `PostView`), so it draws plain thumbnails. Dead code until a caller needs it.
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
