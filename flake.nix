{
  description = "Julien's nix-darwin and home-manager configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    nix-darwin = {
      url = "github:LnL7/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    catppuccin.url = "github:catppuccin/nix";

    # Nebelung theme builder (Catppuccin Mocha, blue stripped). Renders every
    # port with whiskers in a pure derivation, so no imperative `brew install
    # whiskers` and the themes rebuild with `darwin-rebuild`. Follows our
    # nixpkgs + catppuccin so there's a single whiskers/nixpkgs in the closure.
    nebelung = {
      url = "github:JulienMartel/nebelung";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.catppuccin.follows = "catppuccin";
    };

    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      nix-darwin,
      home-manager,
      catppuccin,
      nebelung,
      nix-index-database,
    }:
    let
      username = "julienmartel";
      hostname = "mbp";
      system = "aarch64-darwin";

      # Overlay for local packages
      localOverlay = final: prev: {
        pounce = final.callPackage ./pkgs/pounce { };
        pounce-commands = final.callPackage ./pkgs/pounce-commands { };
      };
      pkgs = import nixpkgs {
        inherit system;
        overlays = [ localOverlay ];
      };
    in
    {
      packages.${system} = {
        pounce = pkgs.pounce;
        pounce-commands = pkgs.pounce-commands;
      };

      darwinConfigurations.${hostname} = nix-darwin.lib.darwinSystem {
        inherit system;
        specialArgs = { inherit username; };
        modules = [
          ./hosts/${hostname}/configuration.nix
          home-manager.darwinModules.home-manager
          {
            nixpkgs.overlays = [
              localOverlay
            ];
            users.users.${username} = {
              name = username;
              home = "/Users/${username}";
            };

            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.backupFileExtension = "backup";
            home-manager.extraSpecialArgs = {
              inherit username;
              # Built Nebelung theme tree + the palette as a name->"#hex" attrset.
              nebelung = {
                themes = nebelung.packages.${system}.default;
                palette = nebelung.palette;
              };
            };
            home-manager.sharedModules = [
              catppuccin.homeModules.catppuccin
              nix-index-database.homeModules.nix-index
            ];
            home-manager.users.${username} = import ./home/home.nix;
          }
        ];
      };
    };
}
