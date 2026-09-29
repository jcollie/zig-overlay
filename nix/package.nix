# SPDX-FileCopyrightText: © 2022 Mitchell Hashimoto
# SPDX-License-Identifier: MIT

{
  stdenv,
  lib,
  fetchurl,
  callPackage,
  wrapCCWith,
  wrapBintoolsWith,
  overrideCC,
  version,
  urls,
  hash,
  ...
}:
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
    zig_default_optimize_flag = "--release=safe";
  };

  setupHook = ./setup-hook.sh;

  passthru = import ./passthru.nix {
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
    changelog = "https://ziglang.org/download/${version}/release-notes.html";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ andrewrk ];
    teams = [ lib.teams.zig ];
    mainProgram = "zig";
    platforms = lib.platforms.unix;
  };
})
