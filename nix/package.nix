# SPDX-FileCopyrightText: © 2022 Mitchell Hashimoto
# SPDX-License-Identifier: MIT

{
  stdenv,
  lib,
  path,
  fetchurl,
  callPackage,
  wrapCCWith,
  wrapBintoolsWith,
  overrideCC,
  xcbuild,
  version,
  urls,
  hash,
  ...
}:
let
  # The setup hook and the passthru helpers (hook, cc, bintools, stdenv,
  # fetchDeps) come from the Zig package in nixpkgs rather than being carried
  # here, so that they stay in step with it. This is a directory inside
  # nixpkgs rather than a public interface: if it moves, evaluation fails here.
  upstream = path + "/pkgs/development/compilers/zig";

  isNightly = lib.hasInfix "-dev." version;

  # Whether this is at least the tagged release `v`, counting the nightlies
  # leading up to it as older, since when during a cycle a feature arrived is
  # not recorded here.
  atLeastRelease = v: lib.versionAtLeast version v && !lib.hasPrefix "${v}-" version;

  # The setup hook always passes `zig build -j<N>`, which Zig before 0.11
  # rejects, so older versions get no hook at all rather than one that fails
  # every build it touches.
  hasSetupHook = atLeastRelease "0.11.0";

  # `zig build --release` arrived in 0.12; the hook's default optimize flag is
  # left empty for anything older, which builds in Debug mode.
  hasReleaseFlag = atLeastRelease "0.12.0";
in
stdenv.mkDerivation (finalAttrs: {
  inherit version;

  pname = "zig";

  src = fetchurl { inherit urls hash; };

  # dontConfigure = true;
  # dontBuild = true;
  # dontFixup = true;

  preBuild = ''
    export ZIG_GLOBAL_CACHE_DIR="$TMPDIR/zig-cache";
  '';

  strictDeps = true;

  installPhase = ''
    mkdir -p $out/{doc,bin,lib}
    [ -d docs ] && cp -r docs/* $out/doc
    [ -d doc ] && cp -r doc/* $out/doc
    cp -r lib/* $out/lib
    cp zig $out/bin/zig
  '';

  env = {
    zig_default_cpu_flag = "-Dcpu=baseline";
    zig_default_optimize_flag = lib.optionalString hasReleaseFlag "--release=safe";
  };

  setupHook = if hasSetupHook then upstream + "/setup-hook.sh" else null;

  # Zig needs xcode-select, from xcbuild, to find the SDK on Darwin.
  propagatedNativeBuildInputs = lib.optionals stdenv.hostPlatform.isDarwin [ xcbuild ];

  passthru = import (upstream + "/passthru.nix") {
    inherit
      stdenv
      callPackage
      wrapCCWith
      wrapBintoolsWith
      overrideCC
      ;
    zig = finalAttrs.finalPackage;
  };

  meta = {
    description = "General-purpose programming language and toolchain for maintaining robust, optimal, and reusable software";
    homepage = "https://ziglang.org/";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ andrewrk ];
    teams = [ lib.teams.zig ];
    mainProgram = "zig";
    platforms = lib.platforms.unix;
  }
  # Nightlies have no release notes.
  // lib.optionalAttrs (!isNightly) {
    changelog = "https://ziglang.org/download/${version}/release-notes.html";
  };
})
