local wezterm = require('wezterm')
local platform = require('utils.platform')

local font_family = platform.is_mac and 'JetBrainsMono Nerd Font' or 'MesloLGS NF'
local font_size = 12.0

return {
   font = wezterm.font({
      family = font_family,
      weight = 'Regular',
   }),
   font_size = font_size,

   --ref: https://wezfurlong.org/wezterm/config/lua/config/freetype_pcf_long_family_names.html#why-doesnt-wezterm-use-the-distro-freetype-or-match-its-configuration
   freetype_load_target = 'Light', ---@type 'Normal'|'Light'|'Mono'|'HorizontalLcd'
   freetype_render_target = 'Normal', ---@type 'Normal'|'Light'|'Mono'|'HorizontalLcd'
   freetype_load_flags = platform.is_mac and 'NO_HINTING' or 'DEFAULT',
}
