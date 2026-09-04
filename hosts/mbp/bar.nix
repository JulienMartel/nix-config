# Two bars: the menu bar, and a second one along the bottom.
{
  haus.bar = {
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
    logo.updateCheck = true;

    # Naming a pill here MOVES it off the menu bar. Weather, focus, battery and
    # the clock are left out so they stay up top.
    bottom = {
      enable = true;
      items = {
        agents = "left";
        aiUsage = "left";
        github = "left";

        media = "center";

        cpu = "right";
        memory = "right";
        elgato = "right";
        caffeinate = "right";
      };
    };
  };
}
