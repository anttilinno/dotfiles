// Points Zen at dotfiles.cfg (deployed to /opt/zen-browser-bin). Plain pref()
// files here load before Zen's own defaults, so Zen's zen.* defaults would win;
// autoconfig runs after all defaults, so its defaultPref() calls stick.
pref("general.config.filename", "dotfiles.cfg");
pref("general.config.obscure_value", 0);
