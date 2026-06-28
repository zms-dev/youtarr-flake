{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  nix-update-script,
}:

buildNpmPackage rec {
  pname = "youtarr-client";
  version = "1.72.1";

  src = fetchFromGitHub {
    owner = "DialmasterOrg";
    repo = "Youtarr";
    rev = "v${version}";
    hash = "sha256-8OvOb2CCMJqPDhsxyBaPcg8VWujTmd80CWt+HFwLj1o=";
  };

  sourceRoot = "source/client";

  # Nix needs the hash of the npm dependencies.
  # We set this to fakeHash initially so Nix can calculate and print the correct one.
  npmDepsHash = "sha256-BYJy0irko9TPZ1NOGTXQcTrpVycz0qU8g6S3j1qREmg=";

  # Disable running checkPhase (tests) since we only want to build the production bundle
  doCheck = false;

  # Vite build puts compiled production assets in the 'build' directory.
  # We copy this built static folder to the output directory.
  installPhase = ''
    runHook preInstall
    mkdir -p $out
    cp -r build/* $out/
    runHook postInstall
  '';

  passthru.updateScript = nix-update-script;
}
