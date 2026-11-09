-- Application-independent notifications, transported by OSC 1337 user variables.
local wezterm = require('wezterm')
local M = {}
local STATE_KEY = 'terminal_notifications_v1'
local HISTORY_LIMIT = 100

local function state()
   local stored = wezterm.GLOBAL[STATE_KEY]
   if type(stored) == 'string' then
      -- Decode to ordinary Lua tables; GLOBAL table values are proxy objects.
      return wezterm.json_parse(stored)
   end
   local value = { history = {}, unread = {} }
   -- Migrate history saved by the earlier table-based implementation.
   if stored then
      for _, item in pairs(stored.history) do
         local copy = {
            id = item.id,
            pane_id = item.pane_id,
            title = item.title,
            body = item.body,
            time = item.time,
            unread = item.unread,
         }
         table.insert(value.history, copy)
         if copy.unread then
            value.unread[tostring(copy.pane_id)] = true
         end
      end
   end
   return value
end

local function save(value)
   -- Storing JSON avoids table.insert mutating a GLOBAL array proxy on reload.
   wezterm.GLOBAL[STATE_KEY] = wezterm.json_encode(value)
end

local function visible(window, pane)
   local active = window:active_pane()
   return window:is_focused() and active and active:pane_id() == pane:pane_id()
end

local function mark_read(pane_id)
   local value = state()
   local key = tostring(pane_id)
   if value.unread[key] then
      value.unread[key] = nil
      for _, item in ipairs(value.history) do
         if item.pane_id == pane_id then
            item.unread = false
         end
      end
      save(value)
   end
end

function M.has_unread(panes)
   local unread = state().unread
   for _, pane in ipairs(panes) do
      if unread[tostring(pane.pane_id)] then
         return true
      end
   end
   return false
end

local function panes_in(window)
   local panes = {}
   for _, tab in ipairs(window:mux_window():tabs()) do
      for _, pane in ipairs(tab:panes()) do
         panes[pane:pane_id()] = pane
      end
   end
   return panes
end

local function activate(window, pane_id)
   local pane = panes_in(window)[pane_id]
   if pane then
      pane:activate()
      mark_read(pane_id)
   end
end

local function window_history(window)
   local items = {}
   local panes = panes_in(window)
   for _, item in ipairs(state().history) do
      if panes[item.pane_id] then
         table.insert(items, item)
      end
   end
   return items
end

local function clean(text)
   return (text:gsub('%c', ' '))
end

function M.setup()
   wezterm.on('user-var-changed', function(window, pane, name, raw)
      if name ~= 'term_notify' or #raw > 16384 then
         return
      end
      local ok, message = pcall(wezterm.json_parse, raw)
      if not ok or type(message) ~= 'table' or message.version ~= 1 then
         return
      end
      if message.op == 'clear' then
         mark_read(pane:pane_id())
         return
      end
      if
         message.op ~= 'notify'
         or type(message.title) ~= 'string'
         or type(message.body) ~= 'string'
      then
         return
      end
      if
         type(message.id) ~= 'string'
         or #message.id > 100
         or #message.title > 1024
         or #message.body > 4096
      then
         return
      end
      local value = state()
      -- A user-var event may reach multiple clients; keep one history entry per ID.
      for _, previous in ipairs(value.history) do
         if previous.id == message.id then
            return
         end
      end
      local unread = not visible(window, pane)
      local item = {
         id = message.id,
         pane_id = pane:pane_id(),
         title = clean(message.title),
         body = clean(message.body),
         time = wezterm.strftime('%H:%M:%S'),
         unread = unread,
      }
      table.insert(value.history, 1, item)
      if #value.history > HISTORY_LIMIT then
         table.remove(value.history)
      end
      value.unread = {}
      for _, previous in ipairs(value.history) do
         if previous.unread then
            value.unread[tostring(previous.pane_id)] = true
         end
      end
      save(value)
      if unread then
         window:toast_notification(item.title, item.body, nil, 5000)
      else
         mark_read(item.pane_id)
      end
   end)

   local function acknowledge(window)
      local pane = window:active_pane()
      if pane and window:is_focused() then
         mark_read(pane:pane_id())
      end
   end
   wezterm.on('update-status', acknowledge)
   wezterm.on('window-focus-changed', acknowledge)

   wezterm.on('notifications.jump-unread', function(window)
      for _, item in ipairs(window_history(window)) do
         if item.unread then
            activate(window, item.pane_id)
            return
         end
      end
   end)

   wezterm.on('notifications.show', function(window, pane)
      local items = window_history(window)
      local choices = {}
      for i, item in ipairs(items) do
         table.insert(choices, {
            id = tostring(i),
            label = string.format(
               '%s %s  [pane %d] %s: %s',
               item.unread and '●' or ' ',
               item.time,
               item.pane_id,
               item.title,
               item.body
            ),
         })
      end
      window:perform_action(
         wezterm.action.InputSelector({
            title = 'Notifications',
            choices = choices,
            fuzzy = true,
            action = wezterm.action_callback(function(selected_window, _, id)
               if id and items[tonumber(id)] then
                  activate(selected_window, items[tonumber(id)].pane_id)
               end
            end),
         }),
         pane
      )
   end)
end

return M
