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
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      nix-darwin,
      home-manager,
      catppuccin,
    }:
    let
      username = "julienmartel";
      hostname = "mbp";
      system = "aarch64-darwin";

      # Overlay for local packages
      localOverlay = final: prev: {
        choose = final.callPackage ./pkgs/choose { };
        choose-commands = final.callPackage ./pkgs/choose-commands { };
      };
      pkgs = import nixpkgs {
        inherit system;
        overlays = [ localOverlay ];
      };
    in
    {
      packages.${system} = {
        choose = pkgs.choose;
        choose-commands = pkgs.choose-commands;
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
            home-manager.extraSpecialArgs = { inherit username; };
            home-manager.sharedModules = [
              catppuccin.homeModules.catppuccin
            ];
            home-manager.users.${username} = import ./home/home.nix;
          }
        ];
      };
    };
}
