# Contributing to Lilith

How this app is built, and why. It follows Flutter's own
[architecture recommendations](https://docs.flutter.dev/app-architecture/recommendations),
[accessibility checklist](https://docs.flutter.dev/ui/accessibility) and
[testing guidance](https://docs.flutter.dev/testing/overview), and
[Effective Dart](https://dart.dev/effective-dart). Where we deviate, this file
says so. CI (`scripts/ci.sh`) enforces what can be enforced.

## Principles

- **Boring and obvious beats clever.** A contributor who knows Flutter should
  be able to change a file without learning a local framework. No code
  generation, no custom DSLs, no clever abstractions.
- **A new dependency is a decision.** Say why in the pull request. The Flutter
  SDK and what is already used come first.
- **Vertical slices.** A change is a user need delivered end to end: data,
  view model, view, tests. A change that only adds a layer is not a slice.
- **Ask before building when something is unclear.** A question answered
  mid-implementation is a guess.
- **Everything in this repo is public**, comments and commit messages included.
  Never a real reading, a real pod URL, or anyone's health data: test data is
  invented. Secrets live in CI secrets or a file under `$XDG_RUNTIME_DIR`,
  never in git, never in a chat.

## Architecture

Flutter's recommended shape, MVVM with a data layer behind abstract
repositories, as described in the architecture guide.

| Path | What |
|---|---|
| `lib/domain/` | Immutable models and the predictors: plain Dart, no Flutter import |
| `lib/data/` | Repositories (`HealthRepository`, `ShareRepository`, …) and the service seams they use: `PodService`, `ShareService`, `NotificationService`, each an abstract interface with one real implementation and one fake |
| `lib/data/pod/` | The only code that imports `solidpod` or `solid_auth` |
| `lib/ui/<feature>/` | One folder per screen: `<feature>_screen.dart` (the view) and `<feature>_view_model.dart` |
| `lib/ui/components/`, `lib/ui/theme/` | The shared pieces and the one theme |
| `lib/main.dart` | Wiring only: the real services, the providers, which screen shows |
| `test/` | Mirrors `lib/`; `test/fakes/` holds the in-memory fakes |

Rules that follow from it:

- **A widget holds no decision.** What to show, in what order, which fallback,
  what a tap does: a view model method, with a test. Widgets read view model
  getters and call view model methods.
- **Dependencies come in through constructors** and reach widgets with
  `provider`. No singleton, no `static instance`, no service locator, no
  `DateTime.now()` below `main.dart`: the clock is injected.
- **Models are immutable**, annotated `@immutable`, with `copyWith`,
  `toJson`/`fromJson`, `==` and `hashCode` (Effective Dart: override both or
  neither). Dates that mean a day are normalised to midnight on construction.
  We write them by hand rather than generate them (see Principles).
- **One source of truth per kind of data.** `HealthRepository` holds the
  user's document; screens never cache their own copy.
- **The pod document is versioned.** `HealthDocumentCodec.migrate` steps one
  version at a time, each step a pure map with its own test. Any change to
  what is stored bumps the version, even when the new fields are optional:
  an older app must refuse the document rather than drop fields on its next
  save. Bumps are rare and announced.
- **Navigation** is a tab shell plus a few pushed pages, done with `Navigator`.
  Flutter recommends `go_router` for most apps; this app is in the remainder
  where plain `Navigator` is simpler. Revisit if deep links grow.
- **Unidirectional flow.** State lives in repositories (`ChangeNotifier`);
  view models listen and expose; widgets render and call.

## Tests: TDD, on everything

- Write the failing test, **watch it fail**, make it pass, refactor. A test
  that passes before the code exists tests nothing.
- **Unit tests** (plain Dart) for every model, predictor, codec, repository
  and view model, against hand-written fakes in `test/fakes/`, not mocks.
  Test the failure paths: the missing document, the refused write, the
  expired session, the malformed JSON.
- **Widget tests** for every screen, through `test/harness.dart`: the real
  view model, fake repositories, assertions by `Key` or semantics, never by
  wording or pixels. Every screen test calls `expectAccessible(tester)`,
  which runs Flutter's guidelines (text contrast 4.5:1, 48 dp targets,
  labelled controls) on the screen as pumped, in the other theme, and at
  twice the text size, where an overflow fails the test. No golden files:
  the owner checks the look by eye.
- **Integration tests** are few and run on a device by hand
  (`scripts/smoke.sh`), never per pull request. For native dialogs such as
  permissions, Flutter points at `patrol`.
- **One function, several cases: one list of cases**, each named, every
  failing case reported. A copy-pasted test is the signal.
- **Never loosen a test to make it pass.** Dropping an assertion changes what
  is tested: name it in the PR.
- **Coverage is a prompt to look, never a target.** `scripts/ci.sh` prints it.

## Code style and analysis

- `analysis_options.yaml` includes `very_good_analysis` with the analyzer's
  strict modes. Four rules are turned off, each with its reason in the file:
  public member docs (the file header says what is not obvious), the new
  class-name-less constructor syntax (unfamiliar to most readers), cascades
  (tests read better as statements), and redundant-argument warnings (an
  explicit argument equal to the default is often the point).
- `flutter analyze --fatal-infos` must be clean. Prefer fixing to
  `// ignore`; an ignore carries a one-line reason.
- Effective Dart in brief: named parameters for booleans, `to…()` for
  copies, positive names for booleans, no runtime type tests to fake
  overloading, `const` where possible.
- **Comments: less comment than code.** A file comment says what the file
  does in one to three lines. A `///` says what a declaration does, accepts
  and returns. Anything else is a one-liner for a non-obvious *why*.
  `checks/comment-density.sh` measures it.

## The look: one theme, shared pieces, no drift

- Colours, type, spacing and radii come from `lib/ui/theme/`. A screen writes
  no literal colour, text style, radius, size or spacing; `checks/style-drift.sh`
  fails CI when one does.
- A piece of UI is a component the first time, not the second. Shared pieces
  live in `lib/ui/components/` and are used as they look; a look a piece
  lacks is a change to the piece, agreed first, never a screen's own copy.
- The design gallery (`lib/ui/design/`, reachable from the Pod tab in debug
  builds) shows every piece in both themes.
- Accessibility follows Flutter's release checklist: every control does
  something and has a spoken label, nothing is conveyed by colour alone, the
  UI stays legible at large text sizes, important actions are undoable.
  The theme test checks WCAG contrast for every colour pairing in both themes.
- The font is bundled (`assets/fonts/`, Roboto, Apache 2.0). The app fetches
  nothing from Google at run time.

## Pull requests

1. Branch from `main`. Never commit to `main`: the pre-push hook refuses it.
2. Commit as you go. One line, imperative, capitalised, no full stop, 72
   characters at most, then a short body saying why. **No attribution
   footers** of any kind.
3. Run `scripts/ci.sh` before you push. CI runs the same script.
4. Open a pull request with two sections and nothing else: **What it does**
   and **How to test it**. A maintainer reviews and merges.
