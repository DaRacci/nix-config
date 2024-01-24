# Using a Nix Package or NixOS Module from a Separate Fork of Nixpkgs

This guide will show you how to use a Nix package or NixOS module from a separate fork of nixpkgs.

## Step 1: Define the Forked Repository

In your Nix file, define the forked repository using `fetchFromGitHub` function:

```nix
nixpkgs.overlays = [
  (self: super: {
    <your-package> = (import
      (pkgs.fetchzip (
        let owner = "<owner>"; branch = "<branch>"; in {
          url = "https://github.com/${owner}/nixpkgs/archive/${branch}.tar.gz";
          # Change to 52 zeros when archive needs to be redownloaded.
          sha256 = "<sha256>";
        }
      ))
      { overlays = [ ]; config = super.config; }).<your-package>;
  })
];
in
```

In this example, replace `<your-package>`, `<owner>`, `<branch>`, and `<sha256>` with the actual values from the forked repository.

## Step 2: Use Packages or Modules from the Forked Repository

Now you can use packages or modules from the forked repository in your Nix expressions. For example, if you want to use a package from the forked repository, you can refer to it using the `<your-package>` attribute. Here's an example:

```nix
{
  environment.systemPackages = with pkgs; [
    <your-pckage>
  ];
}
```

In this example, replace `<your-package` with the actual name of the package you want to use.
