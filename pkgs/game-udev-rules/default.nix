{
  stdenvNoCC,
  fetchFromCodeberg,
  udevCheckHook,
  bash,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "game-devices-udev-rules";
  version = "1.0";

  src = fetchFromCodeberg {
    owner = "fabiscafe";
    repo = "game-devices-udev";
    tag = finalAttrs.version;
    hash = "sha256-J4LfRifTqBM+B/dryLHERaVa1UUWEbfjEUj+exCFVsU=";
  };

  nativeBuildInputs = [
    udevCheckHook
  ];

  doInstallCheck = true;

  postInstall = ''
    install -Dm444 -t "$out/lib/udev/rules.d" src/*.rules
    substituteInPlace $out/lib/udev/rules.d/powera-gdu.rules \
      --replace-fail "/bin/sh" "${bash}/bin/bash"
    for rule in $out/lib/udev/rules.d/*.rules; do
      replaced=$(echo $rule | sed "s@^$out/lib/udev/rules.d/@71-@")
      echo $replaced
      mv $rule $out/lib/udev/rules.d/$replaced
    done
  '';

  meta = {
    description = "Udev rules to make supported controllers available with user-grade permissions, priority added";
    platform = [
      "aarch64-linux"
      "i686-linux"
      "x86_64-linux"
    ];
    license = "mit";
  };
})
