{
  lib,
  stdenvNoCC,
  darwin,
}:

stdenvNoCC.mkDerivation {
  pname = "pounce";
  version = "0.2.0";

  src = ./.;

  # Use system Swift via xcrun (from Xcode Command Line Tools)
  # This avoids building the entire Swift toolchain from source
  nativeBuildInputs = [ darwin.cctools ];

  buildPhase = ''
    mkdir -p Pounce.app/Contents/MacOS

    # Use xcrun to invoke the system's Swift compiler
    /usr/bin/xcrun swiftc -parse-as-library -o Pounce.app/Contents/MacOS/pounce main.swift \
      -framework SwiftUI \
      -framework AppKit \
      -framework ApplicationServices \
      -O

    cp Info.plist Pounce.app/Contents/

    # Bundle the emoji dataset (read at runtime via Bundle.main).
    mkdir -p Pounce.app/Contents/Resources
    cp emoji.json Pounce.app/Contents/Resources/
  '';

  installPhase = ''
    mkdir -p $out/Applications
    cp -r Pounce.app $out/Applications/

    mkdir -p $out/bin
    ln -s $out/Applications/Pounce.app/Contents/MacOS/pounce $out/bin/pounce
    cp ports $out/bin/ports
    chmod +x $out/bin/ports
  '';

  meta = {
    description = "A minimal dmenu-like picker for macOS";
    platforms = lib.platforms.darwin;
  };
}
