------------------------------- Plugins ---------------------------------------

local config = require "core.config"


-- Builtin plugins
config.plugins.autocomplete.max_height = 15
config.plugins.autocomplete.min_len = 0
config.plugins.autoreload.always_show_nagview = true
config.plugins.bracketmatch.line_size = 4
config.plugins.drawwhitespace = { enabled = true, show_leading = false, show_middle_min = 2 }
config.plugins.lineguide.width = 0.5
config.plugins.lineguide.enabled = true
config.plugins.lineguide.rulers = { [1] = 80, [2] = 90, [3] = 100 }
config.plugins.linenumbers.relative = true
config.plugins.linewrapping.mode = "word"
config.plugins.lsp.mouse_hover_delay = 750
config.plugins.lsp.more_yielding = true
config.plugins.nerdicons.draw_tab_icons = true
config.plugins.nerdicons.draw_treeview_icons = true

config.plugins.snippets.autoexit = true
local snippets = require 'plugins.snippets'
snippets.add {
    trigger  = 'cb',
    info     = 'codeblock',
    desc     = 'Markdown codeblock',
    format   = 'lsp',
    template = [[
```${0:markdown}
```
]]
}

