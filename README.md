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
mise install          # Flutter and the tools, at the versions in mise.toml
scripts/dev.sh        # in Chrome, on the port login expects
```

`CONTRIBUTING.md` has the rest: layout, how we test, and how pull requests work.
