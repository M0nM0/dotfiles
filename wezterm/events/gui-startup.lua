local wezterm = require('wezterm')
local mux = wezterm.mux
local fonts = require('config.fonts')

local M = {}

-- 1 セルの幅・高さ (フォントサイズ比)
local CELL_WIDTH_EM = 0.6
local CELL_HEIGHT_EM = 1.32

-- 起動時の最初のウィンドウを画面いっぱいに広げる
-- ToggleFullScreen と違い、別スペースに移らない通常のウィンドウのまま最大化する
M.setup = function()
   wezterm.on('gui-startup', function(cmd)
      local screen = wezterm.gui.screens().active
      local scale = screen.scale or 1
      local cell_width = fonts.font_size * scale * CELL_WIDTH_EM
      local cell_height = fonts.font_size * scale * CELL_HEIGHT_EM

      local args = cmd or {}
      args.width = math.floor(screen.width / cell_width)
      args.height = math.floor(screen.height / cell_height)
      args.position = { x = 0, y = 0, origin = 'ActiveScreen' }

      local _, _, window = mux.spawn_window(args)
      window:gui_window():maximize()
   end)
end

return M
