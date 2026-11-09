-- Run from the repo root: lua wezterm/tests/notifications.lua
package.path = 'wezterm/?.lua;' .. package.path
local events, panes, toasts = {}, {}, {}
local host_ok, host = pcall(require, 'wezterm')
if not host_ok then
   host = nil
end
local encoded, encode_count = {}, 0
local function clone(value)
   if type(value) ~= 'table' then
      return value
   end
   local copy = {}
   for key, item in pairs(value) do
      copy[key] = clone(item)
   end
   return copy
end
local payload
local window = { focused = false, current = 1 }
local fake = {
   GLOBAL = host and host.GLOBAL or {},
   on = function(name, callback)
      events[name] = callback
   end,
   json_parse = function(raw)
      assert(raw ~= 'invalid')
      if host and raw ~= '{}' then
         return host.json_parse(raw)
      end
      return encoded[raw] and clone(encoded[raw]) or payload
   end,
   json_encode = function(value)
      if host then
         return host.json_encode(value)
      end
      encode_count = encode_count + 1
      local key = 'encoded:' .. encode_count
      encoded[key] = clone(value)
      return key
   end,
   strftime = function()
      return '12:00:00'
   end,
   action_callback = function(callback)
      return callback
   end,
   action = {
      InputSelector = function(options)
         return options
      end,
   },
   nerdfonts = setmetatable({ fa_bell = 'BELL' }, {
      __index = function()
         return '_'
      end,
   }),
   log_error = function(message)
      error(message)
   end,
}
if host then
   -- WezTerm's module searcher also uses the module to register watched files.
   setmetatable(fake, { __index = host })
end
package.loaded.wezterm = fake
for id = 1, 3 do
   panes[id] = {
      pane_id = function()
         return id
      end,
      activate = function()
         window.current = id
      end,
   }
end
function window:active_pane()
   return panes[self.current]
end
function window:is_focused()
   return self.focused
end
function window:mux_window()
   return {
      tabs = function()
         return {
            {
               panes = function()
                  local result = {}
                  for _, pane in pairs(panes) do
                     table.insert(result, pane)
                  end
                  return result
               end,
            },
         }
      end,
   }
end
function window:toast_notification(title, body)
   table.insert(toasts, { title, body })
end
function window:perform_action(action)
   self.selector = action
end
local notifications = require('events.notifications')
notifications.setup()
-- Exercise migration from the old GLOBAL table representation as well.
fake.GLOBAL.terminal_notifications_v1 = { history = {}, unread = {} }
local serial = 0
local function notify(id)
   serial = serial + 1
   payload =
      { version = 1, op = 'notify', id = tostring(serial), title = 'Build', body = 'Finished' }
   events['user-var-changed'](window, panes[id], 'term_notify', '{}')
end
local function unread(id)
   return notifications.has_unread({ { pane_id = id } })
end

notify(1)
assert(
   type(fake.GLOBAL.terminal_notifications_v1) == 'string',
   'GLOBAL must store serialized state, not array proxies'
)
assert(unread(1) and #toasts == 1, 'unfocused app must retain unread notifications')
events['update-status'](window)
assert(unread(1), 'background app must not acknowledge visible panes')
window.focused = true
events['window-focus-changed'](window)
assert(not unread(1), 'returning to a focused pane acknowledges it')
notify(1)
assert(not unread(1) and #toasts == 1, 'viewed pane must stay quiet')
notify(2)
assert(unread(2) and #toasts == 2, 'another pane in the same window must notify')
events['user-var-changed'](window, panes[2], 'term_notify', '{}')
assert(#toasts == 2, 'duplicate events must not repeat notifications')
events['notifications.show'](window, panes[1])
assert(#window.selector.choices == 3, 'history must include read and unread entries')
window.selector.action(window, panes[1], '1')
assert(
   window.current == 2 and not unread(2),
   'history selection activates source and acknowledges it'
)
notify(1)
events['notifications.jump-unread'](window)
assert(window.current == 1 and not unread(1), 'jump must activate newest unread pane')
notify(3)
payload = { version = 1, op = 'clear' }
events['user-var-changed'](window, panes[3], 'term_notify', '{}')
assert(not unread(3), 'explicit clear must acknowledge the sender only')
notify(3)
panes[3] = nil
events['notifications.jump-unread'](window)
assert(window.current == 1, 'closed panes must not be activated')
events['notifications.show'](window, panes[1])
for _, choice in ipairs(window.selector.choices) do
   assert(not choice.label:find('[pane 3]', 1, true), 'closed panes must be omitted')
end
for _ = 1, 105 do
   notify(2)
end
events['notifications.show'](window, panes[1])
assert(#window.selector.choices == 100, 'history must remain bounded')
assert(not unread(3), 'eviction must remove orphaned unread entries')
local count = #toasts
events['user-var-changed'](window, panes[1], 'term_notify', 'invalid')
payload = { version = 1, op = 'notify', id = 'bad', title = false, body = 'invalid' }
events['user-var-changed'](window, panes[1], 'term_notify', '{}')
assert(#toasts == count, 'malformed data must be ignored')
package.loaded['events.notifications'] = nil
notifications = require('events.notifications')
notifications.setup()
assert(unread(2), 'config reload must preserve unread state')
local titles = require('events.tab-title')
titles.setup()
local tab = {
   tab_id = 1,
   tab_index = 0,
   is_active = false,
   active_pane = { foreground_process_name = 'bash', title = 'Shell' },
   panes = { { pane_id = 2, has_unseen_output = false } },
}
local function title_text()
   local text = ''
   for _, item in ipairs(events['format-tab-title'](tab, {}, {}, {}, false, 25)) do
      if type(item) == 'table' and item.Text then
         text = text .. item.Text
      end
   end
   return text
end
assert(
   title_text():find('BELL', 1, true),
   'unread must render a bell independently of unseen output'
)
window.current = 2
events['update-status'](window)
assert(not title_text():find('BELL', 1, true), 'acknowledging source must remove its tab bell')
fake.GLOBAL.terminal_notifications_v1 = {
   history = {
      {
         id = 'legacy',
         pane_id = 1,
         title = 'Old',
         body = 'Old event',
         time = '11:00:00',
         unread = true,
      },
   },
   unread = { ['1'] = true },
}
window.current = 2
notify(2)
events['notifications.show'](window, panes[2])
assert(#window.selector.choices == 2, 'existing proxy-based history must migrate before appending')
assert(unread(1), 'migration must retain unread state')
print('Notification state tests passed')
