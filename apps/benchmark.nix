{pkgs}: let
  benchmarkScript = pkgs.writeShellApplication {
    name = "benchmark";
    runtimeInputs = [
      pkgs.phoronix-test-suite
      pkgs.p7zip
      pkgs.libaio
      pkgs.openssl
      pkgs.zlib
      pkgs.gcc
    ];
    text = ''
      # Phoronix checks for headers at hardcoded /usr/include paths which don't
      # exist in the Nix store. NO_EXTERNAL_DEPENDENCIES=1 skips that pre-flight
      # check. C_INCLUDE_PATH/LIBRARY_PATH let gcc find headers+libs at compile time;
      # LD_LIBRARY_PATH lets the dynamic linker find them at runtime.
      export NO_EXTERNAL_DEPENDENCIES=1
      export C_INCLUDE_PATH="${pkgs.libaio}/include:${pkgs.openssl.dev}/include:${pkgs.zlib.dev}/include''${C_INCLUDE_PATH:+:$C_INCLUDE_PATH}"
      export LIBRARY_PATH="${pkgs.libaio}/lib:${pkgs.openssl.out}/lib:${pkgs.zlib}/lib''${LIBRARY_PATH:+:$LIBRARY_PATH}"
      export LD_LIBRARY_PATH="${pkgs.libaio}/lib:${pkgs.openssl.out}/lib:${pkgs.zlib}/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
      phoronix-test-suite run pts/compress-7zip pts/ramspeed pts/fio pts/blake2 pts/openssl
    '';
  };
in {
  benchmark = {
    type = "app";
    program = "${benchmarkScript}/bin/benchmark";
  };
}
