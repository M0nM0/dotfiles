local wezterm = require('wezterm')
local mux = wezterm.mux

local M = {}

-- 起動時の最初のウィンドウを画面いっぱいに広げる
-- ToggleFullScreen と違い、別スペースに移らない通常のウィンドウのまま最大化する
M.setup = function()
   wezterm.on('gui-startup', function(cmd)
      local _, _, window = mux.spawn_window(cmd or {})
      window:gui_window():maximize()
   end)
end

return M
