(deflayer window_navigation
  _     _     _     _     _     _     _     _     _     _     _     _     _            XX    XX    XX
  XX    XX    XX    XX    XX    XX    XX    XX    XX    XX    XX    XX    XX    _      XX    XX    XX     XX    XX    XX    XX
  _     @klps XX    @kltb XX    @wtgt XX    @wprv @fup  @wnxt @wmfp XX    XX    @wrnm  XX    XX    XX     XX    XX    XX    XX
  _     XX    @scrw @scrd @fuls @wtgs XX    @flft @fdwn @frgt @wmfc XX    @wtrm                           XX    XX    XX
  _     XX    XX    XX    @wspt XX    XX    XX    XX    XX    XX    _                        XX           XX    XX    XX    XX
  _     _     @wman             @wrof             _     _     _     _                  XX    XX    XX     XX    XX
)
(deflayer window_manipulation
  _     _     _     _     _     _     _     _     _     _     _     _     _            XX    XX    XX
  XX    XX    XX    XX    XX    XX    XX    XX    XX    XX    XX    XX    XX    _      XX    XX    XX     XX    XX    XX    XX
  _     XX    XX    XX    @wsrn XX    XX    @wszl @wmvu @wszr @wszu XX    XX    XX     XX    XX    XX     XX    XX    XX    XX
  _     XX    XX    XX    @wtmd XX    XX    @wmvl @wmvd @wmvr @wszd XX    @wmmw                           XX    XX    XX
  _     XX    XX    XX    XX    XX    @wsn  @wsml @wmvc @wsmr XX    _                        XX           XX    XX    XX    XX
  _     _     _                 _                 _     _     _     _                  XX    XX    XX     XX    XX
)
(defalias
    wman (layer-toggle window_manipulation)
    klps (cmd-button "i3-msg kill")
    kltb C-w
    wrnm (cmd-button "settitle")
    scrw (cmd-button "screenshot")
    scrd (cmd-button "screenshotdesktop")
    wtrm (cmd-button "alacritty")
    wrof (cmd-button "rofi -show drun")
    wspt (cmd-button "i3-msg split vertical")
    wtgt (cmd-button "i3-msg layout toggle tabbed split")
    wtgs (cmd-button "i3-msg layout toggle split")
    fuls (cmd-button "i3-msg fullscreen toggle")
    wnxt (cmd-button "i3-msg workspace next")
    wprv (cmd-button "i3-msg workspace prev")
    frgt (cmd-button "i3-msg focus right")
    flft (cmd-button "i3-msg focus left")
    fup  (cmd-button "i3-msg focus up")
    fdwn (cmd-button "i3-msg focus down")
    wmfp (cmd-button "i3-msg focus parent")
    wmfc (cmd-button "i3-msg focus child")
    wtmd (cmd-button "i3-msg focus mode_toggle")
    wsn  (cmd-button "userprompt -p 'Workspace name: ' -e 'i3-msg workspace {{}}'")
    wsml (cmd-button "i3-msg move workspace to output left")
    wsmr (cmd-button "i3-msg move workspace to output right")
    wmvl (cmd-button "i3-msg move left 50 px or 5 ppt")
    wmvr (cmd-button "i3-msg move right 50 px or 5 ppt")
    wmvu (cmd-button "i3-msg move up 25 px or 5 ppt")
    wmvd (cmd-button "i3-msg move down 25 px or 5 ppt")
    wmvc (cmd-button "windowcenter")
    wmmw (cmd-button "userprompt -p 'Move window to workspace: ' -e 'i3-msg move to workspace {{}}'")
    wsrn (cmd-button "userprompt -p 'Rename workspace: ' -e 'i3-msg rename workspace to {{}}'")
    wszr (cmd-button "i3-msg resize grow width 50 px or 5 ppt")
    wszl (cmd-button "i3-msg resize shrink width 50 px or 5 ppt")
    wszu (cmd-button "i3-msg resize grow height 25 px or 5 ppt")
    wszd (cmd-button "i3-msg resize shrink height 25 px or 5 ppt")
)

