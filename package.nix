{
  stdenv,
  lib,
  fetchurl,
  xcbuild,
  callPackage,
  wrapCCWith,
  wrapBintoolsWith,
  overrideCC,
  version,
  urls,
  sha256,
  ...
}:
stdenv.mkDerivation (finalAttrs: {
  inherit version;

  pname = "zig";

  src = fetchurl { inherit urls sha256; };

  dontConfigure = true;
  dontBuild = true;
  dontFixup = true;

  installPhase = ''
    mkdir -p $out/{doc,bin,lib}
    [ -d docs ] && cp -r docs/* $out/doc
    [ -d doc ] && cp -r doc/* $out/doc
    cp -r lib/* $out/lib
    cp zig $out/bin/zig
  '';

  propagatedNativeBuildInputs = lib.optionals stdenv.hostPlatform.isDarwin [ xcbuild ];

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
