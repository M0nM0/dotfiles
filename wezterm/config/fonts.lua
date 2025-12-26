local wezterm = require('wezterm')
local platform = require('utils.platform')

-- local font = 'Maple Mono SC NF'
-- local font_family = 'JetBrainsMono Nerd Font'
local font_family = 'MesloLGS NF'
local font_size = 13.0

return {
   font = wezterm.font({
      family = font_family,
      weight = 'Regular',
   }),
   font_size = font_size,

   --ref: https://wezfurlong.org/wezterm/config/lua/config/freetype_pcf_long_family_names.html#why-doesnt-wezterm-use-the-distro-freetype-or-match-its-configuration
   freetype_load_target = 'Light', ---@type 'Normal'|'Light'|'Mono'|'HorizontalLcd'
   freetype_render_target = 'Normal', ---@type 'Normal'|'Light'|'Mono'|'HorizontalLcd'
   freetype_load_flags = 'NO_HINTING', -- macOS高DPI向け明示的設定
}
