{
  stdenvNoCC,
  fetchurl,
  udevCheckHook,
}:
stdenvNoCC.mkDerivation {
  pname = "game-devices-udev-rules";
  version = "1.0";

  src = ./.;

  nativeBuildInputs = [
    udevCheckHook
  ];

  unpackPhase =
    let
      rules = fetchurl {
        url = "https://probe.rs/files/69-probe-rs.rules";
        hash = "sha256-CfLqWaVzR2h2ZxhN/NETb2Zj38D/3BHrjrjZjzHatF0=";
      };
    in
    ''
      mkdir -p src
      cp ${rules} src/$(stripHash ${rules})
    '';

  doInstallCheck = true;

  postInstall = ''
    install -Dm444 -t "$out/lib/udev/rules.d" src/*.rules
  '';

  meta = {
    description = "Udev rules for probe-rs, a modern, embedded debugging toolkit";
    platform = [
      "aarch64-linux"
      "i686-linux"
      "x86_64-linux"
    ];
    license = "unfree";
  };
}
