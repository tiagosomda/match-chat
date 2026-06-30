# Bracket Screen

A pan-and-zoom canvas that renders a tournament's knockout bracket: every
knockout match as a node, connected by lines that show who advances to whom.
Scores stay hidden behind the same spoiler-free reveal as the match list; a
small info affordance surfaces time / date / status without cluttering the node;
tapping a node opens the existing match detail screen.

> Status: **implemented**. This document preserves the design rationale and
> records the current topology contract.

---

## TL;DR — how hard is this?

**Medium.** Most of it is reuse, not invention:

- **Pan / pinch-zoom canvas** — Flutter's built-in [`InteractiveViewer`] gives
  two-finger pan, pinch-to-zoom, min/max scale, and boundary handling out of the
  box, and it does **not** swallow taps on its children. ~80% solved for free.
  The real work is web/trackpad polish and a fit-to-screen control.
- **Hidden scores** — reuse the exact reveal mechanism the match list already
  uses (`RevealService` + per-user `UserMatchState`, blur + tap-to-reveal). Zero
  new backend.
- **Status / date / live tint** — already modelled (`MatchModel.displayPhase`,
  `Formatting.kickoff`, the today/tomorrow tint colors). The info bubble just
  re-presents data we already have.
- **Tap → match detail** — one `Navigator.push` to `MatchDetailScreen`, same as
  the match card.

The original blocker was that flat fixture data had no bracket shape. It is now
resolved by explicit `roundIndex` and `bracketSlot` fields. The World Cup 2026
poller assigns those fields from FIFA's published topology; the renderer refuses
to infer edges from kickoff order when they are absent.

T-shirt sizing once the data decision is made: **layout/connector engine = M**,
**canvas + gestures = S–M**, **node + info bubble = S**, **data model + admin =
S–M**. Roughly a few focused days of work.

---

## Goals

1. Visualize the knockout stage as a real bracket the user can explore by
   panning (two-finger drag) and zooming (pinch), with mouse/keyboard fallbacks
   for desktop web.
2. Keep results **spoiler-free** — scores blurred until the viewer reveals them,
   identical to the match list, sharing the same per-user reveal state.
3. Convey each match's **time, date, and status** (upcoming / live / finished)
   without crowding the node — via a tap-to-open info bubble plus a subtle
   status tint/dot.
4. Tap a match node to open the existing **match detail** screen.

## Non-goals (for v1)

- Rendering the **group stage** as tables — the bracket is the knockout stage
  only. (Group standings can link out to the existing list / Ranks.)
- An **admin bracket editor** with drag-to-reseed. v1 authors bracket position
  through simple fields in the existing admin match sheet.
- **Auto-deriving** the bracket purely from chronology (fragile — see below).
- Live "ball travels down the bracket" animations. Tasteful reveal/advance
  motion only.

---

## Where it lives

The bottom nav is already at three tabs (Matches / Buzz / Ranks), two of which
are conditionally hidden ([`home_shell.dart`](../src/app/lib/screens/home_shell.dart)).
Adding a fourth permanent tab crowds it, and a bracket only makes sense once a
tournament has knockout matches.

**Recommendation:** a **segmented "List / Bracket" toggle** on the Matches tab
header, shown only when the active tournament has at least one knockout match.
The bracket renders in the tab body (full width). Rationale:

- Discoverable, contextual (it lives with the matches), and keeps the bottom bar
  at three.
- The canvas gets the full body height; the app header/nav stay put so the user
  never feels lost in an infinite plane.

Alternative considered: a dedicated full-screen route opened from a header icon
(maximizes canvas, but costs a navigation level and re-entry state). Keep this as
a "expand" affordance inside the bracket view if users want chrome-free space.

---

## Data model — the real work

### Current data contract

Matches live at `match-chat/app/tournaments/{tid}/matches/{id}`
([`firestore_refs.dart`](../src/app/lib/services/firestore_refs.dart)) as a flat
collection. The relevant fields ([`match.dart`](../src/app/lib/models/match.dart)):

