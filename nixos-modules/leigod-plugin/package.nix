{
  stdenvNoCC,
  fetchurl,
  bash,
  ...
}:

let
  baseUrl = "http://119.3.40.126/";
  binaryName = "acc-gw.router.amd64";
  ipdbName = "ipdatacloud_country.xdb";
in

stdenvNoCC.mkDerivation {
  pname = "leigod";
  version = "1.3.0.01";

  src = ./src;

  dontBuild = true;

  unpackPhase =
    let
      binary = fetchurl {
        url = baseUrl + binaryName;
        hash = "sha256-+B7Gp+GlvO+MuNG/IzFB7OfVQlCIFCLswoFMmN+BniM=";
      };
      ipdb = fetchurl {
        url = baseUrl + ipdbName;
        hash = "sha256-NTYADunrOZdTjLN6FPkNVxl5c0xIsjuNVI7OrBZmYnM=";
      };
    in
    ''
      runHook preUnpack

      mkdir -p src
      cp ${binary} src/$(stripHash ${binary})
      cp ${ipdb} src/$(stripHash ${ipdb})
      cp $src/steamdeck_monitor.sh src/steamdeck_monitor.sh

      runHook postUnpack
    '';

  installPhase = ''
        runHook preInstall

        mkdir -p "$out/bin"
        mkdir -p "$out/libexec/"
        mkdir -p "$out/share/fake"
        mkdir -p "$out/share/config"

        install -m755 \
          "src/steamdeck_monitor.sh" \
          "$out/libexec/steamdeck_monitor.sh"

        substituteInPlace $out/libexec/steamdeck_monitor.sh \
          --replace-fail "/bin/sh" "${bash}/bin/bash"

        install -m755 \
          "src/${binaryName}" \
          "$out/bin/${binaryName}"

        # use same binary as upgrade monitor, which is the same implementation as in the original install script
        cp \
          "$out/bin/${binaryName}" \
          "$out/bin/acc_upgrade_monitor"

        install -m444 \
          "src/ipdatacloud_country.xdb" \
          "$out/share/config/ipdatacloud_country.xdb"

        # simulate steamdeck
        cat > "$out/share/fake/product_name" <<'EOF'
    Jupiter
    EOF

        # simulate steamdeck
        cat > "$out/share/fake/os-release" <<'EOF'
    NAME="SteamOS"
    ID=steamos
    ID_LIKE=arch
    BUILD_ID=20260420.100
    PRETTY_NAME="SteamOS"
    VERSION_ID=3.6
    EOF

        runHook postInstall
  '';

  meta = {
    platforms = [
      "x86_64-linux"
    ];
    license = [
      "mit"
      "unfree" # For the leigod plugin binaries
    ];
  };
}
