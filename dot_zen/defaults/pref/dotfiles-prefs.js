// Zen defaults shared across machines. Deployed to
// /opt/zen-browser-bin/defaults/pref/ by run_onchange_after_deploy-zen-policies,
// where Zen loads every .js as default prefs (like its own channel-prefs.js).
// Defaults only: a value changed in the browser wins and stays per profile.
// Copied from the workstation profile; refresh with the values from prefs.js.

// Toolbar layout: extension buttons (1Password, uBlock) pinned in the nav bar,
// compact-mode toggle on top of the sidebar, library/workspaces/new at the foot
pref("browser.uiCustomization.state", "{\"placements\":{\"widget-overflow-fixed-list\":[],\"unified-extensions-area\":[],\"nav-bar\":[\"back-button\",\"forward-button\",\"stop-reload-button\",\"customizableui-special-spring1\",\"vertical-spacer\",\"urlbar-container\",\"customizableui-special-spring2\",\"unified-extensions-button\",\"_d634138d-c276-4fc8-924b-40a0ea21d284_-browser-action\",\"ublock0_raymondhill_net-browser-action\",\"reset-pbm-toolbar-button\",\"_446900e4-71c2-419f-a6a7-df9c091e268b_-browser-action\"],\"toolbar-menubar\":[\"menubar-items\"],\"TabsToolbar\":[\"tabbrowser-tabs\",\"smartwindow-group-tabs-button\",\"ai-window-toggle\",\"zen-media-controls-toolbar\",\"customizableui-special-spring3\"],\"vertical-tabs\":[],\"PersonalToolbar\":[\"import-button\",\"personal-bookmarks\"],\"zen-sidebar-top-buttons\":[\"zen-toggle-compact-mode\"],\"zen-sidebar-foot-buttons\":[\"zen-library-button\",\"zen-workspaces-button\",\"zen-create-new-button\"]},\"seen\":[\"developer-button\",\"ublock0_raymondhill_net-browser-action\",\"screenshot-button\",\"_d634138d-c276-4fc8-924b-40a0ea21d284_-browser-action\",\"reset-pbm-toolbar-button\",\"_446900e4-71c2-419f-a6a7-df9c091e268b_-browser-action\",\"ai-window-toggle\",\"smartwindow-group-tabs-button\"],\"dirtyAreaCache\":[\"nav-bar\",\"vertical-tabs\",\"zen-sidebar-foot-buttons\",\"PersonalToolbar\",\"unified-extensions-area\",\"toolbar-menubar\",\"TabsToolbar\",\"zen-sidebar-top-buttons\"],\"currentVersion\":28,\"newElementCount\":3}");

// Collapsed left bar, separate top toolbar, no Firefox sidebar launcher
pref("zen.view.sidebar-expanded", false);
pref("zen.view.use-single-toolbar", false);
pref("sidebar.visibility", "hide-launcher");

pref("zen.workspaces.continue-where-left-off", true);
pref("browser.translations.neverTranslateLanguages", "et,ru,de");
pref("browser.startup.homepage", "about:blank");
pref("privacy.clearOnShutdown_v2.formdata", true);
