{
  inputs,
  pkgs,
  ...
}:
let
  unstable = import inputs.nixpkgs-unstable {
    inherit (pkgs.stdenv.hostPlatform) system;
    config.allowUnfree = true;
  };

in
{
  # Minimal Python: just the notebook infrastructure.
  # Scientific stacks (numpy/torch/polars/...) belong to per-project uv envs,
  # registered as named kernels via `ipykernel install --user --name <proj>`.
  home.packages = with unstable; [
    python3
    python3Packages.ipykernel
    python3Packages.jupyter-client
    python3Packages.jupytext
  ];

  xdg.configFile."jupytext/jupytext.toml".text = ''
    default_notebook_metadata_filter = "-all"
    default_cell_metadata_filter = "-all"
    formats = "ipynb,py:percent"
  '';

  home.sessionVariables = {
    # Let jupyter find per-project kernels installed via `ipykernel install --user`
    JUPYTER_PATH = "$HOME/.local/share/jupyter";
  };
}
