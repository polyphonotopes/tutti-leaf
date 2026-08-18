{
  description =
    "tutti-leaf — a homogeneous ESP32 synth-mesh node: Rust p2p + AMY + BLE-MIDI on one classic ESP32";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        inherit (pkgs) lib stdenv;
        onLinux = stdenv.hostPlatform.isLinux;

        # Host deps the ESP-IDF build (fetched + built by esp-idf-sys/embuild on
        # first `cargo build`) needs. IDF itself is NOT pinned here: esp-idf-sys
        # installs the pinned IDF (v5.5) into ~/.espressif, keeping the framework
        # identical to the espup/esp-rs world and always fresh.
        idfBuildDeps = with pkgs; [
          cmake ninja python3 git wget flex bison gperf ccache dfu-util pkg-config libusb1
        ];

        # Fresh Espressif Rust tooling, straight from nixpkgs (nixos-unstable,
        # Aug 2026: espup 0.17, espflash 4.3, ldproxy 0.31). rustup is required —
        # `espup install` registers the Xtensa `esp` toolchain inside rustup and
        # `cargo +esp build` drives it.
        espTools = with pkgs; [ rustup espup espflash ldproxy cargo-generate just ];

        libclang = pkgs.llvmPackages.libclang;

        # Runtime libraries espup's PREBUILT toolchain (rustc/clang for Xtensa)
        # and the IDF tool downloads expect to find via the FHS loader. Only used
        # by the Linux FHS shell.
        prebuiltRuntimeLibs = with pkgs; [
          stdenv.cc.cc.lib
          zlib
          openssl
          libxml2
          ncurses5
        ];

        bootstrapHint = ''
          if [ ! -d "$HOME/.rustup/toolchains/esp" ]; then
            echo ""
            echo "  tutti-leaf — first time here?  Bootstrap the Xtensa Rust toolchain:"
            echo "      just bootstrap"
            echo "  (runs 'espup install' — a one-time PREBUILT download, Apple-Silicon native;"
            echo "   you are NOT compiling a compiler.)"
            echo ""
          fi
          [ -f "$HOME/export-esp.sh" ] && . "$HOME/export-esp.sh"
        '';

        # macOS + non-NixOS Linux: a plain shell. Prebuilt esp binaries run
        # natively on macOS and under nix-ld on generic Linux.
        plainShell = pkgs.mkShell {
          name = "tutti-leaf";
          packages = idfBuildDeps ++ espTools ++ [ pkgs.llvmPackages.clang ];
          LIBCLANG_PATH = "${libclang.lib}/lib";
          shellHook = bootstrapHint + ''
            echo "tutti-leaf dev shell (plain) · target xtensa-esp32-espidf."
          '';
        };

        # NixOS: an FHS sandbox so espup's prebuilt Xtensa toolchain + the IDF
        # tool downloads find a standard loader and their runtime libs. This is
        # the reliable NixOS path; macs use plainShell.
        fhsShell = pkgs.buildFHSEnv {
          name = "tutti-leaf-fhs";
          targetPkgs = _:
            idfBuildDeps ++ espTools ++ prebuiltRuntimeLibs
            ++ [ pkgs.llvmPackages.clang libclang ];
          profile = ''
            export LIBCLANG_PATH="${libclang.lib}/lib"
            ${bootstrapHint}
            echo "tutti-leaf dev shell (FHS/NixOS) · target xtensa-esp32-espidf."
          '';
          runScript = "bash";
        };
      in {
        devShells.default = if onLinux then fhsShell.env else plainShell;
        # Escape hatch: force the plain shell (macs, or Linux with nix-ld).
        devShells.plain = plainShell;

        # The FHS wrapper as a runnable, for non-interactive use (CI, scripts):
        #   nix run .#fhs -- -c 'just build'
        # `nix develop` uses fhsShell.env above; this is the same sandbox, driven
        # by an explicit command instead of an interactive prompt. Linux only —
        # buildFHSEnv does not exist on darwin (macs don't need it).
        packages = lib.optionalAttrs onLinux { fhs = fhsShell; };
        apps = lib.optionalAttrs onLinux {
          fhs = {
            type = "app";
            program = "${fhsShell}/bin/tutti-leaf-fhs";
          };
        };

        formatter = pkgs.nixfmt-classic or pkgs.nixpkgs-fmt;
      });
}
