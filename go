#!/usr/bin/env bash
set -ex

dir=$(dirname $(readlink -f ${BASH_SOURCE[0]}))
./with-zig-tools true
export PATH="$dir/zig-tools:$PATH"

os=ubuntu
os=nixos

zig build -Dfetch xcbproto -D$os -Dtarget=x86_64-linux --verbose
zig build -Dfetch xorg-macros -D$os -Dtarget=x86_64-linux --verbose
zig build -Dfetch xorgproto -D$os -Dtarget=x86_64-linux --verbose
zig build -Dfetch libxau -D$os -Dtarget=x86_64-linux --verbose

# libxcb not compiling yet
#zig build -Dfetch libxcb -D$os -Dtarget=x86_64-linux --verbose

zig build -Dfetch libxtrans -D$os -Dtarget=x86_64-linux --verbose

# libx11 not compiling yet
#zig build -Dfetch libx11 -D$os -Dtarget=x86_64-linux --verbose
# libxext not compiling yet
#zig build -Dfetch libxext -D$os -Dtarget=x86_64-linux --verbose
