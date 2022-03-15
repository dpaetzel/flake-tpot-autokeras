{
  description = "My Python flake";

  inputs = {
    # This Nixpkgs commit provides Tensorflow <= 2.5 which is required by
    # autokeras.
    nixpkgs-tf24.url =
      "github:NixOS/nixpkgs/746b1b9d69263235b64f19337734fe57c5806ba8";

    nixpkgs.url = "github:NixOS/nixpkgs/21.11";

    overlays.url = "github:dpaetzel/overlays";

    autokerasSrc = {
      url = "github:keras-team/autokeras/1.0.16";
      flake = false;
    };
  };

  outputs = inputs@{ self, nixpkgs, nixpkgs-tf24, overlays, ... }:

    let
      system = "x86_64-linux";
      pkgsTf24 = import nixpkgs-tf24 {
        inherit system;
        config.allowUnfree = true;
        overlays = [
          overlays.keras-tuner
          (overlays.pythonPackageOverlay "python38" (final: prev: rec {
            tensorflow24 = prev.tensorflow.override {
              cudaSupport = true;
              inherit cudnn cudatoolkit;
            };

            autokeras = prev.buildPythonPackage {
              pname = "autokeras";
              version = "1.0.16";
              src = inputs.autokerasSrc;

              # I think we have a similar problem like these ones
              #
              # - https://github.com/NixOS/nixpkgs/issues/75125
              #
              # - https://github.com/NixOS/nixpkgs/issues/84774
              #
              # The Tensorflow package somehow isn't found by the setup.py . We
              # thus simply remove that line from setup.py as a dirty
              # workaround. What's interesting is that the Nix package for
              # Tensorflow is for version 2.4.4 but the Python package that gets
              # installed in the end is Tensorflow 2.4.2.
              postPatch = ''
                sed -i "s/.*tensorflow.*//" setup.py
              '';

              propagatedBuildInputs = [
                final.tensorflow24
                prev.keras-tuner
                prev.scikit-learn
                prev.pandas
                prev.packaging
              ];

              doCheck = false;
            };
          }))
        ];
      };
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };

      pythonStr = "python38";
      python = pkgsTf24.${pythonStr};

      cudatoolkit = pkgs.cudaPackages.cudatoolkit_11_2;
      cudnn = pkgs.cudnn_cudatoolkit_11_2;
      nvidia = pkgs.linuxPackages.nvidia_x11;
      cc = pkgs.stdenv.cc.cc;

    in rec {

      devShell.${system} = pkgs.mkShell {

        shellHook = ''
          export LD_LIBRARY_PATH="${
            pkgs.lib.makeLibraryPath [ cc cudatoolkit cudnn nvidia ]
          }:$LD_LIBRARY_PATH";
            unset SOURCE_DATE_EPOCH
        '';
        buildInputs = [ (python.withPackages (ps: [ ps.autokeras ])) ];
      };

    };
}
