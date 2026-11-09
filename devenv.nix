{
  pkgs,
  lib,
  config,
  inputs,
  ...
}:

{
  env.PYTHONPYCACHEPREFIX = "${config.devenv.state}/.pycache";  # Put bytecode files in a single folder
  process.proxy.enable = true;

  overlays = [
    (final: prev: {
      nextflow = inputs.nextflow-pin.legacyPackages.${prev.system}.nextflow.overrideAttrs (oldAttrs: {
        system = prev.stdenv.system;
        postPatch = ''
          substituteInPlace modules/nextflow/src/main/groovy/nextflow/executor/BashWrapperBuilder.groovy \
            --replace-fail "['/bin/bash'," "['${prev.bash}/bin/bash'," \
            --replace-fail "if( containerBuilder ) {" "if( containerBuilder ) {
                      launcher = launcher.replaceFirst(\"/nix/store/.*/bin/bash\", \"/bin/bash\")"
        '';
      });
    })
  ];

  # https://devenv.sh/packages/
  packages = with pkgs; [
    docker-client
    file
    git
    nextflow
  ];

  # https://devenv.sh/languages/
  languages.python = {
    enable = true;
    version = "3.14";
    uv.enable = true;
  };

  outputs = {
    sapporo-service = config.languages.python.import ./. {};
    run-irida-next = pkgs.stdenv.mkDerivation {
      name = "run-irida-next";
      src = ./.;
      installPhase = ''
        mkdir -p $out/bin
        cp sapporo/run_irida_next.sh $out/bin/run.sh
        chmod +x $out/bin/run.sh
      '';
    };
  };

  # https://devenv.sh/processes/
  processes.sapporo = {
    exec = "${config.outputs.sapporo-service}/bin/sapporo";
    ports.http.allocate = 1122;
    env.PYTHONPATH = "${config.outputs.sapporo-service}/src:${config.outputs.sapporo-service}/lib";
    env.SKIP_CHOWN_OUTPUTS = "True";
    env.SAPPORO_HOST = "0.0.0.0";
    env.SAPPORO_PORT = builtins.toString config.processes.sapporo.ports.http.value;
    env.SAPPORO_DEBUG = "True";
    env.SAPPORO_RUN_SH = "${config.outputs.run-irida-next}/bin/run.sh";
    env.SAPPORO_RUN_DIR = "${config.devenv.state}/sapporo-runs";
  };

  # https://devenv.sh/services/
  # services.postgres.enable = true;

  # https://devenv.sh/basics/
  #enterShell = ''
  #  uv sync --directory ${config.git.root}
  #'';

  # https://devenv.sh/tasks/
  tasks."sapporo:setup-data" = {
    exec = ''
      mkdir -p sapporo-runs/.nextflow
      printf "docker {\n\tenabled = true\n\trunOptions = '--network host'\n}" > sapporo-runs/.nextflow/config
    '';
    cwd = "${config.devenv.state}";
    before = [ "devenv:processes:sapporo" ];
  };

  # https://devenv.sh/tests/
  #enterTest = ''
  #  echo "Running tests"
  #  uv run pytest
  #'';

  # See full reference at https://devenv.sh/reference/options/
}
