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

exec @bwrap@ "${args[@]}" -- @zig@ "$@"
