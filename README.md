<!-- SPDX-FileCopyrightText: © 2022 Mitchell Hashimoto -->
<!-- SPDX-License-Identifier: MIT -->

# Nix Flake for Zig

This repository is a Nix flake packaging the [Zig](https://ziglang.org)
compiler. It packages the binaries built officially by the Zig project and
does not build them from source. A scheduled job checks for new releases and
nightlies every four hours and commits whatever it finds.

The repository lives at <https://git.jcollie.dev/jeff/zig-overlay>, and is
mirrored at <https://tangled.org/jcollie.dev/zig-overlay>.

## Packages

For each system, the flake provides:

- `default` — the newest tagged release
- `"<version>"` — a tagged release, such as `"0.16.0"`
- `master` — the newest nightly
- `master-<date>` — the nightly built on that date, such as `master-2021-02-13`

and the apps `default`/`zig`, which run the newest tagged release.

Packages are provided for `x86_64-linux`, `aarch64-linux` and
`aarch64-darwin`, and, where Zig has published builds for them, for
`armv7l-linux`, `i686-linux`, `loongarch64-linux`, `powerpc64le-linux`,
`riscv64-linux` and `s390x-linux`. There is no `x86_64-darwin`, because
nixpkgs no longer supports it; Zig's Windows and BSD builds are recorded but
not packaged.

Each package downloads from the Zig community mirrors first and falls back to
ziglang.org, as the Zig project recommends, and checks the tarball against the
SHA-256 published in Zig's release index.

The packages can stand in for `zig` from nixpkgs when building other
packages. Their setup hook and their `hook`, `cc`, `bintools`, `stdenv` and
`fetchDeps` attributes are taken from the Zig package in the pinned nixpkgs
rather than copied here. Putting one in `nativeBuildInputs` supplies the
configure, build, check and install phases for a Zig project, with these
limits:

- Zig before 0.11 rejects the `-j` flag the hook passes, so those versions
  have no setup hook and only put `zig` on the `PATH`.
- `--release=safe` is passed only from Zig 0.12, which introduced it, so 0.11
  builds in Debug mode unless the project asks otherwise.
- Nightlies count as older than the release they lead up to.

## Usage

In a `flake.nix`:

```nix
{
  inputs.zig.url = "git+https://git.jcollie.dev/jeff/zig-overlay.git";

  outputs = { self, zig, ... }: {
    # zig.packages.${system}.default, zig.packages.${system}.master, ...
  };
}
```

In a shell:

```console
# run the newest tagged release
$ nix run 'git+https://git.jcollie.dev/jeff/zig-overlay.git'
# a shell with the nightly from 2021-02-13 (the oldest available)
$ nix shell 'git+https://git.jcollie.dev/jeff/zig-overlay.git#master-2021-02-13'
# a shell with the newest nightly
$ nix shell 'git+https://git.jcollie.dev/jeff/zig-overlay.git#master'
# a shell with a particular release
$ nix shell 'git+https://git.jcollie.dev/jeff/zig-overlay.git#"0.14.0"'
```

## How it is updated

`nix run .#update`, run from the root of the repository, builds and runs the
update tool in `update/`. It:

1. downloads Zig's list of community mirrors and its release index,
   `index.json`, along with the `sources.json` history kept by
   [mitchellh/zig-overlay](https://github.com/mitchellh/zig-overlay);
2. records every artifact in `sources.sqlite3`, keyed by its SHA-256, with
   Zig's target names (`x86_64-macos`, `x86-linux`) translated to Nix systems;
3. writes `nix/mirrors.nix` and one `nix/sources-<system>.nix` per system,
   which hold data only — version, date, hash and URL.

`nix/packages.nix` turns that data into packages. Tagged releases are the
artifacts published under `/download/`; everything under `/builds/` is a
nightly, and where a date has more than one nightly, `master-<date>` is the
newest version among them.

The database is committed because it is the history: `index.json` lists only
the tagged releases and the one current nightly, so a nightly that was never
recorded while it was current cannot be recovered later. The tool changes the
database only when something is new, so a run that finds nothing leaves the
tree clean.

The scheduled Forgejo workflow in `.forgejo/workflows/cron.yaml` runs the
update, refuses to commit unless every system still evaluates
(`nix flake check --no-build --all-systems`), and pushes any change to
`main`.

### Working on the update tool

```console
$ nix develop
$ cd update
$ zig build test
$ zig fmt --check --exclude zig-pkg --exclude .zig-cache .
```

After changing a dependency in `update/build.zig.zon`, regenerate
`update/build.zig.zon.nix` with:

```console
$ nix develop -c zon2nix --16 --nix=update/build.zig.zon.nix update/build.zig.zon
```

## FAQ

### Why is a nightly missing?

There are two possible reasons:

1. Zig's release index only shows the latest _master_ release. It doesn't
   keep track of historical ones. If this overlay wasn't running, or didn't
   exist, at the time of a nightly, that day is missing. This is why
   historical dates beyond a certain point don't exist: they predate this
   overlay (or the original overlays it derives from).

2. The official Zig CI only publishes a master build if the CI runs full
   green. During certain periods of development a whole day may go by where
   the master branch of the Zig compiler is broken, and no nightly is built
   at all.

## Thanks

This flake derives from [mitchellh/zig-overlay](https://github.com/mitchellh/zig-overlay),
whose `sources.json` was in turn inherited from an overlay by the user `arqv`,
since deleted. Thank you for compiling nightly release information since
2021!

## License

MIT, following the [REUSE](https://reuse.software/) specification. The
generated data files and `sources.sqlite3` are CC0-1.0.

## References cited

- Zig Software Foundation. “Zig Release Index.”
  <https://ziglang.org/download/index.json>.
- Zig Software Foundation. “Community Mirrors.”
  <https://ziglang.org/download/community-mirrors/>.
