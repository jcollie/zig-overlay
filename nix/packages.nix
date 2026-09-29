# SPDX-FileCopyrightText: © 2022 Mitchell Hashimoto
# SPDX-License-Identifier: MIT

# The Zig packages for one system, built from the data that `nix run .#update`
# writes into `sources-<system>.nix` and `mirrors.nix`:
#
#  - <version>      - a tagged release
#  - master-<date>  - the nightly built on that date
#  - master         - the newest nightly
#  - default        - the newest tagged release
{
  lib,
  pkgs,
  system,
}:
let
  sources = import (./. + "/sources-${system}.nix");
  mirrors = import ./mirrors.nix;

  # Try the community mirrors first, as ziglang.org asks, and fall back to
  # ziglang.org itself.
  mkBinaryInstall =
    {
      version,
      hash,
      url,
      ...
    }:
    let
      tarball = lib.last (lib.splitString "/" url);
      fromZigLang = lib.hasPrefix "https://ziglang.org/" url;
      fromMirrors = map (mirror: "${mirror}/${tarball}?source=nix-zig-overlay") mirrors;
    in
    pkgs.callPackage ./package.nix {
      inherit version hash;
      urls = lib.optionals fromZigLang fromMirrors ++ [ url ];
    };

  newest = a: b: if builtins.compareVersions b.version a.version > 0 then b else a;

  taggedPackages = lib.mapAttrs (_: mkBinaryInstall) sources.releases;

  # A date occasionally has more than one nightly, and a version was
  # occasionally published on two dates; take the newest version of each date.
  nightlies = lib.mapAttrs (_: builds: lib.foldl' newest (lib.head builds) builds) (
    lib.groupBy (build: build.date) sources.builds
  );

  masterPackages = lib.mapAttrs' (
    date: build: lib.nameValuePair "master-${date}" (mkBinaryInstall build)
  ) nightlies;

  latestDate = lib.last (lib.sort (a: b: a < b) (lib.attrNames nightlies));
  latestRelease = lib.foldl' newest { version = "0"; } (lib.attrValues sources.releases);
in
taggedPackages
// masterPackages
// lib.optionalAttrs (nightlies != { }) {
  master = masterPackages."master-${latestDate}";
}
// lib.optionalAttrs (sources.releases != { }) {
  default = taggedPackages.${latestRelease.version};
}
