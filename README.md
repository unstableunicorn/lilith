# Lilith

Private cycle tracking from skin temperature. Lilith reads the temperature
your smart ring or watch records overnight, spots the rise that follows
ovulation, and predicts when your next period starts. Everything you log stays
encrypted on your own [Solid](https://solidproject.org) pod: you own the data,
and nobody else can read it.

A Flutter app for Android, iOS and the web, licensed
[AGPL-3.0-or-later](LICENSE).

## Status

A rewrite, in progress, of [CybrKat/LillithApp](https://github.com/CybrKat/LillithApp),
the original by Kat, whose design and ideas this project builds on. The name
is [Lilith](https://en.wikipedia.org/wiki/Lilith), one l; the original spelled
it with two. Features
are being ported one at a time, each with tests. Nothing here is medical
advice or a contraceptive tool.

The web app is at [lilith.unstableunicorn.dev](https://lilith.unstableunicorn.dev),
deployed from `main`.

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

See [CONTRIBUTING.md](CONTRIBUTING.md): the architecture, TDD, the one theme,
accessibility, analysis rules and the pull request routine, with the Flutter
guidance each follows.
