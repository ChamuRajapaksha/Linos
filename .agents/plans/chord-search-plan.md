# Chord Search — Build Plan (Phase 2)

> Planner file for the builder agent. Update checkboxes as milestones complete. Each task is self-contained: read its Context + Tasks + Done When before starting work.
>
> **Commit granularity note:** Each task lists its own commit message (marked with →) — commit after finishing that task, not at the end of the milestone. This keeps diffs small and gives clean rollback points. The "Wrap-up commit" at the end is a fallback only.

## Status

| # | Milestone | Status | Depends on |
|---|-----------|--------|------------|
| 0 | Chord search feature (Phase 1) | Done | — |
| 1 | Backend proxy (Dart Shelf + SQLite + UG scraper) | Done | — |
| 2 | Flutter real API client (`http` + repos) | Not Started | M1 |
| 3 | List pagination (infinite scroll) | Not Started | M2 |
| 4 | Transposition | Not Started | — |
| 5 | Autoscroll / playback | Not Started | — |
| 6 | Favorites + recent searches | Not Started | — |
| 7 | Final verification | Not Started | M1–M6 |

Status values: `Not Started` / `In Progress` / `Blocked` / `Done`

**~42 commits total. Each task = one commit.**

---

## Context

**Linos** is a Flutter guitar tuner (MVVM + Repository, `get_it` DI, `ChangeNotifier`, walnut/brass Material 3 theme). Phase 1 shipped a second **Chords** tab (bottom `NavigationBar`), a song-search screen (by title **or** artist), a chord-sheet reader (chords above lyrics), and chord diagrams — backed entirely by **mock** repositories and bundled sample data.

Phase 2 moves the app from mock data to a **real API** (with a self-hosted scraping proxy so the mobile client never scrapes), then layers on: **list pagination** (infinite scroll), **transposition**, **autoscroll/playback**, and **favorites + recent searches**.

### Decisions (confirmed with user)

- **Backend:** Dart `shelf` + `shelf_router` server in a new `backend/` directory with its own `pubspec.yaml` — same language as the Flutter app, pure Dart, runs on Windows.
- **Backend storage:** SQLite via the `sqlite3` package. Tables: `songs` (cached search results) and `chord_sheets` (cached parsed sheets as JSON `lines`). Results are cached so repeat requests don't re-scrape.
- **Scraping source:** Ultimate Guitar (per original research). All scraping/HTML parsing happens on the backend only. `UgHttpClient` is an **injectable interface** so tests use fixture HTML and never hit the network.
- **Client HTTP:** `http` package (official Dart, minimal). Base URL via `String.fromEnvironment('LINOS_API_URL', defaultValue: 'http://10.0.2.2:8080')` (Android emulator loopback).
- **Local storage:** `shared_preferences` (already a dependency) for favorites + recent searches.
- **`Song` model unchanged:** its `id` is a `String`, which maps cleanly to UG's numeric IDs.
- **Mocks stay:** `MockSongSearchRepository`, `MockChordSheetRepository` and the bundled sheets remain (tests rely on them). API repos replace the mocks in DI by default. Existing test fakes must be updated for the paginated interface.

### API contract

| Endpoint | Respores |
|----------|----------|
| `GET /health` | `{ "status": "ok" }` |
| `GET /api/search?query=…&page=1&limit=20` | `{ "items": [{"id","title","artist"}], "page": 1, "hasMore": false }` |
| `GET /api/songs/:id` | `{ "title","artist","key","lines":[section|lyric] }` |

