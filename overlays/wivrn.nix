_: prev: {
  wivrn = prev.wivrn.overrideAttrs (finalAttrs: {
    version = "26.9";
    src = prev.fetchFromGitHub {
      owner = "wivrn";
      repo = "wivrn";
      rev = "v26.9";
      hash = "sha256-/kXgbku/4EeYY5YTwtY71csgxOP8bRACLqOvKXolg5g=";
    };
    monado = prev.applyPatches {
      src = prev.fetchFromGitLab {
        domain = "gitlab.freedesktop.org";
        owner = "monado";
        repo = "monado";
        rev = "f037264d23e2472a444a157370647fcd601ed81b";
        hash = "sha256-exHbecudAy57szL7kut7/fBYCoekEs3riZzhMtFWS/c=";
      };
      postPatch = ''
        ${finalAttrs.src}/patches/apply.sh ${finalAttrs.src}/patches/monado/*
      '';
    };
  });
}
