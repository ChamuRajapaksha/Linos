# Chord Search — Build Plan

> Planner file for the builder agent. Update checkboxes as milestones complete. Each task is self-contained: read its Context + Tasks + Done When before starting work.
>
> **Commit granularity note:** Each task lists its own commit message (marked with →) — commit after finishing that task, not at the end of the milestone. This keeps diffs small and gives clean rollback points. The "Wrap-up commit" at the end is a fallback only.

## Status

| # | Milestone | Status | Depends on |
|---|-----------|--------|------------|
| 1 | Chord search feature | Not Started | Tuner M5, M12 |

Status values: `Not Started` / `In Progress` / `Blocked` / `Done`

---

## Context

**Linos** is a Flutter guitar tuner (MVVM + Repository, `get_it` DI, `ChangeNotifier`, walnut/brass Material 3 theme). It is currently a single screen (`TunerView`) with modal bottom sheets and no external APIs.

This plan adds a **chord search feature**: a second tab (Tuner / Chords) via a bottom `NavigationBar`, a song-search screen (by title **or** artist), and a chord-sheet reader rendering **chords above lyrics** in the standard sheet format.

### Decisions

- **Navigation:** Bottom tab bar → **Tuner** and **Chords** tabs. The tab body is **lazy-mounted** (only the active tab is built) so switching to Chords stops the tuner/mic via `TunerView.dispose()` (avoids idle mic processing). Tuner state lives in the singleton VM, so nothing is lost.
- **Results display:** Search results = list of songs (title + artist). Tapping a song opens the chord sheet with chords positioned above the corresponding lyrics.
- **API left alone:** Real chord/lyrics sources (Ultimate Guitar scrapers, LRCLIB, Tablatures) are unofficial and fragile. This plan builds a thin **repository interface + local mock implementation** behind which any real API can drop in later. The UI is fully functional and testable today with bundled sample data.

### API research summary (for a later swap-in — no action in this plan)

There is **no free, official, maintained API that returns both chords AND lyrics**. Ranked options:

| Source | What it gives | Notes |
|--------|---------------|-------|
| `ultimate-guitar-scraper` / `UltimateGuitar-Project` (self-hosted) | Search + chord pages with chords AND lyrics inline, section markers | Best match, but unofficial scrapers subject to markup changes + ToS. Run from a backend, never the mobile client. |
| Tablatures API (self-hosted) | Search + tab downloads, live search of UG/Songsterr | Open-source, MIT-ish; the public URL returns 404 — must self-host. |
| LRCLIB (`lrclib.net`) | free, keyless **lyrics only** | Best lyrics fallback/synced lyrics; no chords. |
| Genius API | search + song metadata | No raw lyrics via API; no chords. |
| `tombatossals/chords-db` | static JSON of ~2,300 chord shapes | Bundle locally for offline chord-diagram rendering. |
| Songsterr public API | — | **Dead** (404 as of 2026); skip. |
| Uberchord / Strumly | chord shapes / AI analysis | Not search-centric; unreliable or paid. Skip. |

**Swap-in strategy:** implement real repositories against the same interfaces (`SongSearchRepository`, `ChordSheetRepository`). Keep per-user caching so a scraped backend isn't hammered.

---

## Architecture (mirrors existing layers)

```
lib/
├── domain/
│   └── models/
│       ├── song.dart            # Song {id, title, artist}
│       └── chord_sheet.dart     # ChordSheet + SongSection + LyricLine + WordChord
├── data/
│   ├── repositories/
│   │   ├── song_search_repository.dart    # abstract: Future<List<Song>> search(query)
│   │   └── chord_sheet_repository.dart    # abstract: Future<ChordSheet> fetch(song)
│   └── services/
│       ├── mock_song_search_repository.dart  # local catalog, title/artist substring filter
│       └── mock_chord_sheet_repository.dart  # bundled sample sheets
├── ui/
│   ├── core/
│   │   ├── navigation/app_shell.dart       # NavigationBar: Tuner / Chords
│   │   └── widgets/                        # extracted from tuner_view
│   │       ├── press_scale.dart            # (was _PressScale)
│   │       └── wordmark.dart               # (was _Wordmark, label-parameterized)
│   └── features/chords/
│       ├── view_models/
│       │   ├── song_search_view_model.dart # debounced search, state enum
│       │   └── chord_sheet_view_model.dart # loads/displays one sheet
│       └── views/
│           ├── chord_search_view.dart      # search bar + states + results list
│           ├── chord_sheet_view.dart       # chords-over-lyrics reader
│           └── chord_diagram_sheet.dart    # mini fretboard on chord tap
```

**Sheet line model:** each lyric line is a list of `WordChord{word, chord?}`. Rendered as a `Wrap` of columns (`chord above word`), giving pixel-perfect chords-over-lyrics alignment regardless of font. Section headers (`[Chorus]`) are separate typed rows styled in brass.

**Verify commands** (run after each commit): `flutter analyze` and `flutter test`.

