#!@shell@
# SPDX-FileCopyrightText: © 2026 Jeffrey C. Ollie <jeff@ocjtech.us>
# SPDX-License-Identifier: MIT

# Zig works out the native ABI and glibc version by reading the ELF
# interpreter of /usr/bin/env, a path compiled into the binary. A Nix build
# sandbox has no /usr/bin/env, and without one the statically linked binary
# falls back to its own ABI, musl. Where /usr/bin/env is missing, run Zig in a
# mount namespace that has one.

if [ -e /usr/bin/env ]; then
  exec @zig@ "$@"
fi

args=(--tmpfs /)
for dir in /*; do
  args+=(--dev-bind "$dir" "$dir")
done
args+=(--ro-bind @env@ /usr/bin/env --chdir "$PWD")

# Some hosts forbid the user namespace bubblewrap needs -- Ubuntu from 24.04
# restricts them with AppArmor, which is what GitHub's runners are -- and then
# bubblewrap fails before Zig runs. Its exit status cannot be told apart from
# Zig's own, so try it first with something that cannot fail, and where it
# cannot start, run Zig directly: the native target is then musl, as it was
# before this wrapper existed, which is wrong only for a build that links libc.
if ! @bwrap@ "${args[@]}" -- @env@ true 2>/dev/null; then
  exec @zig@ "$@"
fi

exec @bwrap@ "${args[@]}" -- @zig@ "$@"