Line shape (matches the client's sealed `SheetLine`):
- section → `{ "type": "section", "name": "Intro" }`
- lyric   → `{ "type": "lyric", "words": [{"word": "Today", "chord": "Em7"}] }`

### Architecture (delta)

```
backend/
├── pubspec.yaml                  # shelf, shelf_router, sqlite3, html, test
├── bin/server.dart               # entry, middleware wiring
└── lib/
    ├── api/                      # routes (health, search, chord_sheet)
    ├── data/                     # sqlite schema + song/cache DAOs
    ├── domain/                   # Song/ChordSheet/SearchPage DTOs
    └── scraping/
        ├── ug_http_client.dart   # injectable UG fetcher (rate-limit + UA)
        ├── ug_search_client.dart # UG search JSON API
        └── ug_chord_parser.dart  # UG HTML → ChordSheet (ChordPro parsing)

lib/  (client)
├── data/
│   ├── api/api_config.dart       # baseUrl, timeouts
│   ├── api/api_client.dart       # http wrapper w/ typed errors
│   ├── api/api_models.dart       # JSON → domain parsing
│   └── services/
│       ├── api_song_search_repository.dart
│       ├── api_chord_sheet_repository.dart
│       ├── favorites_repository.dart      # shared_preferences
│       └── recent_searches_repository.dart
├── domain/
│   ├── models/search_results.dart        # {items, page, hasMore}
│   ├── models/favorite_song.dart
│   └── use_cases/chord_transposer.dart
└── ui/features/chords/
    ├── view_models/  # search VM: page state, favorites, recents; sheet VM: transpose + autoscroll
    └── views/        # infinite scroll list, transposition bar, autoscroll panel, recents idle
```

The client's `ChordSheet` domain model is reused verbatim by the backend response via the DTO mapping (backend produces the same line JSON). Existing repository interfaces define the boundary; API repos implement them without touching the view models' contracts beyond the pagination change.

**Verify commands** (run after each commit): root → `flutter analyze` + `flutter test`; backend → `dart analyze` + `dart test` (in `backend/`).

---

## Milestone 1 — Backend proxy (Dart Shelf + SQLite + UG scraper)

**Context:** Standalone Dart package under `backend/`. Own `pubspec.yaml`, `analysis_options.yaml`, `bin/server.dart`. SQLite caches search results and parsed sheets so repeat hits don't re-scrape. UG scraping enclosed behind injectable `UgHttpClient` for fixture-based testing. All handlers wrapped in logging + JSON error middleware + CORS.

**Tasks** *(commit after each one — don't batch)*

- [x] Scaffold `backend/` Dart package: `pubspec.yaml` (shelf, shelf_router, sqlite3, html; test dev-dep), `analysis_options.yaml`, `bin/server.dart` with minimal `shelf` server + `GET /health`; add run note (port 8080)
  → `build(backend): scaffold shelf server with health endpoint` *(split into 5 commits: `8ff3ae2`, `a6fc59e`, `304337e`, `1d6115b`, `1b27c88`)*

- [x] SQLite layer: `backend/lib/data/database.dart` — `openDatabase`, schema DDL for `songs` (id, title, artist) and `chord_sheets` (id, title, artist, key, lines_json, scraped_at), migrate/upsert helpers
  → `feat(backend-db): add sqlite schema and connection helpers`

- [x] Backend domain DTOs in `backend/lib/domain/`: `Song`, sealed `SongLine` with `SectionLine`/`LyricLine(WordChord)`, `ChordSheet`, `SearchPage<T>{items,page,hasMore}`
  → `feat(backend-model): add song, chord sheet and search page DTOs`

- [x] DAOs: `SongCacheDao` + `ChordSheetCacheDao` (insert, get by id, update/upsert, `prepare()` called at boot)
  → `feat(backend-db): add song and chord sheet cache DAOs`

- [x] `ug_http_client.dart`: abstract `UgHttpClient {Future<String> get(String url);}` + `HttpUgHttpClient` (browser User-Agent, 1 req/s rate limit, timeout)
  → `feat(backend-scrape): add injectable ultimate guitar http client`

- [x] `ug_search_client.dart`: hit UG search JSON endpoint, map results to `SearchPage<Song>` (page → UG offset paging, hasMore)
  → `feat(backend-scrape): add song search over ultimate guitar api`

- [x] `ug_chord_parser.dart`: fetch tab page HTML, extract ChordPro body, parse section markers + lyric lines into `ChordSheet` (title/artist/key)
  → `feat(backend-scrape): add ultimate guitar chord sheet parser`

- [x] Route handlers in `backend/lib/api/`: `/api/search` (query → cache → search → page) and `/api/songs/:id` (cache → fetch → parse → cache); wrap with logging + JSON error middleware + CORS
  → `feat(backend-api): add search and chord sheet routes`

- [x] Backend tests: fixture HTML + fake `UgHttpClient` covering search paging, parser mapping, cache hit/miss, 404 on unknown song, health check
  → `test(backend): cover api routes, parser and cache`

**Done when**

- [x] `GET /health` returns ok
- [x] `GET /api/search` returns paginated songs (mock/fixture-backed)
- [x] `GET /api/songs/:id` returns a complete parsed sheet, served from cache on repeat
- [x] `dart analyze` clean and `dart test` passes in `backend/`
- [x] No test in the backend suite hits the real network

---

## Milestone 2 — Flutter real API client

**Context:** Add `http`, build `ApiConfig`/`ApiClient`, JSON parsing, and the two API repositories that implement `SongSearchRepository` and `ChordSheetRepository`. DI switches to API repos (keeping mocks registered for tests). Note: this milestone does **not** change repository signatures yet — pagination is Milestone 3.

**Tasks**

- [ ] Add `http` to `pubspec.yaml` root dependencies
  → `chore(deps): add http package`

- [ ] `lib/data/api/api_config.dart` (`String.fromEnvironment` base URL, request/connect timeouts) + `lib/data/api/api_client.dart` (GET returning decoded JSON, throws typed `ApiException` on non-2xx/network errors, respects timeout)
  → `feat(api): add api config and http client wrapper`

- [ ] `lib/data/api/api_models.dart`: `SearchResponse.fromJson` → `List<Song>`, `ChordSheetDto` → `ChordSheet` (sealed `SheetLine` parsing from `type` discriminator), key/title/artist
  → `feat(api): add json parsing for search and chord sheet responses`

- [ ] `ApiSongSearchRepository implements SongSearchRepository` — calls `/api/search?query=`, maps to songs, propagates `ApiException`
  → `feat(api): add api song search repository`

- [ ] `ApiChordSheetRepository implements ChordSheetRepository` — calls `/api/songs/{id}`, maps DTO → `ChordSheet`
  → `feat(api): add api chord sheet repository`

- [ ] DI (`lib/di/locator.dart`): register `ApiSongSearchRepository`/`ApiChordSheetRepository` against the abstract interfaces (guarded registrations, mocks still available); unit/widget tests unaffected (they inject fakes)
  → `feat(api): register api repositories in locator`

- [ ] Tests: parse DTOs from fixture JSON; repository tests against an in-process `HttpServer` (dart:io) returning canned JSON; error propagation (500, timeout, malformed body)
  → `test(api): cover client repositories and json parsing`

**Done when**

- [ ] Client makes real HTTP calls against the backend contract
- [ ] Typed errors surface cleanly (no raw exceptions in view models beyond `ApiException`)
- [ ] `flutter analyze` clean, `flutter test` passes

---

## Milestone 3 — Search pagination (infinite scroll)

> ⚠ Interface change ripples through existing fakes/tests — handled in task 3 explicitly.

**Context:** Search currently returns a flat `List<Song>`. Introduce `SearchResults{items, page, hasMore}`, a `page` parameter on `SongSearchRepository.search`, mock repo slicing, API repo page support, and infinite-scroll UI that appends results as the user scrolls.

**Tasks**

- [ ] `lib/domain/models/search_results.dart`: `SearchResults{items: List<Song>, page: int, hasMore: bool}` value class
  → `feat(model): add paginated search results model`

- [ ] Change `SongSearchRepository.search(String query, {int page = 1})` → `Future<SearchResults>`; update `MockSongSearchRepository` to slice the catalog by a page size and compute `hasMore`
  → `refactor(repo): paginate song search interface`

- [ ] Update `ApiSongSearchRepository` (passes page, parses `hasMore`) and every test fake (`FakeSongSearchRepository` in `song_search_view_model_test`, `chord_search_view_test`, `app_shell_test`) to the paginated signature
  → `refactor(repo): propagate paginated signature through fakes`

- [ ] `SongSearchViewModel`: hold `page`, `hasMore`, `isLoadingMore`; debounce path resets to page 1; `loadMore()` guards on `hasMore`/`isLoadingMore`, appends results, bumps page; stale-page sequence guard like the existing `_searchSeq`
  → `feat(vm): add infinite scroll state to song search`

- [ ] `ChordSearchView`: `ScrollController` on the results list, `loadMore` when within 80% of bottom, trailing pagination footer loader (small spinner, `Semantics` label); dispose controller
  → `feat(ui): add infinite scroll to search results`

- [ ] Unit tests for `loadMore` append/hasMore/isLoadingMore guards + widget test for footer loader appearing and results appending
  → `test(ui): cover infinite scroll pagination`

- [ ] Run `flutter analyze` + full `flutter test` with the new interface; fix any ripple in chord search/widget tests
  → `chore(chords): verify pagination integration`

**Done when**

- [ ] Search loads page 1, scroll-to-bottom appends page 2+, footer loader shows while fetching
- [ ] `hasMore:false` stops further requests
- [ ] Stale responses from an old query are dropped (same guarantee as before)
- [ ] Mock repo still passes its own tests with slicing; existing tuner suite green

---

## Milestone 4 — Transposition

**Context:** Add `ChordTransposer` (root-note shift with enharmonic handling), expose `transposition` on `ChordSheetViewModel` (−12..+12), and render/read transposed chord names everywhere in the sheet (labels + diagram). UI: `−`/`+` steppers in the sheet AppBar next to the key chip, with offset label and reset.

**Tasks**

- [ ] `lib/domain/use_cases/chord_transposer.dart`: parse root + suffix from a chord name; shift root by semitones with wrap; enharmonic mapping (e.g. C#→Db context-aware or fixed sharp-based); handle `m/maj7/7/sus2/sus4/dim/dim7/aug/6/9/add9/5` and slash bass chords (`G/B`); no-op at 0 and on unparseable input (returns input)
  → `feat(transpose): add chord transposition algorithm`

- [ ] Unit tests: sharp/flat roots, octave wrap (B→C), common suffixes, slash chords, diminished, unknown/uppercase input passthrough
  → `test(transpose): cover chord transposer edge cases`

- [ ] `ChordSheetViewModel`: add `transposition` (int, −12..+12, default 0), `transposeUp()`, `transposeDown()`, `resetTransposition()`, and `transposedChord(String name)` convenience using `ChordTransposer`
  → `feat(transpose): add transposition state to sheet view model`

- [ ] `ChordSheetView` AppBar: transposition stepper — `−`/`+` icon buttons, current offset label (e.g. `+3`), long-press or dedicated reset; haptic on change; stays visible next to the key chip
  → `feat(transpose): add transposition controls to sheet header`

- [ ] `_WordChordColumn` renders `viewModel.transposedChord(chord)`; `showChordDiagram` receives the transposed name (diagram finds the shape by the displayed name); Semantics labels match the visible name
  → `feat(transpose): render transposed chords in sheet and diagrams`

- [ ] VM tests (range clamp, up/down/reset, transposedChord correctness) + widget tests (labels transpose, stepper bounds disable buttons, reset restores original)
  → `test(transpose): cover view model and sheet transposition ui`

**Done when**

- [ ] Tapping `+`/`−` moves every chord in the sheet by the matching semitones and the label reflects it
- [ ] `C` at +1 renders `C#` (or configured enharmonic), `B` at +1 renders `C`
- [ ] Diagram sheet shows the transposed chord name
- [ ] Range clamped to ±12; reset key present

---

## Milestone 5 — Autoscroll / playback

**Context:** Smooth, timer-driven scroll through the sheet at a configurable speed with play/pause + speed controls. Auto-stops at the bottom. Honors reduced motion (instant jump) and exposes Semantics labels.

**Tasks**

- [ ] `ChordSheetViewModel`: add `autoscrollEnabled`/`isAutoscrolling`, `autoscrollSpeedPx` (default ~60 px/s, range 30–150), `startAutoscroll()`, `stopAutoscroll()`, `setAutoscrollSpeed()`, and a `progress` value fed by the view's scroll position (for the control readout)
  → `feat(autoscroll): add autoscroll state to sheet view model`

- [ ] `ChordSheetView`: own `ScrollController`; chrono-driven ticker advances offset while playing; deactivates VM state on `dispose`; **auto-stop** when reaching max scroll extent; if `MediaQuery.disableAnimationsOf` → jump instead of animate
  → `feat(autoscroll): drive smooth autoscroll of sheet body`

- [ ] Autoscroll control panel: floating pill docked above the bottom edge — play/pause toggle (brass icon when active), `−`/`+` speed steppers with readout (px/s), a thin progress bar; haptic on toggle; collapses to just the play/pause when inactive
  → `feat(autoscroll): add playback control panel`

- [ ] Semantics: toggle labeled `Play auto-scroll`/`Pause auto-scroll`, speed buttons labeled with resulting px/s; honor reduced-motion everywhere in the engine
  → `chore(autoscroll): honor reduced motion and semantics`

- [ ] Tests: VM start/stop/speed bounds + widget test that the scroll offset advances over time, stops at bottom, and that controls render in the reduced-motion variant (assessing `disableAnimations` path)
  → `test(autoscroll): cover playback controls and auto scroll`

**Done when**

- [ ] Play begins scrolling; pause freezes; speed adjusts mid-scroll
- [ ] Reaching the sheet bottom auto-pauses
- [ ] Reduced-motion users get an instant jump, no timed animation
- [ ] Existing sheet tests still pass

---

## Milestone 6 — Favorites & recent searches

**Context:** Persist favorites and recent searches with `shared_preferences`. Favorites = serialized `Song` list (JSON). Recents = capped, deduped, most-recent-first query strings. Search view model exposes both; search screen shows a favorite star on each result and a `RECENT` chips section in the idle state.

**Tasks**

- [ ] `lib/data/services/favorites_repository.dart`: `ChangeNotifier`-based store of `List<Song>` (JSON-encoded via `shared_preferences`), `toggle(song)`, `add`, `remove`, `contains`, `favorites` getter, `load()` on init
  → `feat(favorites): add favorites local repository`

- [ ] `lib/data/services/recent_searches_repository.dart`: capped at 10, dedupe (move-to-front), most-recent-first, `add(query)`, `clear()`, `remove(query)`, `recent` getter, `load()` on init
  → `feat(favorites): add recent searches local repository`

- [ ] `SongSearchViewModel`: hold `FavoritesRepository`/`RecentSearchesRepository`; expose `isFavorite(song)`, `toggleFavorite(song)` (haptic callback optional), and `recordSearch(query)` called on debounced submit and chip taps; `clear()` also clears transient state, recents independent
  → `feat(favorites): integrate favorites and recents into search view model`

- [ ] `_SongResultTile`: favorite star icon button in the trailing slot (outline when not fav, brass filled when fav) inside `PressScale`, with `Semantics` label `Add to favorites`/`Remove from favorites`
  → `feat(ui): add favorite toggle to song result tiles`

- [ ] `_IdleView`: add a `RECENT` section above `POPULAR`, chip tap triggers a search, trailing `Clear` button when recents exist; borrow existing chip styling; empty-records case hides the section
  → `feat(ui): show recent searches in idle state`

- [ ] DI: register `FavoritesRepository` + `RecentSearchesRepository` singletons; unit tests for repositories (JSON roundtrip, cap, dedupe, clear/remove) and VM (toggle reflects, recordSearch ordering, recents dedupe)
  → `test(favorites): cover repositories and view model`

- [ ] Widget tests: star toggles and persists across rebuilds; recents chips appear after a search, tap triggers a new search, Clear empties the list
  → `test(ui): cover favorites and recents interactions`

**Done when**

- [ ] Favoriting a song persists across app restarts and shows a brass star
- [ ] Recent searches surface in the idle state, are searchable on tap, and can be cleared
- [ ] Recents stay ≤ 10 with no duplicates

---

## Milestone 7 — Final verification

**Context:** Full stack check before wrap-up.

**Tasks**

- [ ] Run `flutter analyze` + `flutter test` (root) and `dart analyze` + `dart test` (backend); resolve all failures; confirm mock repo tests still validate bundled sheets; confirm the tuner suite stays green
  → `chore(chords): run full analyze and test suite`

**Wrap-up commit (only if tasks above weren't committed individually):** `feat: add real api backends, pagination, transposition, autoscroll and favorites`

**Notes:** The UG parser is fixture-testable but will break if Perfect Guitar changes its markup — the SQLite cache absorbs repeat-hit risk. Favorites/recents live entirely on-device (per-user privacy). The `LINOS_API_URL` dart-define lets a future release point to a deployed proxy without code changes.

---

## Out of scope

- Backend deployment/CI, auth, user accounts, rate-limit management beyond the built-in 1 req/s
- Offline full-sheet caching beyond favorites/recents
- Chord recognition, record tracking, metronome (per the main project plan)