---

## Milestone 1 — Chord Search & Chord-Sheet Reader

**Context:** Depends on Tuner M5 (UI/theme) and Tuner M12 (shared UI primitives). API is intentionally not integrated — the repository interfaces define the boundary; mock implementations make the UI fully functional.

**Tasks** *(commit after each one — don't batch)*

- [ ] Extract `_PressScale` → `PressScale` and `_Wordmark` → `Wordmark(label: default 'TUNER')` into `lib/ui/core/widgets/`; update `tuner_view.dart` and sheets to import them
  → `refactor(ui): extract shared PressScale and Wordmark widgets to core`

- [ ] Domain models: `Song{id, title, artist}` + `ChordSheet{title, artist, key?, lines}` with line types `SongSection` (`[Chorus]`) and `LyricLine{List<WordChord>}`; add unit tests
  → `feat(chords-model): add Song and ChordSheet domain models`

- [ ] Abstract repository interfaces: `SongSearchRepository` (`Future<List<Song>> search(String query)`) and `ChordSheetRepository` (`Future<ChordSheet> fetch(Song song)`)
  → `feat(chords-data): define song search and chord sheet repository interfaces`

- [ ] Mock implementations + sample catalog: ~15–20 songs filtered case-insensitively by title or artist; bundled sheets with verse/chorus sections covering ~12 chords; unit tests
  → `feat(chords-data): add mock repositories with sample song catalog`

- [ ] `SongSearchViewModel`: mirrors `TunerViewModel` pattern — `ChangeNotifier`, `SongSearchState` enum (`idle/loading/results/empty/error`), 300ms debounced query, `clear()`, `selectSong()`; unit tests with fakes
  → `feat(chords-vm): add debounced song search view model`

- [ ] `ChordSheetViewModel`: holds `ChordSheet?`, loading/error state, `selectChord(name)` for the diagram; unit tests
  → `feat(chords-vm): add chord sheet view model`

- [ ] `AppShell` bottom navigation: Material 3 `NavigationBar` themed from palette (panel bg, brass active indicator, hairline top border, reduced-motion aware); refactor `linos_app.dart` to `home: AppShell`; register repos/services/VMs in `lib/di/locator.dart`; tabs: Tuner (`Icons.tune`) / Chords (`Icons.music_note`); widget test for tab switching
  → `feat(navigation): add Tuner/Chords tab shell`

- [ ] Chord search screen UI: LINOS·CHORDS wordmark header, search `TextField` (12px filled, brass 2px focus, search icon + clear button), `SongResultTile` (title, artist, chevron, `PressScale`, `InkWell` ripple, brass selection accents), results `ListView`; widget tests for idle/results/loading/empty/error states
  → `feat(chords-ui): add chord search screen with results list`

- [ ] Search experience polish: idle state with "Popular searches" chips (reuse chip style), empty state themed icon + message, error state with retry (mirror `_ErrorView` pattern), haptic on result tap via `haptic_feedback.dart` addition
  → `feat(chords-ui): polish search states and interactions`

- [ ] Chord-sheet viewer UI: header panel (song title/artist, key chip), scrollable `LyricLine` rows (`chord above word`, monospace chords in brass, lyric text warm off-white), `SongSection` markers (`labelLarge` brass), back navigation, reduced-motion honored; widget tests
  → `feat(chords-ui): add chord sheet reader with chords over lyrics`

- [ ] Chord diagram on tap: tapping a chord opens a bottom sheet with a custom-painted mini fretboard (dot/barre rendering); bundled `chord_shape.dart` data map (~8–12 common open/barre shapes: A, Am, C, D, Dm, E, Em, G, F) using `panel`/`accent`/`inTune` tokens; widget tests
  → `feat(chords-ui): add chord diagram on chord tap`

- [ ] Final verification: full `flutter analyze` + `flutter test`; resolve any failures or blockers found
  → `chore(chords): run full analyze and test suite`

**Done when**

- [ ] Bottom navigation switches between Tuner and Chords; selecting Chords stops the tuner/mic
- [ ] Searching by song title or artist returns a filtered song list; tap opens a chord sheet
- [ ] Chord sheets render chords above the correct lyric words with brass section markers
- [ ] Tapping a chord shows a mini fretboard diagram
- [ ] All states (idle/loading/results/empty/error) handled with `Semantics` labels and reduced-motion support
- [ ] `flutter analyze` clean and the existing tuner test suite still passes

**Wrap-up commit (only if the tasks above weren't committed individually):** `feat: add chord search and chord sheet reader`

**Notes:** Keep the API out of scope — only the repository interfaces exist for future implementation. The sheet-line `WordChord` model is the crux of the alignment guarantee; test it before building the viewer UI.

---

## Out of scope

- Real API integration, scraping, backend/proxy
- Autoscroll/playback, transposition, favorites/recent searches, list pagination
- Metronome, chord recognition, history/record tracking (per the main project plan)