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
  };

  outputs = inputs@{ self, nixpkgs, nix-darwin, home-manager }:
    let
      system = "aarch64-darwin";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      darwinConfigurations."mbp" = nix-darwin.lib.darwinSystem {
        inherit system;
        modules = [
          ./hosts/mbp/configuration.nix
          home-manager.darwinModules.home-manager
          {
            # Define the user
            users.users.julienmartel = {
              name = "julienmartel";
              home = "/Users/julienmartel";
            };

            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.backupFileExtension = "backup";
            home-manager.users.julienmartel = import ./home/home.nix;
          }
        ];
      };
    };
}
