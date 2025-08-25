{
  buildCatppuccinPort,
  fetchYarnDeps,
  sources,
  yarnConfigHook,
  yarnBuildHook,
  nodejs,
  jq,
}:
buildCatppuccinPort {
  port = "firefox";

  patches = [
    ./write-themes-to-json.patch
  ];

  yarnOfflineCache = fetchYarnDeps {
    yarnLock = sources.firefox + /yarn.lock;
    hash = "sha256-EWx1/kujC6HBSJr6d4sTlFwANbZqBQ3FHetHcbMtiVU=";
  };

  yarnBuildScript = "generate";

  installPhase = ''
    set -euo pipefail
    mkdir -p $out

    jq -s '
      def deepmerge(a; b):
        if (a|type)=="object" and (b|type)=="object" then
          reduce ((a|keys_unsorted) + (b|keys_unsorted) | unique)[] as $k
            ({}; .[$k] = deepmerge(a[$k]; b[$k]))
        elif (a|type)=="array" and (b|type)=="array" then
          (a + b) | unique
        else
          b // a
        end;

      .[0] as $base | .[1] as $patch
      | $base
      | .mocha = deepmerge(.mocha // {}; $patch.mocha // {})
    ' themes.json ${./custom-theme.json} > "$out/themes.json"
  '';

  nativeBuildInputs = [
    yarnConfigHook
    yarnBuildHook
    nodejs
    jq
  ];
}
