# SPDX-FileCopyrightText: © 2026 Jeffrey C. Ollie <jeff@ocjtech.us>
# SPDX-License-Identifier: MIT

{
  callPackage,
  lib,
  stdenv,
  zig,
  sqlite,
  pkg-config,
  ...
}:
let
  deps = callPackage ./build.zig.zon.nix { };
in
stdenv.mkDerivation (finalAttrs: {
  name = "zig-overlay-update";
  src = lib.cleanSource ./.;
  postPatch = lib.concatMapStrings (p: ''
    cp -rsL --no-preserve=mode ${deps}/${p} fork-${p}
  '') deps.pathDependencyPackages;
  buildInputs = [
    sqlite
  ];
  nativeBuildInputs = [
    zig
    pkg-config
  ];
  zigBuildFlags = [
    "--system"
    "${deps}"
  ]
  ++ map (p: "--fork=fork-${p}") deps.pathDependencyPackages;
  zigCheckFlags = finalAttrs.zigBuildFlags;
  meta = {
    mainProgram = "zig-overlay-update";
    license = lib.licenses.mit;
  };
})
