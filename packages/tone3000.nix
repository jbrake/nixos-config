{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  copyDesktopItems,
  makeDesktopItem,
  wrapGAppsHook3,
  alsa-lib,
  curl,
  fontconfig,
  freetype,
  glib-networking,
  gtk3,
  libx11,
  webkitgtk_4_1,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "tone3000";
  version = "0.0.5";

  src = fetchurl {
    url = "https://github.com/tone-3000/tone3000-plugin/releases/download/v${finalAttrs.version}/TONE3000-v${finalAttrs.version}-linux-x64.tar.gz";
    hash = "sha256-Hqe0PrLZrPXjsLsdXS+yqWzDM+uYkWBlJ0jncb3hAB4=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    copyDesktopItems
    wrapGAppsHook3
  ];

  buildInputs = [
    alsa-lib
    fontconfig
    freetype
    glib-networking
    libx11
    stdenv.cc.cc.lib
  ];

  # JUCE loads these at runtime instead of recording them as ELF dependencies.
  # Put them in the standalone executable's RUNPATH so its web UI and model
  # downloads work on NixOS.
  runtimeDependencies = map lib.getLib [
    curl
    gtk3
    webkitgtk_4_1
  ];

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 TONE3000 $out/bin/tone3000
    install -Dm644 tone3000.png \
      $out/share/icons/hicolor/512x512/apps/tone3000.png
    install -Dm644 factory-presets/*.t3kpreset \
      -t $out/share/tone3000/factory-presets

    runHook postInstall
  '';

  desktopItems = [
    (makeDesktopItem {
      name = "tone3000";
      desktopName = "TONE3000";
      comment = "Load and play Neural Amp Modeler captures";
      exec = "tone3000";
      icon = "tone3000";
      categories = [
        "Audio"
        "AudioVideo"
      ];
    })
  ];

  meta = {
    description = "NAM capture and impulse-response player";
    homepage = "https://www.tone3000.com/plugin";
    license = lib.licenses.mit;
    mainProgram = "tone3000";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
})
