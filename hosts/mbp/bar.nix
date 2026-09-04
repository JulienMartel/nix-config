# Two bars: the menu bar up top, a second one along the bottom.
{
  haus.bar = {
    # Which pills exist. `bottom.items` below decides where each one is drawn;
    # anything switched on here but not named there stays on the menu bar.
    # Off on purpose: volume and harvest, and wifi (the menu bar already says it).
    items = {
      agents = true;
      aiUsage = true;
      caffeinate = true;
      calendar = true;
      cpu = true;
      elgato = true;
      github = true;
      memory = true;
      trill = true;
      wifi = false;
    };

    battery.hideOver = 80;
    clock.mode = "compact";
    # This machine tracks the layer, so the "haus update" nag is wanted.
    logo.updateCheck = true;

    bottom = {
      enable = true;
      items = {
        # Left is "what is my work doing", start to finish: which panes are
        # busy, what they have spent, what has landed.
        agents = "left";
        aiUsage = "left";
        github = "left";

        media = "center";

        # Right is this machine's own vitals and switches. Weather and focus are
        # deliberately unnamed here, which is what keeps them in the menu bar's
        # always-visible right corner.
        cpu = "right";
        memory = "right";
        elgato = "right";
        caffeinate = "right";
      };
    };
  };
}
