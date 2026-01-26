{ stdenv, darwin }:

stdenv.mkDerivation {
  pname = "choose";
  version = "0.1.0";

  src = ./.;

  buildInputs = with darwin.apple_sdk.frameworks; [
    SwiftUI
    AppKit
    Foundation
  ];

  buildPhase = ''
    mkdir -p Choose.app/Contents/MacOS
    swiftc -parse-as-library -o Choose.app/Contents/MacOS/choose main.swift \
      -framework SwiftUI \
      -framework AppKit \
      -O
    cp Info.plist Choose.app/Contents/
  '';

  installPhase = ''
    mkdir -p $out/Applications
    cp -r Choose.app $out/Applications/

    mkdir -p $out/bin
    ln -s $out/Applications/Choose.app/Contents/MacOS/choose $out/bin/choose
  '';

  meta = {
    description = "A minimal dmenu-like picker for macOS";
    platforms = [ "aarch64-darwin" "x86_64-darwin" ];
  };
}
