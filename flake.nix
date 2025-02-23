{
  description = "A flake to setup testing istio service mesh between two clusters";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    treefmt-nix.url = "github:numtide/treefmt-nix";
  };

  outputs =
    {
      self,
      nixpkgs,
      systems,
      treefmt-nix,
    }:
    let
      eachSystem = f: nixpkgs.lib.genAttrs (import systems) (system: f nixpkgs.legacyPackages.${system});
      treefmtEval = eachSystem (pkgs: treefmt-nix.lib.evalModule pkgs ./treefmt.nix);
    in
    {
      formatter = eachSystem (pkgs: treefmtEval.${pkgs.system}.config.build.wrapper);
      devShell = eachSystem (
        { pkgs, ... }:
        let
          setupClusters = pkgs.writeShellApplication {
            name = "setup-clusters";
            runtimeInputs = with pkgs; [
              kubectl
              kind
              openssl
            ];
            text = builtins.readFile ./scripts/setup_clusters.sh;
          };
        in
        pkgs.mkShell {
          buildInputs = with pkgs; [
            setupClusters
            openssl
            kubectl
            kind
            kustomize
            istioctl
          ];
        }
      );
    };
}