| field | example | use for bracket |
| --- | --- | --- |
| `teamA` / `teamB` | `"Brazil"` / `"Argentina"` | node labels + flags |
| `description` | `"Round of 16"`, `"Quarter-Final"`, `"Group Stage · Group B"` | display label + fallback stage signal |
| `status`, `scoreA/B`, `scheduledAt`, `venue`, `city`, `goals` | — | node content + info bubble |
| `apiFixtureId` (poller) | `1234567` | source id |
| `matchNumber` | `90` | organizer's stable match number (FIFA M90) |
| `roundIndex` / `bracketSlot` | `2` / `1` | authoritative node position and connector topology |

The poller derives `description` from API-Football's `league.round` string
([`mapping.py:_describe`](../src/backend/poller/mapping.py)). For World Cup 2026,
[`bracket_topology.py`](../src/backend/poller/bracket_topology.py) maps the
provider fixture's stage and host city to FIFA's official match number and
published bracket slot. Unknown fixtures remain unslotted and therefore render
without speculative connector lines.

### Why `description` alone is not enough

From the strings we can sort matches into **columns** (all "Round of 16" in one
column, "Quarter-Final" in the next, …). What we *cannot* get is the **edges** —
which specific R16 matches feed which quarter-final. Pairing them by kickoff time
or array order is wrong as often as it's right (real schedules interleave halves
of the bracket across days). A bracket with wrong lines is worse than no bracket.

Two more gaps:
- **Naming drift** — the seed uses `"Quarter-Final"`, API-Football returns
  `"Quarter-finals"`, and 2026 adds a `"Round of 32"`. We need a normalizer.
- **TBD slots** — before a round is decided, real brackets show
  "Winner Group A" / "W49". Our matches only have concrete team names, so early
  knockout nodes may not exist yet or carry placeholder names.

### Explicit slots: edges become math

Add to the knockout match docs (group matches leave them null → excluded from the
bracket):

```jsonc
{
  "roundIndex": 0,   // 0 = first knockout round, ascending toward the final
  "bracketSlot": 3   // 0-based position within the round, top → bottom
}
```

