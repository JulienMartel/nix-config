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
      username = "julienmartel";
      hostname = "mbp";
      system = "aarch64-darwin";
    in
    {
      darwinConfigurations.${hostname} = nix-darwin.lib.darwinSystem {
        inherit system;
        specialArgs = { inherit username; };
        modules = [
          ./hosts/${hostname}/configuration.nix
          home-manager.darwinModules.home-manager
          {
            users.users.${username} = {
              name = username;
              home = "/Users/${username}";
            };

            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.backupFileExtension = "backup";
            home-manager.extraSpecialArgs = { inherit username; };
            home-manager.users.${username} = import ./home/home.nix;
          }
        ];
      };
    };
}
