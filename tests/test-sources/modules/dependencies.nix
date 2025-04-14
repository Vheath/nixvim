{
  override =
    { pkgs, ... }:
    {
      dependencies.git = {
        enable = true;
        package = pkgs.gitMinimal;
      };
    };

  all =
    {
      lib,
      pkgs,
      options,
      ...
    }:
    {
      dependencies = lib.mapAttrs (_: depOption: {
        enable = lib.meta.availableOn pkgs.stdenv.hostPlatform depOption.package.default;
      }) options.dependencies;
    };

  all-examples =
    {
      lib,
      pkgs,
      options,
      ...
    }:
    {
      dependencies = lib.pipe options.dependencies [
        # We use a literalExpression example, with an additional `path` attr.
        # This means we don't have to convert human readable paths back to list-paths for this test.
        (lib.filterAttrs (_: depOption: depOption.package ? example.path))
        (lib.mapAttrs (
          _: depOption:
          let
            packagePath = depOption.package.example.path;
            packageName = lib.showAttrPath packagePath;
            package = lib.attrByPath packagePath (throw "${packageName} not found in pkgs") pkgs;
          in
          {
            enable = lib.meta.availableOn pkgs.stdenv.hostPlatform package;
            inherit package;
          }
        ))
      ];
    };

  # Integration test for `lib.nixvim.deprecation.mkRemovedPackageOptionModule`
  removed-package-options =
    {
      lib,
      pkgs,
      config,
      ...
    }:
    {
      test = {
        buildNixvim = false;
        warnings = expect: [
          (expect "count" 2)

          (expect "any" "The option `plugins.chatgpt.curlPackage' defined in `")
          (expect "any" "has been replaced by `dependencies.curl.enable' and `dependencies.curl.package'.")

          (expect "any" "The option `plugins.glow.glowPackage' defined in `")
        ];
      };

      plugins.chatgpt.curlPackage = null;
      plugins.glow.glowPackage = pkgs.hello;

      assertions = [
        {
          assertion = !lib.elem pkgs.curl config.extraPackages;
          message = "Expected curl not to be installed.";
        }
        {
          assertion = config.dependencies.glow.enable;
          message = "Expected `dependencies.glow` to be enabled.";
        }
        {
          assertion = lib.elem pkgs.hello config.extraPackages;
          message = "Expected hello to be installed.";
        }
        {
          assertion = !lib.elem pkgs.glow config.extraPackages;
          message = "Expected glow not to be installed.";
        }
      ];
    };
}
