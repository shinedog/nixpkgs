{ nixpkgs
, officialRelease
, pkgs ? import nixpkgs.outPath {}
, nix ? pkgs.nix
, lib-tests ? import ../../lib/tests/release.nix { inherit pkgs; }
}:

pkgs.releaseTools.sourceTarball {
  name = "nixpkgs-tarball";
  src = nixpkgs;

  inherit officialRelease;
  version = pkgs.lib.fileContents ../../.version;
  versionSuffix = "pre${
    if nixpkgs ? lastModified
    then builtins.substring 0 8 (nixpkgs.lastModifiedDate or nixpkgs.lastModified)
    else toString (nixpkgs.revCount or 0)}.${nixpkgs.shortRev or "dirty"}";

  buildInputs = with pkgs; [ nix.out jq lib-tests brotli ];

  configurePhase = ''
    eval "$preConfigure"
    releaseName=nixpkgs-$VERSION$VERSION_SUFFIX
    echo -n $VERSION_SUFFIX > .version-suffix
    echo -n ${nixpkgs.rev or nixpkgs.shortRev or "dirty"} > .git-revision
    echo "release name is $releaseName"
    echo "git-revision is $(cat .git-revision)"
  '';

  dontUnpack = true;

  dontBuild = false;

  doCheck = true;

  checkPhase = ''
    echo "generating packages.json"

    (
      echo -n '{"version":2,"packages":'
      NIX_STATE_DIR=$TMPDIR NIX_PATH= nix-env -f $src -qa --meta --json --show-trace --arg config 'import ${./packages-config.nix}'
      echo -n '}'
    ) | sed "s|$src/||g" | jq -c > packages.json

    # Arbitrary number. The index has ~115k packages as of April 2024.
    if [ $(jq -r '.packages | length' < packages.json) -lt 100000 ]; then
      echo "ERROR: not enough packages in the search index, bailing out!"
      exit 1
    fi

    packages=$out/packages.json.br

    mkdir -p $out/nix-support
    brotli -9 < packages.json > $packages
    echo "file json-br $packages" >> $out/nix-support/hydra-build-products
  '';

  distPhase = ''
    mkdir -p $out/tarballs
    XZ_OPT="-T0" tar \
      --absolute-names \
      --transform="s|^$src|$releaseName|g" \
      --transform="s|^$(pwd)|$releaseName|g" \
      --create \
      --xz \
      --file=$out/tarballs/$releaseName.tar.xz \
      $src $(pwd)/{.version-suffix,.git-revision}
  '';
}
