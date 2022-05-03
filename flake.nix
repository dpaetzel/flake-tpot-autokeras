{
  description = "My Python flake";

  # This is commit that the system drivers are currently built from.
  inputs.nixpkgs.url =
    "github:NixOS/nixpkgs/4afca382d80b68bff9e154a97210e5a7bf5df8b3";

  outputs = inputs@{ self, nixpkgs }:

    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };

      pythonStr = "python38";
      python = pkgs.${pythonStr};

      cudnn = pkgs.cudnn_cudatoolkit_11_2;
      nvidia = pkgs.linuxPackages.nvidia_x11;
      cc = pkgs.stdenv.cc.cc;
      magma = pkgs.magma.override { inherit cudatoolkit; };

      # CUDA needs to be fixed. See
      # https://github.com/NixOS/nixpkgs/blob/4afca382d80b68bff9e154a97210e5a7bf5df8b3/pkgs/development/python-modules/tensorflow/default.nix#L45
      cudatoolkit = pkgs.cudaPackages.cudatoolkit_11_2;
      cudatoolkitJoined = pkgs.symlinkJoin {
        name = "${cudatoolkit.name}-merged";
        paths = [ cudatoolkit.lib cudatoolkit.out ];
      };

    in rec {

      devShell.${system} = pkgs.mkShell {

        venvDir = "./.venv";
        postShellHook = ''
          export LD_LIBRARY_PATH="${
            pkgs.lib.makeLibraryPath [ cc cudatoolkitJoined cudnn nvidia pkgs.zlib ]
          }:$LD_LIBRARY_PATH";

          unset SOURCE_DATE_EPOCH
          # TODO Comment out after everything works.
          pip install -r requirements.txt
        '';

        postVenvCreation = ''
          unset SOURCE_DATE_EPOCH
          pip install -r requirements.txt
        '';

        buildInputs = [
          python.pkgs.python
          python.pkgs.venvShellHook
        ];
      };

    };
}
