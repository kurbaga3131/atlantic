{
  description = "atlantic - a desktop shell built for YOU.";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    atlantic-wallpapers = {
      url = "github:kurbaga3131/shell-wallpapers";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, atlantic-wallpapers, ... }:
    let
      supportedSystems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
      pkgsFor = system: import nixpkgs { inherit system; };
    in
    {
      overlays.default = final: _prev: {
        atlantic = final.callPackage ./nix/package.nix {
          rev = self.rev or self.dirtyRev or "dirty";
        };
      };

      packages = forAllSystems (system:
        let pkgs = pkgsFor system;
        in {
          default = pkgs.callPackage ./nix/package.nix {
            rev = self.rev or self.dirtyRev or "dirty";
          };
          atlantic = self.packages.${system}.default;
        });

      apps = forAllSystems (system: {
        default = {
          type = "app";
          program = "${self.packages.${system}.default}/bin/atlantic";
        };
        atlanticd = {
          type = "app";
          program = "${self.packages.${system}.default}/bin/atlanticd";
        };
      });

      devShells = forAllSystems (system:
        let pkgs = pkgsFor system;
        in {
          default = pkgs.mkShell {
            inputsFrom = [ self.packages.${system}.default ];
            packages = with pkgs; [ nixpkgs-fmt nil ];
          };
        });

      homeManagerModules.default = import ./nix/hm-module.nix {
        inherit self;
        wallpapers = atlantic-wallpapers;
      };
      homeManagerModules.atlantic = self.homeManagerModules.default;

      nixosModules.default = import ./nix/nixos-module.nix;
      nixosModules.atlantic = self.nixosModules.default;

      formatter = forAllSystems (system: (pkgsFor system).nixpkgs-fmt);
    };
}
