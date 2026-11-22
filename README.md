# Lillith

Private cycle tracking from skin temperature. Lillith reads the temperature
your smart ring or watch records overnight, spots the rise that follows
ovulation, and predicts when your next period starts. Everything you log stays
encrypted on your own [Solid](https://solidproject.org) pod: you own the data,
and nobody else can read it.

A Flutter app for Android, iOS and the web, licensed
[AGPL-3.0-or-later](LICENSE).

## Status

A rewrite, in progress, of [CybrKat/LillithApp](https://github.com/CybrKat/LillithApp),
the original by Kat, whose design and ideas this project builds on. Features
are being ported one at a time, each with tests. Nothing here is medical
advice or a contraceptive tool.

## Run it

```bash
mise install                      # Flutter, JDK and the check tools, at the versions in mise.toml
git config core.hooksPath .githooks
scripts/dev.sh                    # the app in Chrome on :4400
flutter test                      # every test
scripts/ci.sh                     # everything CI runs, in CI's order
```

Tool versions live in `mise.toml`. CI installs the same. Don't install a
different version by hand.

## Layout

| Path | What |
|---|---|
| `lib/domain/` | Models and the predictors: plain Dart, no Flutter |
| `lib/data/` | `PodService` (the abstract interface to a Solid pod), its solidpod implementation, the document codec and `HealthRepository` |
| `lib/ui/<feature>/` | One folder per screen: `<feature>_screen.dart` (the view) and `<feature>_view_model.dart` |
| `lib/main.dart` | Wiring only: dependency injection and routes |
| `test/` | Mirrors `lib/`. `test/fakes/` holds the in-memory fakes |
| `integration_test/` | The few journeys that run on a device |
| `scripts/` | Everything you run: dev, CI |
| `checks/` | Repo checks CI runs (secrets, comment density) |
| `web/` | The web shell, the Solid OIDC client profile and redirect page |

## How we work

- **Boring and obvious beats clever.** A contributor who knows Flutter should
  be able to change a file without learning a local framework. No code
  generation, no custom DSLs, no clever abstractions.
- **A new dependency is a decision.** Say why in the pull request. The Flutter
  SDK and what is already used come first.
- **Follow Flutter's [architecture guide](https://docs.flutter.dev/app-architecture/recommendations).**
  Widgets are dumb; a screen's decisions live in its view model; data comes
  through a repository behind an abstract interface; dependencies are
  injected with `provider`, never reached through a global.
- **Vertical slices.** A change is a user need delivered end to end: data,
  view model, view, tests. A change that only adds a layer is not a slice.
- **Ask before building when something is unclear.** A question answered
  mid-implementation is a guess.
- **Everything in this repo is public**, comments and commit messages included.
  Never a real reading, a real pod URL, or anyone's health data: test data is
  invented.

### Tests: TDD, on everything

- Write the failing test, **watch it fail**, make it pass, refactor. A test
  that passes before the code exists tests nothing.
- **Test the failure paths**: the missing document, the refused write, the
  expired session, the malformed JSON.
- **Control what you depend on**: inject the clock and the `PodService`. No
  `DateTime.now()` below `main.dart`.
- **Unit tests** for every model, predictor, codec, repository and view model,
  as plain Dart against hand-written fakes (`test/fakes/`), not mocks.
- **Widget tests** for a screen check behaviour: given this repository state,
  the screen shows that. Never pixels, never golden files, never wording.
  A test changes only when behaviour changes.
- **Integration tests** are few: login, log a reading, see the prediction.
  They run on a device by hand or nightly, never per pull request.
- **One function, several cases: one list of cases**, each named, every
  failing case reported. A copy-pasted test is the signal.
- **Never loosen a test to make it pass.** Dropping an assertion changes what
  is tested: name it in the PR.
- **Coverage is a prompt to look, never a target.** `scripts/ci.sh` prints it.

### Comments: less comment than code

- A file comment says what the file does, in 1–3 lines. A declaration comment
  (`///`) says what it does, accepts and returns.
- Anything else is a one-liner, and only for a non-obvious *why*.
- No decision narratives in code. `checks/comment-density.sh` measures it.

## Pull requests

1. Branch from `main`. Never commit to `main`: the pre-push hook refuses it.
2. Commit as you go. One line, imperative, capitalised, no full stop, 72
   characters at most: `Add the temperature-shift predictor`. **No attribution
   footers** of any kind.
3. Run `scripts/ci.sh` before you push.
4. Open a pull request with two sections and nothing else: **What it does**
   and **How to test it**. A maintainer reviews and merges.
