{
  lib,
  stdenv,
  fetchurl,
  makeBinaryWrapper,
  autoPatchelfHook,
  procps,
  ripgrep,
  bubblewrap,
  socat,
  callPackage,
  binName ? "claude",
}: let
  version = "2.1.211";

  platformMap = {
    "aarch64-darwin" = "darwin-arm64";
    "x86_64-darwin" = "darwin-x64";
    "x86_64-linux" = "linux-x64";
    "aarch64-linux" = "linux-arm64";
  };

  platform =
    platformMap.${stdenv.hostPlatform.system}
      or (throw "claude-code: unsupported platform ${stdenv.hostPlatform.system}");

  nativeHashes = {
    "darwin-arm64" = "0a9671rrg23x22izf211ijs7fjxlp91zznvw7izwlvlb35v8lwjs";
    "darwin-x64" = "192x4dbqflrjdmp09zgp75jygikz0zn43nky5fcjnw7l9jqrw11k";
    "linux-x64" = "1cj64k3mlcqr9d43xbfmnr7dri3xgry9z6zi6nya37mcfjjchwl2";
    "linux-arm64" = "0rzq4i3brbfq621bbfakc99yjiz5nwaggyxi22fv21vwjj7pxzqz";
  };

  nativeBinary = fetchurl {
    urls = [
      "https://downloads.claude.ai/claude-code-releases/${version}/${platform}/claude"
      "https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases/${version}/${platform}/claude"
    ];
    sha256 = nativeHashes.${platform};
  };

  updater = callPackage ./update.nix {};
in
  stdenv.mkDerivation {
    pname = "claude-code";
    inherit version;

    dontUnpack = true;
    dontStrip = true;

    nativeBuildInputs =
      [
        makeBinaryWrapper
      ]
      ++ lib.optionals stdenv.hostPlatform.isElf [autoPatchelfHook];

    installPhase = ''
      runHook preInstall
      mkdir -p $out/bin
      install -m755 ${nativeBinary} $out/bin/.claude-unwrapped
      makeBinaryWrapper $out/bin/.claude-unwrapped $out/bin/${binName} \
        --inherit-argv0 \
        --set DISABLE_AUTOUPDATER 1 \
        --set DISABLE_INSTALLATION_CHECKS 1 \
        --set USE_BUILTIN_RIPGREP 0 \
        --prefix PATH : ${
        lib.makeBinPath (
          [
            procps
            ripgrep
          ]
          ++ lib.optionals stdenv.hostPlatform.isLinux [
            bubblewrap
            socat
          ]
        )
      }
      runHook postInstall
    '';

    passthru = {
      inherit updater;
    };

    meta = {
      description = "Claude Code — AI coding assistant in your terminal";
      homepage = "https://www.anthropic.com/claude-code";
      license = lib.licenses.unfree;
      platforms = [
        "aarch64-darwin"
        "x86_64-darwin"
        "x86_64-linux"
        "aarch64-linux"
      ];
      mainProgram = binName;
    };
  }
