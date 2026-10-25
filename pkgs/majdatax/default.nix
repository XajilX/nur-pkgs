{
  lib,
  stdenv,
  fetchzip,
  gtk3,
  zlib,
  alsa-lib,
  dbus,
  libGL,
  libxcursor,
  libxext,
  libxi,
  libxinerama,
  libxkbcommon,
  libxrandr,
  libxscrnsaver,
  libxxf86vm,
  udev,
  vulkan-loader,
  wayland,
  dotnet-runtime_10,
  fontconfig,
  libx11,
  libsm,
  libice,
  ffmpeg,
  writeShellScript,
  makeWrapper,
  imagemagick,
  bubblewrap,
  makeDesktopItem,
  avaloniaDeps ? [
    fontconfig.lib
    libx11
    libsm
    libice
  ],
  unityDeps ? [
    alsa-lib
    gtk3
    (lib.getLib stdenv.cc.cc)
    zlib
    dbus
    libGL
    libxcursor
    libxext
    libxi
    libxinerama
    libxkbcommon
    libxrandr
    libxscrnsaver
    libxxf86vm
    udev
    vulkan-loader
    wayland
  ],
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "MajdataX";
  version = "6.2.0-linux-x64-video-patched";

  src = fetchzip {
    url = "https://github.com/XajilX/MajdataViewX/releases/download/v${finalAttrs.version}/MajdataX-v${finalAttrs.version}.zip";
    hash = "sha256-y38gSrDeYObh3BvKW3eDPbcYmDZFLWDIwrQGtd7CjEA=";
  };

  nativeBuildInputs = [
    imagemagick
    makeWrapper
  ];

  buildInputs = [
    dotnet-runtime_10
    ffmpeg
  ]
  ++ unityDeps
  ++ avaloniaDeps;

  dontBuild = true;
  dontStrip = true;
  dontPatchELF = true;

  desktopItem = makeDesktopItem {
    name = "MajdataEdit-Neo";
    desktopName = "MajdataEdit Neo";
    comment = finalAttrs.meta.description;
    icon = "majdatax";
    exec = "MajdataEdit-Neo";
    categories = [
      "Game"
      "Graphics"
    ];
  };

  installPhase =
    let
      writables = [
        "Settings.json"
        "crash.log"
        "editor.db"
        "completions.json"
        ".autosave"
      ];
      setup = writeShellScript "majdatax-user-setup" ''
        MAJDATAX_DATA_DIR="''${XDG_DATA_HOME:-$HOME/.local/share}/MajdataX"
        mkdir -p $MAJDATAX_DATA_DIR

        for file in ${lib.escapeShellArgs writables}; do
          if [ ! -e "$MAJDATAX_DATA_DIR/$file" ]; then
            cp -r "$APP_PATH/$file" "$MAJDATAX_DATA_DIR/$file"
            chmod u+w "$MAJDATAX_DATA_DIR/$file"
          fi
        done
      '';
      bindArgs = lib.concatMapStringsSep " " (
        file: ''--bind "$MAJDATAX_DATA_DIR/${file}" "$APP_PATH/${file}"''
      ) writables;
    in
    ''
      runHook preInstall

      mkdir -p "$out/libexec/MajdataX"
      cp -r $src/* "$out/libexec/MajdataX/"
      touch "$out/libexec/MajdataX/crash.log"
      touch "$out/libexec/MajdataX/completions.json"
      mkdir -p "$out/libexec/MajdataX/.autosave"

      mkdir -p "$out/share"
      install -Dm644 "$desktopItem/share/applications/MajdataEdit-Neo.desktop" "$out/share/applications/MajdataEdit-Neo.desktop"
      for i in 16 24 48 64 96 128 256 512; do
        mkdir -p $out/share/icons/hicolor/''${i}x''${i}/apps
        magick $src/salt.png -background none -resize ''${i}x''${i} $out/share/icons/hicolor/''${i}x''${i}/apps/majdatax.png
      done

      mkdir -p "$out/bin"
      makeWrapper "$out/libexec/MajdataX/MajdataViewX" "$out/bin/MajdataViewX" \
        --set LD_LIBRARY_PATH "${lib.makeLibraryPath unityDeps}"
      makeWrapper "${lib.getExe bubblewrap}" "$out/bin/MajdataEdit-Neo" \
        --set APP_PATH "$out/libexec/MajdataX" \
        --set DOTNET_ROOT "${dotnet-runtime_10}/share/dotnet" \
        --set LD_LIBRARY_PATH "${lib.makeLibraryPath (avaloniaDeps ++ unityDeps)}" \
        --run 'source ${setup}' \
        --add-flags '--bind / / \
          --dev-bind /dev /dev \
          ${bindArgs} \
          -- "$APP_PATH/MajdataEdit-Neo"
        '

      runHook postInstall
    '';

  meta = {
    description = "Next-Next-Next-generation Simai: Note designer for maimai.";
    mainProgram = "MajdataEdit-Neo";
    homepage = "https://github.com/re-poem/MajdataViewX";
    platforms = [
      "x86_64-linux"
    ];
    license = [
      "mit"
      "unfree" # as it uses libbass
    ];
  };

})
