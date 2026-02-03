{ lib, stdenvNoCC, darwin }:

stdenvNoCC.mkDerivation {
  pname = "choose";
  version = "0.1.0";

  src = ./.;

  # Use system Swift via xcrun (from Xcode Command Line Tools)
  # This avoids building the entire Swift toolchain from source
  nativeBuildInputs = [ darwin.cctools ];

  buildPhase = ''
    mkdir -p Choose.app/Contents/MacOS

    # Use xcrun to invoke the system's Swift compiler
    /usr/bin/xcrun swiftc -parse-as-library -o Choose.app/Contents/MacOS/choose main.swift \
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
    cp ports $out/bin/ports
    chmod +x $out/bin/ports
  '';

  meta = {
    description = "A minimal dmenu-like picker for macOS";
    platforms = lib.platforms.darwin;
  };
}