With these, the bracket is fully determined and the **connectors need no explicit
pointers** — single-elimination guarantees the parent of node `(r, s)` is
`(r + 1, s ~/ 2)`. Layout and lines fall out of pure arithmetic
(see [Layout](#layout-algorithm)). This is the smallest change that makes a
*correct* bracket possible.

Optional niceties (defer unless needed):
- `feedsIntoMatchId` — only if a tournament has a non-standard shape the
  `s ~/ 2` rule can't express (e.g. third-place playoff, which we special-case
  anyway).
- `homePlaceholder` / `awayPlaceholder` — labels like `"Winner R16-1"` for nodes
  whose teams aren't decided.

### Who populates it

The poller owns these fields for `world-cup-2026`. API-Football does not expose
FIFA match numbers, so the tournament-specific resolver identifies each fixture
from its knockout stage and host city (plus date for the two Dallas R32 games),
then applies FIFA's published topology. The source mapping is covered by tests.

The renderer treats slots as mandatory evidence for edges. Kickoff time is only
a display-order fallback: if any real knockout fixture has a missing, duplicate,
or out-of-range slot, nodes remain visible but connectors and winner propagation
are disabled.

### App-side model

- `MatchModel` stores `matchNumber`, `roundIndex`, and `bracketSlot`, parses them
  in `fromDoc`, and writes them in `toMap`.
- `BracketLayout` is a pure, unit-tested value type that takes
  `List<MatchModel>` → ordered rounds, node positions, and connector segments.
  No Firestore, no widgets — just the geometry, so it's trivial to test.

---

## Layout algorithm

Pure function: `List<MatchModel> → positioned nodes + connector lines`.

```
Inputs per node: roundIndex r, bracketSlot s
Constants:       nodeW, nodeH, hGap (between columns), vGap (between round-0 nodes)
lane = nodeH + vGap                       // vertical pitch of the first round

x(r)      = r * (nodeW + hGap)            // column left edge
yCenter(r, s) = (s + 0.5) * lane * 2^r    // each round spans 2^r first-round lanes
y(r, s)   = yCenter(r, s) - nodeH / 2

canvasW = roundsCount * (nodeW + hGap) - hGap
canvasH = firstRoundNodeCount * lane
```

A node at `(r, s)` sits vertically centered between its two children
`(r-1, 2s)` and `(r-1, 2s+1)`, which is exactly what `yCenter` produces — the
classic bracket look where each later round floats between the pair that feeds
it.

**Connectors** (drawn by a `CustomPaint` behind the nodes): for each child
`(r, s)`, draw an orthogonal elbow from its right edge to the left edge of its
parent `(r+1, s ~/ 2)`:

```
right edge of child  →  horizontal to mid-x  →  vertical to parent's y  →  into parent
```

Stroke `c.line` / `c.lineStrong`; brighten the segment when the *advancing* team
is known and that result has been revealed (a faint "path taken" highlight).

**Final + third place:** the final is the single node in the last column.
A third-place match (if present) sits as a detached node below the final with no
connectors, labelled accordingly (this is the one case the `s ~/ 2` rule doesn't
cover — special-case it by `description`).

Render the whole thing as a fixed-size `Stack` (size = `canvasW × canvasH`) with
`Positioned` node cards over the `CustomPaint`, wrapped in the canvas below.

---

## Canvas & gestures

```dart
InteractiveViewer(
  constrained: false,          // let the child be larger than the viewport
  panEnabled: true,
  scaleEnabled: true,
  minScale: 0.4,
  maxScale: 2.5,
  boundaryMargin: const EdgeInsets.all(280), // breathing room around the bracket
  child: SizedBox(width: canvasW, height: canvasH, child: bracketStack),
)
```

- **Two-finger pan / pinch zoom** — native on touch and trackpad. Child
  `GestureDetector`/`InkWell` taps still fire, so tapping a node and tapping its
  info icon both work without extra wiring.
- **Fit-to-screen on open** — compute an initial `TransformationController` matrix
  that scales the full bracket to fit, then center it. Re-fit on a "⊡ Fit"
  button and on tournament change.
- **Desktop / mouse fallbacks (important for Flutter Web):** trackpad pinch maps
  to ctrl+scroll and two-finger drag to pan via pointer-pan-zoom events, but a
  plain mouse has neither. Provide explicit on-canvas controls: **`+` / `−` /
  `⊡ Fit`** buttons (bottom-right), and optionally double-tap-to-zoom-in. This
  also covers accessibility. Treat the gesture path as the delight and the
  buttons as the guarantee.

> **Web gotcha to budget for:** `InteractiveViewer` pan/zoom feel on Flutter Web
> varies by input device and Flutter version (mouse wheel vs. trackpad vs.
> touch). Plan a round of device testing (touch phone, mac trackpad, mouse) —
> this is the most likely source of "it feels off" polish work.

---

## Node anatomy & design

The bracket should read as the same **sports-broadcast** language as the rest of
the app — green-tinted dark surfaces, pink/yellow accents, Space Grotesk +
Space Mono ([`app_colors.dart`](../src/app/lib/theme/app_colors.dart),
[`app_theme.dart`](../src/app/lib/theme/app_theme.dart)). Reuse `SurfaceCard`,
`MonoLabel`, `Avatar`, and the blur/reveal pattern from
[`matches_screen.dart`](../src/app/lib/screens/matches_screen.dart) so a node
feels like a compact match card.

A node is a fixed-size rounded card (`c.surface`, radius 16, `c.line` border):

```
┌──────────────────────────────┐
│ ● LIVE                     ⓘ │   ← status dot+tint (left) · info icon (right)
│ 🇧🇷 Brazil            ▓▓ ┐    │
│ 🇦🇷 Argentina         ▓▓ ┘    │   ← scores blurred until revealed (tap to reveal)
└──────────────────────────────┘
        whole card tap → match detail
```

- **Two team rows** (flag + name, ellipsized), each with its score cell on the
  right. Scores render with `ImageFilter.blur(6,6)` + an eye glyph until the
  viewer reveals them — same `revealed = reveals[m.id]?.scoreRevealed` map and
  the same `reveals.setReveal(...)` toggle as the list. Tapping the score area
  reveals (doesn't navigate); tapping anywhere else on the card navigates.
- **Status tint** — a left accent bar / dot colored by `displayPhase`, reusing
  the list's conventions: live/soon → `accent2` (yellow), finished → `muted`,
  today → orange `0xFFFB923C`, tomorrow → sky `0xFF38BDF8`, else `accent`. This
  is the at-a-glance "live/upcoming/finished" the user asked about, without text.
- **Advanced team emphasis** — once a result is revealed, bold the winner's row
  and dim the loser, and brighten the connector leaving toward the next round
  ("the path taken"). Before reveal, both rows are neutral (no spoiler).
- **TBD slots** — when a team isn't decided, show the placeholder ("Winner
  R16-1" or a muted "—") with a dashed avatar; the node is non-revealable and
  still tappable to the detail screen (which shows the fixture context).

Column headers (`MonoLabel`, e.g. `ROUND OF 16` · `QUARTER-FINALS` · `FINAL`)
pin to the top of each column so they stay legible while panning vertically.

---

## The match info bubble

The user's idea: a small **ⓘ** in the node corner that opens a bubble with the
match's time / date / status. This keeps the node uncluttered while still
exposing the detail.

- **Trigger:** tap the ⓘ icon (top-right of the node). Tapping it opens the
  bubble *without* navigating.
- **Presentation:** an anchored popover via `OverlayEntry` + `LayerLink`
  (`CompositedTransformFollower`) so it floats next to the icon and tracks the
  node as the canvas moves; tap-outside / scroll dismisses it. On narrow screens
  fall back to a bottom sheet.
- **Contents** (all from data we already have — no new reads):
  - Status line — `displayPhase` label with its tint
    (`● LIVE` / `LIVE SOON` / `JUST FINISHED` / `FULL TIME` / `UPCOMING`,
    `TODAY` / `TOMORROW`).
  - Kickoff — `Formatting.kickoff(scheduledAt)` ("Sat, Jun 25 · 2:00 PM") +
    `Formatting.timezoneLabel()`.
  - Countdown for upcoming — `Formatting.untilKickoff(scheduledAt)` ("3h 20m").
  - Venue / city — `match.locationText` when present.
  - A small "Open match →" affordance to the detail screen.
- **No spoilers:** the bubble never shows the score (that stays behind the reveal
  on the node face).

---

## States

| State | Treatment |
| --- | --- |
| **No knockout matches yet** (group stage only, or generic tournament) | Hide the Bracket toggle entirely, or show an empty state: "The bracket appears once the knockout stage is set." |
| **Partial bracket** (later rounds undecided) | Render all known columns; undecided nodes show TBD/placeholder slots and dashed connectors. |
| **Loading** | Reuse the centered `CircularProgressIndicator(color: c.accent)` pattern. |
| **Error** | Mirror the list's `_ErrorState` ("Couldn't load matches"). |
| **Reveal** | Per-user, shared with the list — revealing a score here reveals it there too (same `UserMatchState`). |

---

## Localization

Hand-rolled l10n (en / es / pt-PT / pt-BR), keys added to
`src/app/lib/l10n/`. New strings: the `LIST` / `BRACKET` toggle, column headers
(or derive from existing description strings), the info-bubble labels (reuse the
match-list status keys — `statusLive`, `statusToday`, etc.), the zoom-control
tooltips, TBD/placeholder text, and the empty state. Most status/format strings
already exist and can be reused.

---

## Accessibility & performance

- **Mouse/keyboard users** get the `+ / − / Fit` controls; consider arrow-key
  pan and `+`/`-` zoom when the canvas is focused.
- **Semantics:** each node exposes a semantic label ("Brazil versus Argentina,
  quarter-final, full time — score hidden") so screen readers can traverse the
  bracket even though it's a free-form canvas.
- **Rendering cost:** a knockout bracket is small (a 32-team bracket is 31
  nodes). A `Stack` of `Positioned` cards over one `CustomPaint` is cheap; no
  virtualization needed. Keep the blur layers minimal (one per hidden score) and
  `RepaintBoundary` the connector painter so panning doesn't repaint nodes.

---

## Implementation plan

Suggested order — each phase is independently shippable/reviewable:

1. **Data model (S–M).** Add `roundIndex` + `bracketSlot` to `MatchModel`
   (parse/write), `isKnockout` helper, and round/slot fields to the admin match
   sheet. Add a `roundIndex` normalizer to the poller. Backfill the seed's
   knockout samples.
2. **Layout engine (M).** Pure `BracketLayout` (rounds, node rects, connector
   segments) + unit tests. No UI.
3. **Bracket widgets (S–M).** `BracketNode` card (reusing reveal/blur/status),
   `BracketConnectorPainter` (`CustomPaint`), and the `BracketCanvas`
   (`InteractiveViewer` + fit-to-screen + zoom controls).
4. **Entry point (S).** List/Bracket segmented toggle on the Matches tab, gated
   on `tournament has knockout matches`. Wire node tap → `MatchDetailScreen`.
5. **Info bubble (S–M).** Anchored `OverlayEntry`/`LayerLink` popover (bottom
   sheet on narrow), fed by existing formatting helpers.
6. **States + l10n (S).** TBD slots, empty/loading/error, strings in all four
   locales.
7. **Polish (S–M, time-box it).** Web/trackpad gesture testing across
   touch/trackpad/mouse, reveal & advance motion, semantics.

### Files touched (estimate)

```
src/app/lib/
  models/match.dart                      + roundIndex, bracketSlot, isKnockout
  models/bracket_layout.dart             NEW — pure geometry
  screens/matches_screen.dart            + List/Bracket toggle, gating
  screens/bracket_screen.dart            NEW — canvas + states
  widgets/bracket_node.dart              NEW — node card (reuses reveal/blur)
  widgets/bracket_connectors.dart        NEW — CustomPaint
  widgets/match_info_bubble.dart         NEW — anchored popover
  screens/admin_edit_match_sheet.dart    + round / slot fields
  l10n/*                                 + new strings
  test/bracket_layout_test.dart          NEW — geometry unit tests
src/backend/poller/
  bracket_topology.py                    authoritative tournament mappings
```

---

## Risks & open questions

- **Topology is fail-closed.** Without valid `bracketSlot` values, connectors
  are intentionally omitted. Add an authoritative mapping before enabling a
  new tournament's bracket edges.
- **Web gesture feel** is the top polish risk — budget device testing.
- **TBD nodes:** do undecided knockout matches exist as docs (with placeholder
  team names) before teams qualify, or do they appear only once scheduled? This
  determines whether early rounds render as real nodes or gaps. *(Open — depends
  on how the poller ingests the 2026 schedule.)*
- **Bracket shape generality:** the app is multi-tournament. The `s ~/ 2` rule
  assumes single-elimination with power-of-two rounds (+ optional third place).
  Fine for World Cup; revisit if a non-standard format is ever added.
- **Third-place match** is special-cased (detached node) — confirm that's
  acceptable visually.

[`InteractiveViewer`]: https://api.flutter.dev/flutter/widgets/InteractiveViewer-class.html
