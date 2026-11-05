# Fragments Overview

## Purpose

`modules/fragments` holds class-neutral module fragments.

Fragments declare options, helpers, or config logic that is shared by more than one module class, such as NixOS and Home Manager.
A class-specific wrapper imports the fragments it needs.

## Entry Point

- **Directory**: [`modules/fragments`](../../../../modules/fragments)

### Current fragments

- [`ai`](../../../../modules/fragments/ai/default.nix) — AI fragment aggregator imported once by each class root module.
- [`ai/models`](../../../../modules/fragments/ai/models/default.nix) — model-chain option factory.
  - [`lib.nix`](../../../../modules/fragments/ai/models/lib.nix) — chain resolution and provider helpers.
- [`ai/providers.nix`](../../../../modules/fragments/ai/providers.nix) — provider registry.
  Provider names default to the repository provider id and settings default to `{ }`.
  Providers also declare service-specific secret references, such as `mnemosyne` or `homeManager`.
  Providers only declare overrides, such as Zed naming or settings.
- [`ai/aliases.nix`](../../../../modules/fragments/ai/aliases.nix) — workload aliases for non-agentic consumers.
  `ai.aliases.singleTurn` is a single-request alias used by tools such as `jj-desc`; it is separate from the agentic fallback chains.

## Architecture / Services / Scope

Fragments are imported explicitly by class wrappers, which are themselves imported by the class-specific modules.

Those wrappers are responsible for providing the correct `optionPath` to the fragment factory, which emits options under that path.
The AI model fragment is emitted at root `ai.models` because its use is not limited to the agent service.

Importing a fragment:

```nix
(import "${self}/modules/fragments/ai/models/default.nix" {
  optionPath = [
    "ai"
    "models"
  ];
})
```

### Rules

- Do not place NixOS-only or Home-Manager-only options in `modules/fragments`.
- Do not auto-import fragments globally.
- Do not export fragments as `flake.nixosModules` or `flake.homeManagerModules`.
- Consumers choose the option path through the fragment factory.
