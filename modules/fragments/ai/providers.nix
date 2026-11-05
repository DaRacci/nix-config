{
  openrouter = {
    baseUrl = "https://openrouter.ai/api/v1";

    secrets = {
      default = "AI_AGENT/OPENROUTER_API_KEY";
      mnemosyne = "AI_AGENT/MNEMOSYNE_OPENROUTER_API_KEY";
      homeManager = "OPENROUTER_API_KEY";
    };
  };

  opencode-go = {
    baseUrl = "https://opencode.ai/zen/go/v1";

    secrets = {
      default = "AI_AGENT/OPENCODE_GO_API_KEY";
      homeManager = "OPENCODE_GO_API_KEY";
    };

    services.zed = {
      name = "opencode";
      settings = {
        show_go_models = true;
        show_zen_models = false;
      };
    };
  };
}
