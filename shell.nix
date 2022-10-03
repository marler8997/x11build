{ pkgs ? import <nixpkgs> { } }:

pkgs.stdenvNoCC.mkDerivation {
  name = "shell";
  nativeBuildInputs = with pkgs; [
    autoconf automake pkgconfig libtool python3
  ];
}
