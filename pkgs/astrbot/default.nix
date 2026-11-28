{
  lib,
  pkgs,
  stdenvNoCC,
  fetchFromGitHub,
  fetchPnpmDeps,
  nodejs,
  pnpm_12,
  pnpmConfigHook,
  python312,
  makeWrapper,
  cacert,
  uv,
  git,
  ripgrep,
  ffmpeg,
  pyproject-nix,
  uv2nix,
  pyproject-build-systems,
}:

let
  version = "4.29.4";
  pnpm = pnpm_12;

  source = fetchFromGitHub {
    owner = "AstrBotDevs";
    repo = "AstrBot";
    rev = "61335414433db721b3f7ecc93f90deafe0a59d78";
    hash = "sha256-fuHL0HNOFp47yxsaX1OR4KJLhQ8MQrdQlFTkYYqR6oo=";
  };

  dashboard = stdenvNoCC.mkDerivation (finalAttrs: {
    pname = "astrbot-dashboard";
    inherit version;
    src = "${source}/dashboard";

    pnpmDeps = fetchPnpmDeps {
      inherit (finalAttrs) pname version src;
      inherit pnpm;
      fetcherVersion = 5;
      hash = "sha256-M2PD+tFf95tuXeGUrGTR3DyZTkdx5xsmGuJsfT/nUnw=";
    };

    nativeBuildInputs = [
      nodejs
      pnpmConfigHook
      pnpm
    ];

    # The font download plugin requires network access during the build. The
    # generated page keeps the original Google Fonts link and resolves it in
    # the browser instead.
    postPatch = ''
      substituteInPlace vite.config.ts \
        --replace-fail "import webfontDl from 'vite-plugin-webfont-dl';" "" \
        --replace-fail "webfontDl()" ""
    '';

    buildPhase = ''
      runHook preBuild

      pnpm run build
      mkdir -p dist/assets
      printf '%s\n' "v${version}" > dist/assets/version

      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall

      mkdir -p "$out"
      cp -r dist/. "$out"/

      runHook postInstall
    '';
  });

  astrbotSource = stdenvNoCC.mkDerivation {
    pname = "astrbot-source";
    inherit version;
    src = source;

    dontBuild = true;

    postPatch = ''
      substituteInPlace astrbot/core/utils/pip_installer.py \
        --replace-fail \
          $'        target_site_packages = None\n        if is_packaged_desktop_runtime():\n            target_site_packages = get_astrbot_site_packages_path()' \
          '        if target_site_packages := get_astrbot_site_packages_path():' \
        --replace-fail \
          $'        if not is_packaged_desktop_runtime():\n            return\n\n        target_site_packages = get_astrbot_site_packages_path()' \
          '        target_site_packages = get_astrbot_site_packages_path()'

      substituteInPlace astrbot/core/utils/requirements_utils.py \
        --replace-fail \
          $'    if is_packaged_desktop_runtime():\n        target_site_packages = get_astrbot_site_packages_path()\n        if os.path.isdir(target_site_packages):\n            paths.insert(0, target_site_packages)' \
          $'    target_site_packages = get_astrbot_site_packages_path()\n    if os.path.isdir(target_site_packages):\n        paths.insert(0, target_site_packages)'
    '';

    installPhase = ''
      runHook preInstall

      mkdir -p "$out"
      cp -r ./. "$out"/
      chmod -R u+w "$out"
      rm -rf "$out/astrbot/dashboard/dist"
      mkdir -p "$out/astrbot/dashboard"
      cp -r ${dashboard} "$out/astrbot/dashboard/dist"

      runHook postInstall
    '';
  };

  workspace = uv2nix.lib.workspace.loadWorkspace {
    workspaceRoot = source;
    uvLock = lib.importTOML ./uv.lock;
  };

  pythonSet = (pkgs.callPackage pyproject-nix.build.packages { python = python312; }).overrideScope
    (lib.composeManyExtensions [
      pyproject-build-systems.overlays.wheel
      (workspace.mkPyprojectOverlay { sourcePreference = "wheel"; })
      (final: prev: {
        astrbot = prev.astrbot.overrideAttrs (_old: {
          src = astrbotSource;
        });

        aiocqhttp = prev.aiocqhttp.overrideAttrs (old: {
          nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ final.setuptools ];
        });

        jieba = prev.jieba.overrideAttrs (old: {
          nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ final.setuptools ];
        });
      })
    ]);

  pythonEnv = pythonSet.mkVirtualEnv "astrbot-env" workspace.deps.default;

  pluginPip = pkgs.writeShellScript "astrbot-pip" ''
    export PIP_TARGET="''${ASTRBOT_ROOT:-$PWD}/data/site-packages"
    export SSL_CERT_FILE="${cacert}/etc/ssl/certs/ca-bundle.crt"
    export PYTHONDONTWRITEBYTECODE=1
    exec "${pythonEnv}/bin/python" -P -m pip "$@"
  '';

  runtimeTools = [
    uv
    nodejs
    pnpm
    git
    ripgrep
    ffmpeg
  ];
in
stdenvNoCC.mkDerivation {
  pname = "astrbot";
  inherit version;

  dontUnpack = true;
  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/bin"
    ln -s ${pluginPip} "$out/bin/astrbot-pip"
    makeWrapper "${pythonEnv}/bin/python" "$out/bin/astrbot" \
      --add-flags "-P -m astrbot.cli" \
      --prefix PATH : "${lib.makeBinPath runtimeTools}" \
      --set UV_PYTHON "${pythonEnv}/bin/python" \
      --set UV_PYTHON_DOWNLOADS "never" \
      --set SSL_CERT_FILE "${cacert}/etc/ssl/certs/ca-bundle.crt" \
      --set NODE_EXTRA_CA_CERTS "${cacert}/etc/ssl/certs/ca-bundle.crt" \
      --set PYTHONDONTWRITEBYTECODE 1

    runHook postInstall
  '';

  meta = {
    description = "Easy-to-use multi-platform LLM chatbot and development framework";
    homepage = "https://github.com/AstrBotDevs/AstrBot";
    license = lib.licenses.agpl3Plus;
    mainProgram = "astrbot";
    platforms = lib.platforms.linux;
  };
}
