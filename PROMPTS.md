# AI Prompting Log — cine_match

This document is my AI disclosure for the Platform Commons Flutter assignment, per Page 09 of the spec.

I used **Claude Code** (Anthropic's CLI assistant) as my primary collaborator and **ChatGPT** as a secondary sounding board for early scaffolding. This file captures the decisions made and the *reasoning* behind each — not just the prompts.

---

## How I worked with the AI

I deliberately did **not** copy-paste step-by-step instructions. For each architectural choice (state management, DB, sync strategy, error handling), I asked for trade-offs, picked the option I could defend, and only then asked for code. The structure of this log mirrors that approach: each section is a decision, the alternatives I considered, and the reasoning.

---

## Step 1 — Project scaffolding decisions

**Goal:** Set up a Flutter project foundation that supports offline-first behavior, reactive UI, and clean separation of concerns.

### Folder structure: feature-first Clean Architecture

```
lib/
├── core/         # cross-cutting: theme, network, database, sync, services
├── features/
│   ├── users/        ── data/ domain/ presentation/
│   ├── movies/       ── data/ domain/ presentation/
│   ├── matches/      ── data/ domain/ presentation/
│   └── saved_movies/ ── data/ domain/ presentation/
├── routes/       # go_router config
└── shared/       # widgets/utilities used across features
```

**Why feature-first instead of layer-first:** A layer-first split (`models/`, `screens/`, `services/` at the top) scales poorly — adding a new feature touches every top-level folder. Feature-first keeps related code physically close, so the cost of adding a new page is local.

### State management: Riverpod

**Considered:** Bloc, Provider, Riverpod.
**Picked:** Riverpod.
**Why:**
- Doubles as DI — no need for a separate `get_it` setup.
- Native support for `Stream` providers, which fits the live-updating Matches page (Drift exposes Streams from the DB).
- Compile-safe: if a provider doesn't exist, the build fails — no runtime "provider not found" surprises.
- Less boilerplate than Bloc for an app this size.

### Networking: Dio

**Why Dio over `http`:** The assignment includes a "30% of network calls randomly blocked" test. That requires a retry interceptor with exponential backoff. Dio has first-class interceptor support; `http` does not.

### Local database: Drift

**Why Drift over `sqflite`:** Drift exposes query results as `Stream`s. The Matches page must update live as users save/unsave movies — using a Stream from the DB to a Riverpod `StreamProvider` to the UI gives me real-time updates with zero manual refresh logic.

### Background sync: WorkManager

The assignment explicitly requires WorkManager. **iOS caveat:** Apple restricts background execution heavily — periodic background fetches on iOS are best-effort, not guaranteed. I will document this honestly in the README rather than over-promise.

### Secrets management

- `.env` is gitignored from day one — keys never enter git history.
- `.env.example` is committed as a template so reviewers know which keys to provide.
- TMDB uses the **v4 Bearer token** (header) instead of the v3 `?api_key=` query param shown in the assignment, because keys in URLs leak via logs and screenshots. The endpoints are identical.
- I am aware that any key bundled into the APK is extractable — for a production app I would proxy through a backend. Documented as a known limitation.

### Package versions: pinned with caret ranges

Every dependency is pinned with `^x.y.z` rather than left open. This guarantees a reviewer running `flutter pub get` months from now gets a build-compatible set of versions.

---

---

## Step 2 — Material 3 theme + design tokens

**Goal:** A consistent, premium-feeling dark theme that the rest of the app inherits without per-widget styling.

### Design tokens, not magic numbers

Three small files in `lib/core/theme/`:

- `app_colors.dart` — seed color, accent, custom dark surfaces
- `app_dimensions.dart` — spacing scale (4/8/12/16/24/32/48), radius scale, animation durations
- `app_theme.dart` — assembled `ThemeData`

**Why split this way:** Tokens (color, spacing, radius) are referenced from widgets directly when needed. The `ThemeData` then composes them into M3 component themes. This keeps "what value to use" separate from "where it's applied" — easy to refactor either side independently.

### Color choices

- **Seed:** warm crimson `#B91C1C`. Cinematic without being a Netflix knock-off. `ColorScheme.fromSeed` generates a full M3 tonal palette from this single color, so the rest of the UI (buttons, FABs, focus rings) stays harmonized automatically.
- **Accent (amber `#FFB020`):** kept *outside* the M3 scheme on purpose. Used only for save-count badges and "match" highlights, where we want it to clearly stand apart from primary surfaces.
- **Surface override:** scaffold background set to a deep `#0E0E10` rather than the M3-default surface tone. Reads as "dark theatre" and gives posters more visual weight.

### Typography: Google Fonts Inter

- `GoogleFonts.interTextTheme(...)` applied over the M3 base text theme — keeps M3's type scale (display/headline/title/body/label) intact, just swaps the font family.
- **Trade-off:** `google_fonts` fetches the font file at runtime on first launch and caches it. This means a brand-new install needs internet *once* before fonts work. The assignment's offline tests start *after* first launch, so this is acceptable. For a production app I would bundle the .ttf files in `assets/fonts/` and remove the runtime dependency entirely. Documented as a known trade-off.

### Component themes set explicitly

Setting these once in `ThemeData` means I never restyle them per widget:

- `AppBarTheme` — flat, left-aligned title, no scroll-under elevation (modern look)
- `CardThemeData` — surface-container fill, large radius (16), zero elevation (we use color tone for depth instead of shadows in dark mode)
- `FilledButtonThemeData` — consistent padding and text weight on every button
- `InputDecorationTheme` — filled inputs with a focus ring in primary color (used in the Add User form)
- `SnackBarThemeData` — floating, rounded — matches the spec's "small snackbar at the bottom, no blocking dialogs"
- `splashFactory: InkSparkle` — the M3 sparkle ripple, gives every tap clear feedback (spec calls this out under UI checks)

### What this buys us downstream

When I build the 6 pages, none of them set colors, padding, or radius inline. Every Card, Button, Input, and SnackBar already looks right because the theme handles it. Refactoring the brand color later = change one constant.

---

---

## Step 3 — Routing with `go_router` + page skeletons

**Goal:** Define every route the app needs *before* writing feature logic, so navigation works end-to-end and each page lives at a stable URL from day one.

### Route table

```
GET /                                 → UsersPage (initial)
GET /users/add                        → AddUserPage
GET /users/:userId/movies             → MoviesPage
GET /users/:userId/saved              → SavedMoviesPage
GET /movies/:movieId?userId=:active   → MovieDetailPage
GET /matches                          → MatchesPage
```

### Why this URL shape

- **Active user is in the path, not a global state**, for the routes where it's required (`/users/:userId/movies`, `/users/:userId/saved`). The URL is then self-describing — you can deep-link, share a link, or restart the app on a route and the page knows exactly who it's for.
- **Movie detail uses a query param** (`?userId=...`) for the active user instead of nesting under `/users/:userId/movies/:movieId`. Reason: movie detail is reachable from *Matches* too, where there is no active user. Optional query param handles both cases without two route definitions.
- **Named routes** (`AppRoute.users`, `AppRoute.movies`, ...) instead of hardcoded paths at call sites. If I rename a path later, the call sites don't change.

### Why `go_router` instead of plain `Navigator`

- Declarative — the whole route tree is in one file, easy to reason about
- Built-in deep linking (URL bar in web, App Links / Universal Links on mobile) — comes free
- Type-safe parameters via `state.pathParameters` and `state.uri.queryParameters`
- Plays nicely with Riverpod (no `BuildContext` gymnastics for `Navigator.of(context)`)

### Page skeletons

Each page is a minimal `StatelessWidget` with the right `AppBar`, `Scaffold`, and navigation buttons wired up. The bodies are placeholder text. This is deliberate:

- **Verifies routing end-to-end** before any feature code lands
- **Shows the navigation graph as a working app** — I can tap through every screen during development without auth or DB scaffolding
- **The Matches button appears in every relevant `AppBar`** (Users, Movies, Saved) — matches the spec's "always visible" requirement without needing a `ShellRoute` with persistent chrome

### `pushNamed` vs `goNamed`

I use `pushNamed` for forward navigation everywhere. `goNamed` would *replace* the current location, breaking the back button. Push keeps a proper navigation stack so the system back button always works as expected.

### Updating the smoke test

The test now verifies the initial route renders the Users page (looking for the "Cine Match" AppBar title, the Add User FAB tooltip, and the Matches button tooltip). This is a real end-to-end smoke test: app boot → router config → initial route → page renders.

---

---

## Step 4 — Drift database schema, DAOs, and tests

**Goal:** Design a schema that satisfies *every* offline/sync requirement at the database layer, so the app code above it can be naive.

### Three tables, three load-bearing decisions

**1. `Users.id` is a stable autoIncrement local PK; `serverId` is a nullable column that is filled later.**

This is the single most important schema decision in the project. The naive design — using the Reqres-assigned ID as the primary key — falls apart for offline-created users: when sync completes and the server hands back a real ID, every saved-movie reference would need to migrate. With a stable local PK, sync just sets one column on the users row. Saved movies stay correctly linked, automatically.

`serverId` carries a `UNIQUE` constraint so re-running a failed sync can't insert a duplicate user. SQLite's UNIQUE allows multiple `NULL`s, so unsynced users coexist freely.

**2. `SavedMovies` uses a composite primary key `(userId, movieId)`.**

The spec says "no duplicate saves." Most candidates enforce this in app code with a check-then-insert dance — that's race-prone and wrong. With the composite PK, duplicates are *physically impossible*. `INSERT OR IGNORE` (used in `SavedMoviesDao.save`) turns repeat saves into silent no-ops, so the UI never has to think about it.

Foreign keys with `ON DELETE CASCADE` mean deleting a user automatically removes their saved-movie rows — no orphan data possible.

**3. `Movies` table caches every movie fetched from TMDB.**

The spec requires the Saved Movies page to work offline, even for movies the user hasn't opened in detail. Solution: every API response goes through `MoviesDao.upsertMovie` before any `save()` call. Saved Movies then INNER JOINs against the cached movies table — guaranteed to render whatever the user has saved, even with airplane mode on.

### `PRAGMA foreign_keys = ON` in `beforeOpen`

SQLite ignores foreign-key constraints by default. Without this PRAGMA, the cascade delete and FK enforcement are silently disabled — a classic bug. The `MigrationStrategy.beforeOpen` hook turns them on for every connection.

### DAO design

Three DAOs split by *aggregate*, not by table:

- **`UsersDao`** owns user CRUD plus `watchAllWithSavedCount` — a JOIN that powers the Users page (each row carries the user + their live save count, all in one Stream).
- **`MoviesDao`** owns the movie cache — `upsertMovie`, `upsertMany` (batch), `watchById`.
- **`SavedMoviesDao`** owns the relationship table plus the four reactive queries that drive the live UI:
  - `watchSaveCount(movieId)` → live count badge on Movies cards
  - `watchSavedFor(userId)` → Saved Movies list
  - `watchIsSaved({userId, movieId})` → Save button toggle state
  - `watchMatches()` → Matches page

### Why `watchMatches()` is a `customSelect`

The Matches query needs `GROUP BY` + `HAVING COUNT >= 2` + `GROUP_CONCAT` of user IDs. Drift's typed query builder doesn't compose this elegantly, so it's a `customSelect` with raw SQL — *but* with `readsFrom: {savedMovies, movies}` set. That tells Drift's stream layer "re-emit this query whenever either of these tables changes." A single `save()` call now propagates automatically to the count badge AND the Saved list AND the Matches page. Zero manual refresh logic anywhere.

### `@DataClassName('Movie')` annotation

Drift's auto-singularization heuristic turned `Movies` into `Movy` (it stripped "ies" + appended "y"). Caught on first compile. Fixed by explicitly naming the row class `Movie` and `SavedMovie` via `@DataClassName`. Worth knowing — Drift's heuristic isn't always right and an explicit override is the safe move.

### Riverpod providers for DI

`appDatabaseProvider` owns the database lifecycle. `usersDaoProvider`, `moviesDaoProvider`, `savedMoviesDaoProvider` expose the DAOs. Repositories will `ref.watch()` these. The DB connection is opened lazily on first read — widget tests that don't touch the DB pay zero cost.

### Tests for the load-bearing invariants

`test/core/database/app_database_test.dart` covers the four behaviors that absolutely must work for the assignment:

1. **Composite PK** — repeat saves of `(user, movie)` collapse to one row
2. **Sync invariant** — `markSynced` updates `serverId` and `pendingSync` without affecting `saved_movies` rows
3. **Pending-sync filter** — `getPendingSync()` returns only users that still need to be POSTed (drives WorkManager)
4. **Matches query** — only movies with 2+ saves appear, sorted by count desc; users with single saves don't pollute the list
5. **Cascade delete** — deleting a user removes their saved_movies (proves `PRAGMA foreign_keys = ON` works)

Tests use `NativeDatabase.memory()` via the `AppDatabase.forTesting` constructor — fast, isolated, no file I/O.

---

---

## Step 5 — Network layer (Dio + retry interceptor)

**Goal:** Survive the assignment's "30% of network calls randomly blocked" test invisibly. The user should barely notice anything went wrong.

### Three Dio clients, one builder

`reqresClientProvider`, `tmdbClientProvider`, `omdbClientProvider`. Each has its own base URL and auth headers, but the rest of the configuration (timeouts, retry, logging) is shared via a `_buildClient` helper. Three providers instead of one because:

- Different base URLs (different APIs)
- Different auth schemes — Reqres uses `x-api-key` header, TMDB uses `Authorization: Bearer ...` (v4), OMDB uses `?apikey=...` query param
- Mixing them in one client would mean conditional headers per request — error-prone

### Auth choice for TMDB

The assignment shows `?api_key=...` in URLs (TMDB v3 style). I'm using **TMDB v4 Bearer token** in the `Authorization` header instead. Both authenticate the same endpoints. The Bearer token approach keeps the key out of URLs, which means it doesn't leak into:
- Server access logs
- Browser/devtools history
- Screenshots
- Crash reports

This is the kind of "going beyond" the assignment encourages — same functionality, better security posture. Documented in this file so the reviewer sees the deliberate choice.

### Retry interceptor — exponential backoff

`RetryInterceptor` (in `core/network/retry_interceptor.dart`) does the work for the 10%-of-grade bad-connection test.

Algorithm:
1. Failure arrives → check `extra[_retry_attempt]` from request (defaults to 0)
2. If retryable AND attempt < maxRetries → wait `initialDelay << attempt` (400ms → 800ms → 1.6s) → call `dio.fetch(next)` with attempt+1
3. The retried request goes through the same interceptor, so the chain unwinds naturally
4. Worst case: 1 initial + 3 retries = 4 attempts, ~2.8s total extra latency before giving up

**Retryable**:
- `connectionError` / `connectionTimeout` / `receiveTimeout` / `sendTimeout` — network problems
- `badResponse` with status 5xx — server problems

**Not retryable**:
- 4xx — auth failure, validation error, not found. Retrying just hammers a permanent error.
- `cancel` — user canceled, leave it alone.
- `badCertificate` — would never resolve.

### "Reconnecting…" banner

The spec requires a subtle UI signal when retrying. The interceptor exposes two callbacks: `onRetryStart(int attempt)` and `onRetryEnd()`. The Dio provider wires these to a `NetworkStatusNotifier` (Riverpod `StateNotifier`). When the UI is built, a banner widget can listen via `ref.watch(networkStatusProvider)` and show "Reconnecting (attempt N)…" while `isReconnecting` is true. No coupling between the retry logic and Flutter widgets — the interceptor stays UI-agnostic.

### Interceptor order: log first, retry second

`LogInterceptor` runs *before* `RetryInterceptor`. Reasoning: in Dio, the response/error path goes bottom-to-top through interceptors. If RetryInterceptor were first, the logger would only see the final outcome of a series of retries. With LogInterceptor first, every individual attempt is logged — which is exactly what I want during the bad-connection test, so I can see "attempt 1 failed, attempt 2 failed, attempt 3 succeeded".

### Tests for the retry algorithm

`test/core/network/retry_interceptor_test.dart` — 4 tests covering the contract:

1. **Connection error → retries until success** (3 calls, 2 retries fired)
2. **5xx response → retries** (5xx is server-side, transient)
3. **4xx response → does NOT retry** (permanent error)
4. **Persistent failure → gives up after `maxRetries` and fires `onRetryEnd`** (so the banner clears)

The tests use a custom `_ScriptedAdapter` (an `HttpClientAdapter` that returns predetermined responses or throws connection errors). One subtle gotcha caught while writing the tests: the adapter must construct the `DioException` with the *current* `RequestOptions` at fetch time, not a stale snapshot. If the adapter throws a pre-built exception, the retry interceptor reads the wrong `extra[_retry_attempt]` value (always 0) and effectively retries forever. The fix was a sentinel `_fail` value that the adapter expands using the live options. Worth knowing — a non-obvious pitfall when mocking Dio.

---

---

## Step 6 — Sync layer (offline-first user creation)

**Goal:** Pass the assignment's headline test — add user offline → save movies offline → reconnect → no data lost, no duplicates, server IDs assigned, saved movies still linked.

### Architecture: three layers, one rule

The "rule" is **local-first, sync-best-effort**: every write goes to the local DB synchronously. The network attempt is fire-and-forget. The user never waits.

1. **`UsersRepository`** — public API for the UI. `createUser` always inserts locally with `pendingSync = true`, then either fires an immediate POST (if online) or schedules a WorkManager job (if offline). `watchAll` is purely local — the UI never blocks on the network.

2. **`SyncService`** — pickup-and-push logic. `syncPendingUsers()` queries `usersDao.getPendingSync()`, POSTs each user to Reqres, calls `markSynced` with the server-assigned ID. Per-user errors are isolated: one failure doesn't stop the rest. Returns a `SyncResult { synced, failed }`.

3. **`SyncScheduler`** — listens to `connectivity_plus` and triggers `syncService.syncPendingUsers()` on offline → online transitions. Lives as long as the `ProviderScope`. Guarded against re-entry (`_syncInFlight`).

### Why three pieces instead of one

If `UsersRepository` did the connectivity listening itself, it would be doing too many jobs. Splitting them means:

- I can call `SyncService.syncPendingUsers()` from anywhere (foreground, WorkManager, manual "sync now" button later) without coupling to connectivity logic.
- `SyncScheduler` is purely glue — easy to replace with a different trigger (timer, push notification, manual button) without touching the sync logic.
- Tests for `SyncService` don't need to mock connectivity.

### WorkManager: belt-and-braces

`SyncScheduler` covers the case where the app is *running* when connectivity returns. WorkManager covers the case where the app was killed by the OS, or the user closed it before reconnecting.

`workmanager_callback.dart` defines a top-level `callbackDispatcher` (required by WorkManager — it must be a top-level function, not a method). It runs in a **separate isolate**, so it cannot reuse the main isolate's `ProviderContainer`, DB connection, or Dio instance. It builds its own from scratch. This isolation is correct and intentional — backgrounded code must be fully self-contained.

`UsersRepository.createUser` calls `scheduleSyncOnConnectivity()` when offline, which registers a one-off task with `NetworkType.connected` constraint. The OS fires it once connectivity is detected, even if the app isn't running.

### iOS reality check (documented honestly)

WorkManager works reliably on Android. iOS is **best-effort** — Apple restricts background execution heavily. Periodic background fetches on iOS are not guaranteed to run on schedule. The `SyncScheduler` (which runs while the app is in the foreground) covers most real-world iOS sync needs. Documented in the README so the reviewer sees this isn't a bug — it's a platform constraint.

### How duplicates are prevented

Three layers of defense:

1. **DB schema** — `users.serverId` has a `UNIQUE` constraint. Even if WorkManager and the foreground scheduler both fired at the same moment, the second `markSynced` would conflict with the first.
2. **DAO method** — `getPendingSync()` only returns rows with `pendingSync = true`. After `markSynced`, the row is no longer pending and won't be picked up again.
3. **Scheduler re-entry guard** — `_syncInFlight` boolean prevents `SyncScheduler` from running two passes simultaneously.

### Tests

`test/core/sync/sync_service_test.dart` — 5 tests covering the contract:

1. **All pending users sync** — server IDs assigned, `pendingSync = false`, fields mapped correctly (firstName + lastName → `name`; `movieTaste` → `job`)
2. **Partial failure** — one user fails, others still sync; failed user stays pending
3. **Idempotency** — re-running `syncPendingUsers()` only POSTs the still-pending users, doesn't re-POST already-synced ones
4. **Saved movies remain linked after sync** — the headline assignment requirement, verified directly: create offline user → save movie → sync → confirm `watchSavedFor` still returns the saved movie
5. **Empty queue is a no-op** — no remote calls when nothing is pending

The test uses an in-memory Drift database (real DB, fast) and a hand-rolled `_FakeRemote` (no mocktail dependency for one test).

### `main.dart` changes

`main.dart` now:
1. Initializes WorkManager (wrapped in try/catch so iOS / test environments don't crash)
2. Builds a `ProviderContainer` manually so it can eagerly read `syncSchedulerProvider` *before* the first frame paints — the scheduler starts listening to connectivity immediately
3. Hands the container to `UncontrolledProviderScope` for the widget tree

Widget tests still use `ProviderScope(child: CineMatchApp())` directly, so they never construct the scheduler and don't depend on a real connectivity plugin.

---

---

## Step 7 — Users page (live DB stream + Reqres pagination)

**Goal:** Page 01 of the assignment — scrollable user list with profile photo, name, save count, infinite scroll, shimmer skeleton, FAB → Add User, AppBar → Matches.

### The hybrid approach: DB stream is source of truth, API populates the cache

Most pagination tutorials hand the controller the API itself. That doesn't work cleanly here because:

- The list must include locally-created users (offline) that don't exist on the API.
- The save count badge needs live updates from a different table (`saved_movies`).
- Saved Movies / Movie Detail later need users available offline.

So the architecture is:

1. **`UsersPage` reads `usersStreamProvider`** — a `StreamProvider` over `UsersDao.watchAllWithSavedCount()`. Every user in the DB is rendered, with their live save count.
2. **`UsersPaginationNotifier` tracks API pagination separately** — `currentPage`, `totalPages`, `isLoading`, `errorMessage`. It does NOT hold the list itself.
3. **`UsersRepository.fetchPage(N)` upserts API rows into the DB** — the Stream automatically emits new data. The page never sets state from API responses directly.

Trade-off: two state sources to coordinate (the Stream and the pagination state). But the payoff is that locally-created users appear instantly and the save count badge updates in real time without any extra plumbing.

### `UsersDao.upsertFromApi` via `getByServerId` + `updateProfile`

A `DataClassName('Movie')`-style upsert isn't quite right for users because we need to preserve the local PK. Instead, the repository:

1. Looks up the existing user by `serverId` (UNIQUE column).
2. If found, calls `updateProfile` (writes only the API-mutable fields — name, email, avatar — leaves sync flags alone).
3. If not found, inserts a new row with `pendingSync = false`.

This way, an offline-created user that gets a `serverId` later doesn't get duplicated when the next API page comes in.

### Scroll-to-load: 200px threshold

Plain `ScrollController.addListener`. When `position.pixels >= maxScrollExtent - 200`, call `loadNextPage()`. The notifier guards against re-entry (`if (state.isLoading) return`) and against running past the last page (`!state.hasMore`). The 200px lookahead means new content arrives just as the user reaches it — no jarring stop-and-load.

### Shimmer skeleton for initial load

`UsersListSkeleton` renders 6 `UserListItemSkeleton` placeholders via the `shimmer` package. Each skeleton has the same height/layout as a real list item so the transition doesn't shift content. The shimmer base/highlight colors are derived from `AppColors.surfaceContainer` to match the dark theme.

### Staggered fade-in via `flutter_animate`

Each list item: `.animate(delay: (index * 60).ms).fadeIn(duration: 250.ms).slideY(begin: 0.08)`. Items appear top-to-bottom with a 60ms cascade — matches the spec's "list items should fade in one by one when a page first loads — not all appear at once."

### Avatar = `CachedNetworkImage` with placeholder

Reqres avatars are real URLs. `CachedNetworkImage` handles caching (so subsequent loads are instant), shows a colored placeholder during fetch (no spinner), and fades the image in over `AppDuration.normal`. Falls back to a Material person icon on load failure.

### `RefreshIndicator` for pull-to-refresh

Free win — wraps the body. The `refresh()` method on the notifier resets pagination and re-fetches page 1.

### Empty / error states

`UsersEmptyState` widget renders one of two flavors:
- **No users + no error**: "No users yet. Tap the + button to add the first one."
- **Error**: "Cannot reach the server" + retry button

The "pending sync" cloud-off icon on individual list items signals which users are still local-only — useful debugging information, also a nice touch for the reviewer demoing the offline test.

### The widget test gotcha (worth noting)

After wiring up the page, the widget test was failing with **"A Timer is still pending after the widget tree was disposed"**. The leaking timer turned out to be **Drift's `StreamQueryStore.markAsClosed`**, which schedules a zero-duration `Timer.run(...)` during stream cleanup. The test's `pumpAndSettle` finished before that cleanup happened (because cleanup runs during widget disposal, *after* the test body), so the test framework's invariant check saw a pending timer and failed.

Fix: explicitly unmount the widget tree at the end of the test (`pumpWidget(SizedBox.shrink())` + `pumpAndSettle()`) so the cleanup timer fires inside the test body, not in the framework's verification phase.

The fix is a one-liner but the diagnosis took some real digging — flagged here for future-me when this pattern comes up on the next page.

---

---

## Step 8 — Add User form

**Goal:** Page 02. Form with two fields, validation, calls repository, snackbar confirmation, pops back. Must work online and offline (the local-first repository handles both transparently).

### Form structure

`Form` + `GlobalKey<FormState>` + two `TextFormField`s. Validation runs synchronously on submit:

- **Name** — required, min 2 chars after trim. Single-word names ("Cher") land in `firstName`, `lastName` is empty string. Multi-word names split on whitespace, first word → `firstName`, rest → `lastName`.
- **Movie taste** — optional, max 80 chars. Mapped to Reqres's `job` field by the repository.

Both fields disabled while submitting. Submit button shows a small `CircularProgressIndicator` instead of its label during the network call.

### Why the page is naive about online/offline

`UsersRepository.createUser` already handles the local-first flow internally — write to DB → immediate POST if online → schedule WorkManager if offline. The page just calls `createUser(...)` and trusts. This was the whole reason for splitting the repository from the sync layer: the UI doesn't need to know which path it's on.

### Snackbar persists across navigation

Calling `ScaffoldMessenger.of(context).showSnackBar(...)` resolves to the app-level `ScaffoldMessenger` (the one inside `MaterialApp`), not a per-page one. So the snackbar is owned at the app level — when we pop back to Users, it stays visible. That matches the spec: "show a small snackbar at the bottom. No blocking dialogs."

### `Navigator.canPop(context)` guard

Production: AddUser is always pushed onto Users, so `canPop` is true and the page pops cleanly back. Tests: the page is pumped as `home`, so `canPop` is false. Guarding with `if (canPop)` means the same code works in both contexts without special-casing.

### `try/catch/finally` for the submit button

Initial draft set `_isSubmitting = false` only in the `catch` block — assuming the success path would unmount the page via `pop()`. In tests where pop doesn't happen (no parent route), the indeterminate `CircularProgressIndicator` kept animating forever, hanging `pumpAndSettle`. Fix: a `finally` block that resets `_isSubmitting` if the widget is still mounted. After a real pop the widget is unmounted and the `finally` is a no-op, so production behavior is unchanged.

This is the kind of defensive code that pays for itself the first time the test infrastructure tries to verify the form. Worth knowing as a pattern: indeterminate progress indicators + pumpAndSettle don't mix unless you're sure the widget will unmount.

### Tests

`test/features/users/add_user_page_test.dart` — 4 tests covering the form contract:

1. **Two-word name + taste** — verifies the name split and the taste field round-trip into the repository call
2. **Single-word name** — `firstName` set, `lastName` is empty string, `movieTaste` is null when blank
3. **Empty name** — validation error shown, repository never called
4. **Repository failure** — snackbar with the error appears, button re-enables (regression test for the indeterminate-progress hang)

The fake repository (`_FakeUsersRepository`) records the last call's arguments. Hand-rolled, no mocktail dependency. The page is pumped inside a plain `MaterialApp` (no go_router) — possible because the page uses `Navigator.canPop` instead of `context.pop`.

---

---

## Step 9 — Movies page (TMDB trending + live save state)

**Goal:** Page 03. Trending movies from TMDB with infinite scroll. Each card shows poster + title + year, a **live** save count badge, and a save toggle for the active user. Tapping a card opens the Movie Detail page with a Hero animation on the poster.

### List source: pagination state, not DB

Unlike the Users page (where the DB Stream drives the list), the Movies list is held **in-memory in pagination state**. Reasoning:

- "Trending today" is an order TMDB owns. If I drove the list from the DB sorted by `cachedAt`, yesterday's trending movies would mix with today's.
- The DB cache exists for a different purpose: making Saved Movies and Movie Detail work offline. Cards on Movies page are always rendered from the latest API response.

So the architecture is:
- `MoviesPaginationNotifier.loadNextPage()` calls `fetchTrendingPage(N)` on the repository
- Repository upserts every movie into the DB (`movies` table) — populates the cache for downstream features
- Notifier appends the API response to its in-memory list
- Card widgets render from the in-memory `TmdbMovie` DTOs

The DB cache is a side-effect of fetching, not the source of truth for this page.

### Reactive save state on every card

Each `MovieCard` is "self-aware" — it watches two `family` providers parameterized by movie id:

- `isSavedProvider((userId, movieId))` → `Stream<bool>` → drives the bookmark icon
- `saveCountProvider(movieId)` → `Stream<int>` → drives the count badge text

Both come from Drift Streams. When user A taps Save on movie 550, it writes one row. The Streams for movie 550 emit new values. Both A's bookmark icon (via `isSaved`) and *every other user's count badge* (via `saveCount`) update without any imperative refresh logic. This is exactly the case the spec calls out:

> Each card shows a count badge — how many users have saved this movie. **This number updates in real time as users save or unsave movies.**

### `SavedMoviesRepository.save` is FK-safe

The `saved_movies` table has FKs to both `users` and `movies`. So `save` must run upsert-then-link in order:

```dart
await moviesDao.upsertMovie(...);  // ensures FK target exists
await savedMoviesDao.save(userId, movieId);  // safe to insert
```

The Movies page already upserts on fetch, so by the time the save button is tappable, the movie is in the DB. **But** the Movie Detail page (next step) lets users save a movie fetched from `/movie/{id}` directly, which may not be in any trending list. Centralizing the upsert-then-link sequence in `SavedMoviesRepository.save` means callers don't have to remember the rule. Tests verify this.

### Animated save count badge

`AnimatedSwitcher` keyed on the count value. When count goes 0 → 1 → 2, the badge swaps with a scale + fade transition. Spec: "The save count badge should animate when its number changes." One-line implementation thanks to `AnimatedSwitcher` + a stable `ValueKey(count)`.

The badge text is also adaptive: "No saves yet" → "1 user saved" → "2 users saved" — small grammar polish that costs nothing.

### Animated save button

Same `AnimatedSwitcher` pattern. Two icon variants: `bookmark_outline` (unsaved) and `bookmark` (saved, in `accentAmber`). Tap toggles state by calling `repo.save(...)` or `repo.unsave(...)`. The Stream-driven UI updates the icon naturally — no manual `setState`.

### Hero animation on poster

`Hero(tag: 'movie-poster-$movieId', child: ...)` on the card poster. The Movie Detail page (next step) wraps its large poster in the same `Hero` tag — Flutter morphs the image between pages with a free animation. Spec: "the movie poster should animate from the list card into the detail page (hero animation)." Setup is one widget on each side.

### Pagination provider is global, not parameterized by `userId`

A small but important design call. The `moviesPaginationProvider` is a single-instance `StateNotifierProvider` — not a `family`. Reasoning:

- Trending movies are global to TMDB, not per-user.
- If User A scrolls to page 5 and navigates to a different user's Movies page, the same trending list should appear (no need to refetch from page 1).
- Making it a `family(userId)` would create a new pagination state per user with no upside.

The save state is per-user (correctly a `family`); the trending list is shared.

### Tests

`test/features/saved_movies/saved_movies_repository_test.dart` — 4 tests for the FK-safe save flow:

1. **`save()` upserts movie before linking** — the headline FK guarantee
2. **`save()` is idempotent** — composite PK + INSERT OR IGNORE means repeat saves are safe
3. **`unsave()` removes the link but preserves the cached movie** — the movie row stays so other users can still save it
4. **`save()` refreshes movie metadata** — re-saving after a metadata update writes the new title/poster

I deliberately did NOT write a widget test for the Movies page itself — it depends on TMDB Dio + DB + multiple providers, and the load-bearing behavior (FK-guarded save) is already covered by the repository test. Better leverage from one focused test than three brittle ones.

---

---

## Step 10 — Movie Detail page

**Goal:** Page 04. Large poster with Hero animation from the Movies card, title, formatted release date, overview, save button, and a live "N users want to watch this" line with mini avatars.

- `movieDetailProvider` — `FutureProvider.autoDispose.family<TmdbMovie, int>` that calls `MoviesRepository.fetchDetailAndCache`. AutoDispose so the cache doesn't grow unbounded as users browse.
- `usersWhoSavedProvider` — `StreamProvider.family<List<User>, int>` over a new `SavedMoviesDao.watchUsersWhoSaved` query (INNER JOIN of `saved_movies` and `users`). Live — adds new avatars as users save in real time.
- `SliverAppBar` with `expandedHeight: 360` + `flexibleSpace` containing a `Hero(tag: 'movie-poster-$movieId')` wrapping the w500 poster. Same tag as the Movies card → free morphing animation.
- Save button is reused from Movies page. If `activeUserId` is null (e.g., navigated from Matches without selecting a user), shows an info message instead — no crash, no broken UI.
- Overlapping mini avatars rendered with `Stack` + `Positioned`. Up to 5 avatars visible, "+N" suffix when more saved.
- Date formatted manually ("July 18, 2008") to avoid pulling `intl` for one helper.

---

---

## Step 11 — Saved Movies, Matches, Reconnecting banner, README

Final polish phase, all wired in one batch:

**Saved Movies page** — `userByIdProvider` (live single-user lookup) + `savedMoviesForUserProvider` (Stream of Drift `Movie` rows for a given userId). Header shows the user's avatar/name/taste; body reuses `MovieCard` via a `Movie.toTmdb()` extension in `tmdb_movie.dart`. Fully offline because it only reads from Drift Streams — no network involvement at all. Empty state prompts the user to browse trending.

**Matches page** — `matchesStreamProvider` over `savedMoviesDao.watchMatches()`. The `customSelect` with `readsFrom: {savedMovies, movies}` makes it live by construction: any save anywhere in the app re-emits this stream automatically. Each `MatchCard` shows mini avatars by mapping `match.userIds` through `userByIdProvider(userId)` (Riverpod's `family` dedupes per user, so we don't fan-out queries). The "TOP PICK" highlight (amber border + label) fires when `match.saveCount >= totalUsers && totalUsers >= 2` — guard against single-user "everyone saved" being meaningless.

**Reconnecting banner** — `ReconnectingBanner` is a `ConsumerWidget` that watches `networkStatusProvider`. Wired into `MaterialApp.router.builder` as a `Stack` overlay, so it appears on every page without each page wiring it. Bottom-pinned `StadiumBorder` chip with a small spinner — non-blocking, matches the spec's "small bar, not a popup" requirement.

**README** — full submission doc: setup, architecture diagram (Mermaid), design system, schema (with the user→saved_movies relationship called out as the headline DB decision), offline strategy walkthrough of the airplane-mode test, retry behavior, live-data explanation, list of non-obvious decisions, known limitations, AI disclosure pointing here.

---

## Project status

**Done.** All 6 pages from the spec are wired to real data. 23 tests passing. Analyzer clean. Foundation, sync, retry, and live-update mechanisms all covered by tests. UI polished with shimmer skeletons, staggered fade-ins, hero animations on posters, animated save buttons and count badges, M3 dark theme with consistent design tokens.

Ready to push to GitHub and submit.
