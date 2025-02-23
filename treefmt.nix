# treefmt.nix
{ ... }:
{
  # Used to find the project root
  projectRootFile = "flake.nix";
  programs = {
    nixfmt.enable = true;
    yamlfmt.enable = true;
    shfmt.enable = true;
    mdformat.enable = true;
  };
}
