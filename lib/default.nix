{ ... }@lib:

import ./attrsets.nix { inherit lib; } //
import ./hardware.nix { inherit lib; }
