-- Standard awesome library
local gears = require("gears")
local awful = require("awful")
require("awful.autofocus")
-- Widget and layout library
local wibox = require("wibox")
-- Theme handling library
local beautiful = require("beautiful")
-- HiDPI handling
local dpi = require("beautiful").xresources.apply_dpi
-- Notification library
local naughty = require("naughty")
local menubar = require("menubar")
local hotkeys_popup = require("awful.hotkeys_popup").widget
-- Alternative widget libraries
local vicious = require("vicious")
local fleet = require("fleet")

-- {{{ Error handling
-- Check if awesome encountered an error during startup and fell back to
-- another config (This code will only ever execute for the fallback config)
if awesome.startup_errors then
	naughty.notify({ preset = naughty.config.presets.critical,
	title = "Oops, there were errors during startup!",
	text = awesome.startup_errors })
end

-- Handle runtime errors after startup
do
	local in_error = false
	awesome.connect_signal("debug::error", function (err)
		-- Make sure we don't go into an endless error loop
		if in_error then return end
		in_error = true

		naughty.notify({ preset = naughty.config.presets.critical,
		title = "Oops, an error happened!",
		text = tostring(err) })
		in_error = false
	end)
end
-- }}}

-- {{{ Variable definitions
-- Themes define colours, icons, font and wallpapers.
-- beautiful.init(awful.util.get_themes_dir() .. "default/theme.lua")
beautiful.init(os.getenv("HOME") .. "/.config/awesome/themes/fleet/theme.lua")

terminal = "urxvt" or "terminology" or "terminator" or "gnome-terminal" or "xterm"
browser = "firefox" or "chromium" or "epiphany"
editor = os.getenv("EDITOR") or "vim" or "vi" or "nano"

editor_cmd = terminal .. " -e " .. editor
lockscreen_cmd = "xlock -mode space"

screenshot = "gnome-screenshot -i"

-- Default modkey.
modkey = "Mod4"

-- Table of layouts to cover with awful.layout.inc, order matters.
awful.layout.layouts = {
	awful.layout.suit.floating,
	awful.layout.suit.max,
	-- awful.layout.suit.max.fullscreen,
	awful.layout.suit.fair,
	awful.layout.suit.fair.horizontal,
	awful.layout.suit.tile,
	awful.layout.suit.tile.left,
	awful.layout.suit.tile.top,
	awful.layout.suit.tile.bottom,
	-- awful.layout.suit.spiral,
	-- awful.layout.suit.spiral.dwindle,
	-- awful.layout.suit.magnifier,
	-- awful.layout.suit.corner.nw,
	-- awful.layout.suit.corner.ne,
	-- awful.layout.suit.corner.sw,
	-- awful.layout.suit.corner.se,
}
-- }}}

-- {{{ External library config
awful.titlebar.enable_tooltip = false
naughty.config.defaults.timeout = 0
naughty.config.presets.low.timeout = 4
naughty.config.presets.low.border_color = "#FFFFFF"
naughty.config.presets.normal.border_color = "#FFFFFF"
naughty.config.presets.critical.border_color = "#FFFFFF"
-- }}}

-- {{{ Helper functions
local swappable = setmetatable({}, { __mode = "k" })
_awesome_quit = awesome.quit
_awesome_restart = awesome.restart

awesome.quit = function()
	if os.getenv("XDG_CURRENT_DESKTOP") == "GNOME" then
		os.execute("/usr/bin/gnome-session-quit --logout --no-prompt")
	else
		_awesome_quit()
	end
end

awesome.restart = function()
	_awesome_restart()
end

function run_once ( cmd )
	findme = cmd
	firstspace = cmd:find(" ")

	if firstspace then
		findme = cmd:sub(0, firstspace - 1)
	end

	awful.util.spawn_with_shell("pgrep -u $USER -x " .. findme .. " > /dev/null || (" .. cmd .. ")")
end

local function client_menu_toggle_fn()
	local instance = nil

	return function ()
		if instance and instance.wibox.visible then
			instance:hide()
			instance = nil
		else
			instance = awful.menu.clients({ theme = { width = dpi(400) } }, {}, fleet.widget.client_control.filter.currenttags)
		end
	end
end

local function add_tag (s, nofocus)
	local s = s or awful.screen.focused()
	local idx = (#s.tags + 1)

	local t = awful.tag.add(idx, {
		screen = s,
    layout = awful.layout.suit.floating,
	})

	if not nofocus then
		t:view_only()
	end

	reicon_tags()
end

local function move_to_new_tag ()
	local c = client.focus
	if not c then return end

	local t = awful.tag.add(c.class,{screen= c.screen })
	c:tags({t})
	t:view_only()

	reicon_tags()
end

local function copy_tag ()
	local t = awful.screen.focused().selected_tag
	if not t then return end

	local clients = t:clients()
	local t2 = awful.tag.add(t.name, awful.tag.getdata(t))

	t2:clients(clients)
	t2:view_only()

	reicon_tags()
end

local function delete_tag ()
	local tags = awful.screen.focused().tags
	local num_tags = #tags
	local t = awful.screen.focused().selected_tag

	if not t or 1 == num_tags then return end

	t:delete()

	reicon_tags()
end

local function rename_tag ()
	awful.prompt.run {
		prompt       = " Tag Name: ",
		textbox      = awful.screen.focused().mypromptbox.widget,
		exe_callback = function (new_name)
			local t = awful.screen.focused().selected_tag

			if t then
				if not new_name or #new_name == 0 then
					--t.icon_only = true
					t.name = t.index
				else
					t.icon_only = false
					t.name = new_name
					t.icon = beautiful.tag_icon[t.index] or nil
				end
			end

			reicon_tags()
		end}
end

function reicon_tags ()
	awful.screen.connect_for_each_screen(function (s)
		for _, t in pairs(s.tags) do
			if t.icon then
				t.icon = beautiful.tag_icon[t.index] or nil
			end
		end
	end)
end

local function set_wallpaper_beautiful (s)
	local wallpaper = beautiful.wallpaper

	if type(wallpaper) == "function" then
		wallpaper = wallpaper(s)
	end

	gears.wallpaper.maximized(wallpaper, s, true)
end

local function set_wallpaper(s)
	-- Wallpaper
	awful.spawn.easy_async("nitrogen --restore", function (out, err, reason, code)
		if code > 0 and beautiful.wallpaper then
			if s then
				set_wallpaper_beautiful(s)
			else
				awful.screen.connect_for_each_screen(set_wallpaper_beautiful)
			end
		end
	end)
end

local function adjust_client_border (c)
	if c.fullscreen or c.maximized == true or (c.maximized_horizontal == true and c.maximized_vertical == true) then
		c.border_width = 0
		awful.titlebar.hide(c)

	--	c.shape = function (cr, w, h)
	--	 gears.shape.rectangle(cr, w, h)
	--	end
	else
		c.border_width = beautiful.border_width

		if not c.requests_no_titlebar then
			awful.titlebar.show(c)
		end

	--	c.shape = function (cr, w, h)
			-- gears.shape.rectangle(cr, w, h)
			-- gears.shape.rounded_rect(cr, w, h, 5)
			-- gears.shape.octogon(cr, w, h, 40)
	--	end
	end
end

local function swappable_widget (s, fw, sw)
	local swaps = swappable[s]

	if not swaps then
		swaps = setmetatable({}, { __mode = "v" })
		swappable[s] = swaps
	end

	local w = wibox.widget {
		fw,
		widget = wibox.container.margin
	}

	w._swappable = {position = "a", widgets = {a = fw, b = sw}}

	table.insert(swaps, w)

	return w
end

local function swap_swappable (s, pos)
	if not s or not swappable[s] then return end
	if pos ~= "a" and pos ~= "b" then pos = nil end

	local swaps = swappable[s]

	for _, w in pairs(swaps) do
		if not pos then
			if w._swappable.position == "a" then
				pos = "b"
			else
				pos = "a"
			end
		end

		w._swappable.position = pos
		w.widget = w._swappable.widgets[pos]
	end
end

local function wrap_widget_vmargin (widget)
	return wibox.container.margin(widget, 0, 0, dpi(2), dpi(2))
end

local function wrap_widget_hmargin (widget)
	return wibox.container.margin(widget, dpi(2), dpi(2), 0, 0)
end

local function wrap_widget_margin (widget)
	return wrap_widget_hmargin(wrap_widget_vmargin(widget))
end

local function wrap_widget (w)
	return wrap_widget_hmargin(wibox.widget {
		{
			w,
			left = dpi(4),
			right = dpi(4),
			top = dpi(2),
			bottom = dpi(2),
			widget = wibox.container.margin
		},
		shape = gears.shape.rectangle,
		shape_border_color = "#777777",
		shape_border_width = 0,
		bg = beautiful.bg_widget,
		widget = wibox.container.background
	})
end
-- }}}

-- {{{ Menu
-- Create a launcher widget and a main menu
myawesomemenu = {
	{ "hotkeys", function() return false, hotkeys_popup.show_help end },
	{ "manual", terminal .. " -e man awesome" },
	{ "edit config", editor_cmd .. " " .. awesome.conffile }
}

mysysmenu = {
	{ "suspend", "systemctl suspend"},
	{ "hibernate", "systemctl hibernate"},
	{ "reboot", "systemctl reboot"},
	{ "poweroff", "systemctl poweroff"}
}

mysessmenu = {
	{ "restart", function() awesome.restart() end },
	{ "quit", function() awesome.quit() end}
}

mywmmenu = {
	{ "toggle swap", function ()
		awful.screen.connect_for_each_screen(function(s)
			if awful.screen.focused() == s then
				swap_swappable(s)
			else
				swap_swappable(s, "a")
			end
		end)
 end },
	{ "toggle wibox", function () fleet.layout.toggle_wibox({awful.screen.focused().mywibox}) end },
	{ "change wallpaper", "nitrogen" },
	{ "lock screen", lockscreen_cmd },
}

myscreenmenu = {
	{ "Clone", "xrandr" },
	{ "Expand", "xrandr" }
}

mymainmenu = awful.menu({
	items = {
		{ "session", mysessmenu },
		{ "system", mysysmenu },
		{ "awesome", myawesomemenu },
	--	{ "awesome", myawesomemenu, beautiful.awesome_icon },
		{ "desktop", mywmmenu },
		{ "open terminal", terminal },
		{ "open browser", browser },
		{ "take screenshot", screenshot },
		{ "lock screen", lockscreen_cmd },
	}
})

myrootmenu = awful.menu({
	items = mywmmenu
})

mylauncher = awful.widget.launcher({
	image = beautiful.awesome_icon,
	menu = mymainmenu
})

-- Menubar configuration
menubar.utils.terminal = terminal -- Set the terminal for applications that require it
menubar.geometry = { y = 0, height = dpi(22) }
-- }}}

-- {{{ Wibar Widgets
-- Separators
bar = wibox.widget.imagebox()
bar:set_image(beautiful.bar)

-- Battery
batwidget = wibox.widget {
	{
		id = "baticon",
		image = beautiful.battery_icon,
		widget = wibox.widget.imagebox,
	},
	layout = wibox.layout.fixed.horizontal
}

battooltip = awful.tooltip {
	objects = { batwidget },
	text = "0% - unknown (00:00 remaining)",
}

vicious.register(batwidget, vicious.widgets.bat, function (widget, args)
	local baticon = beautiful.battery_empty
	local state = args[1]
	local perc = args[2]
	local remaining = args[3]
	local batstate = ( state == "+" and "charging" or "discharging" )
	local timestate = ( state == "+" and "until charged" or "remaining" )

	battooltip.text = perc .. "% - " .. batstate .. " (" .. remaining .. " " .. timestate .. ")"

	if perc > 99 then
		baticon = beautiful.battery_full
	elseif perc > 65 then
		baticon = beautiful.battery_high
	elseif perc > 35 then
		baticon = beautiful.battery_medium
	elseif perc > 15 then
		baticon = beautiful.battery_low
	elseif perc > 5 then
		baticon = beautiful.battery_empty
	else
		baticon = beautiful.battery_critical
	end

	widget.baticon.image = baticon

end, 30, "BAT0")

-- Keyboard map indicator and switcher
kbdlayout = fleet.widget.keyboard_layout_control({
	{ name = "CO", layout = "us", variant = "colemak" },
	{ name = "DV", layout = "us", variant = "dvorak" },
	{ name = "US", layout = "us", variant = nil }
})

kbdleds = fleet.widget.keyboard_key_control({
	led_on = '#8AE181',
	position = 'top_right',
	font = 'xos4 Terminus:style=Bold:size=' .. tostring(dpi(10)),
	keys = {
		{ name = ' 1 ', key = 'Num_Lock', led = 'Num Lock' },
		{ name = ' A ', key = 'Caps_Lock', led = 'Caps Lock' }
	}
})

keyboardwidget = wibox.widget {
	{
		image = beautiful.keyboard_icon,
		widget = wibox.widget.imagebox,
	},
	bar,
	kbdlayout.widget,
	wrap_widget_hmargin(nil),
	kbdleds.widget,
	--bar,
	--kbdkeys.widget,
	layout = wibox.layout.fixed.horizontal
}
-- Volume control
volumecontrol = fleet.widget.volume_control({channel="Master"})

volumewidget = wibox.widget {
	{
		image = beautiful.speaker_icon,
		widget = wibox.widget.imagebox,
	},
	bar,
	--wrap_widget_hmargin(nil),
	volumecontrol.widget,
	layout = wibox.layout.fixed.horizontal
}


-- Date
datewidget = wibox.widget {
	{
		image = beautiful.calendar_icon,
		widget = wibox.widget.imagebox,
	},
	bar,
	{
		id = "date",
		widget = wibox.widget.textbox,
	},
	layout = wibox.layout.fixed.horizontal
}

vicious.register(datewidget.date, vicious.widgets.date, '%a, %b %d', 60)

-- time
timewidget = wibox.widget {
	{
		image = beautiful.clock_icon,
		widget = wibox.widget.imagebox,
	},
	bar,
	{
		id = "time",
		widget = wibox.widget.textbox,
	},
	layout = wibox.layout.fixed.horizontal
}

vicious.register(timewidget.time, vicious.widgets.date, '%H:%M', 60)

-- CPU
cpuwidget = wibox.widget {
	{
		image = beautiful.cpu_icon,
		widget = wibox.widget.imagebox,
	},
	bar,
	{
		id = "perc",
		markup = '<span color="#FFFFFF">**</span>',
		widget = wibox.widget.textbox,
	},
	layout = wibox.layout.fixed.horizontal
}

vicious.register(cpuwidget.perc, vicious.widgets.cpu, function (widget, args)
	local color = '#8AE181'
	local perc = tostring(args[1])

	if args[1] < 10 then
		perc = '0'..tostring(args[1])
	elseif args[1] > 70 then
		color = '#E18181'
	elseif args[1] > 40 then
		color = '#E1C381'
	end

	return '<span color="'..color..'">'..perc..'</span> %'
end, 1)

-- Memory
memwidget = wibox.widget {
	{
		image = beautiful.mem_icon,
		widget = wibox.widget.imagebox,
	},
	bar,
	{
		id = "usage",
		markup = '<span color="#FFFFFF">**</span>',
		widget = wibox.widget.textbox,
	},
	layout = wibox.layout.fixed.horizontal
}

vicious.register(memwidget.usage, vicious.widgets.mem, function (widget, args)
	local color = '#8AE181'
	local usage = 0
	local metric = 'B'
	local used = ''

	if args[1] > 70 then
		color = '#E18181'
	elseif args[1] > 40 then
		color = '#E1C381'
	end

	if args[9] > 999999 then
		usage = args[9] / 1048576
		metric = 'T'
	elseif args[9] > 999 then
		usage = args[9] / 1024
		metric = 'G'
	else
		usage = args[9]
		metric = 'M'
	end

	if usage > 99.9 then
		used = tostring(math.ceil(usage))..'.'
	elseif usage > 9.99 then
		used = string.format("%.1f", usage)
	else
		used = string.format("%.2f", usage)
	end

	return '<span color="'..color..'">'..used..'</span> '..metric
end, 2)

-- Disk IO
diowidget = wibox.widget {
	{
		image = beautiful.hdd_icon,
		widget = wibox.widget.imagebox,
	},
	bar,
	{
		id = "disk",
		markup = '<span color="#FFFFFF"></span>',
		widget = wibox.widget.textbox,
	},
	bar,
	{
		id = "reads",
		markup = '<span color="#FFFFFF">0.00</span>',
		widget = wibox.widget.textbox,
	},
	bar,
	{
		id = "writes",
		markup = '<span color="#FFFFFF">0.00</span>',
		widget = wibox.widget.textbox,
	},
	layout = wibox.layout.fixed.horizontal
}

vicious.register(diowidget, vicious.widgets.dio, function (widget, args)
	local dev = machine.drive
	local d_c = '#777777'
	local r_s = 0
	local w_s = 0
	local r_m = 'B'
	local w_m = 'B'
	local r_c = '#8AE181'
	local w_c = '#8AE181'
	local reads = '0.00'
	local writes = '0.00'
	local r_kb = tonumber(args['{'..dev..' read_kb}'])
	local w_kb = tonumber(args['{'..dev..' write_kb}'])

	if r_kb > 999999999 then
		r_s = r_kb / 1073741824
		r_m = 'T'
	elseif r_kb > 999999 then
		r_s = r_kb / 1048576
		r_m = 'G'
	elseif r_kb > 999 then
		r_s = r_kb / 1024
		r_m = 'M'
	else
		r_s = r_kb
		r_m = 'K'
	end

	if r_s > 99.9 then
		reads = tostring(math.ceil(r_s))..'.'
	elseif r_s > 9.99 then
		reads = string.format("%.1f", r_s)
	else
		reads = string.format("%.2f", r_s)
	end

	if w_kb > 10240 then
		w_c = '#E18181'
	elseif w_kb > 5120 then
		w_c = '#E1C381'
	end

	if w_kb > 999999999 then
		w_s = w_kb / 1073741824
		w_m = 'T'
	elseif w_kb > 999999 then
		w_s = w_kb / 1048576
		w_m = 'G'
	elseif w_kb > 999 then
		w_s = w_kb / 1024
		w_m = 'M'
	else
		w_s = w_kb
		w_m = 'K'
	end

	if w_s > 99.9 then
		writes = tostring(math.ceil(w_s))..'.'
	elseif w_s > 9.99 then
		writes = string.format('%.1f', w_s)
	else
		writes = string.format('%.2f', w_s)
	end

	if w_kb > 10240 then
		w_c = '#E18181'
	elseif w_kb > 5120 then
		w_c = '#E1C381'
	end

	if r_kb > 1 or w_kb > 1 then
		d_c = '#FFFFFF'
	end

	widget.disk:set_markup('<span color="'..d_c..'">'..dev..'</span>')
	widget.reads:set_markup('<span color="'..r_c..'">'..reads..'</span> '..r_m)
	widget.writes:set_markup('<span color="'..w_c..'">'..writes..'</span> '..w_m)
	return
end, 1)

-- Combo Widget
combwidget = wibox.widget {
	wrap_widget_hmargin(wibox.widget.systray()),
	wrap_widget(volumewidget),
	wrap_widget(keyboardwidget),
	wrap_widget(cpuwidget),
	wrap_widget(memwidget),
	wrap_widget(diowidget),
	wrap_widget(datewidget),
	wrap_widget(timewidget),
	layout = wibox.layout.fixed.horizontal
}

-- Taglist
local taglist_buttons = awful.util.table.join(
	awful.button({ }, 1, function(t) t:view_only() end),
	awful.button({ modkey }, 1, function(t)
		if client.focus then
			client.focus:move_to_tag(t)
		end
	end),
	awful.button({ }, 3, awful.tag.viewtoggle),
	awful.button({ modkey }, 3, function(t)
		if client.focus then
			client.focus:toggle_tag(t)
		end
	end),
	awful.button({ }, 4, function(t) awful.tag.viewnext(t.screen) end),
	awful.button({ }, 5, function(t) awful.tag.viewprev(t.screen) end)
)

-- Tasklist
local tasklist_buttons = awful.util.table.join(
	awful.button({ }, 1, function (c)
		if c == client.focus then
			c.minimized = true
		else
			-- Without this, the following
			-- :isvisible() makes no sense
			c.minimized = false
			if not c:isvisible() and c.first_tag then
				c.first_tag:view_only()
			end
			-- This will also un-minimize
			-- the client, if needed
			client.focus = c
			c:raise()
		end
	end)
)

local taskalt_buttons = awful.util.table.join(
	awful.button({ }, 3, client_menu_toggle_fn()),
	awful.button({ }, 4, function ()
		awful.client.focus.byidx(1)
	end),
	awful.button({ }, 5, function ()
		awful.client.focus.byidx(-1)
	end)
)
-- }}}

-- {{{ Wibar
-- Create a wibox for each screen and add it
awful.screen.connect_for_each_screen(function(s)
	-- Each screen has its own tag table.
	awful.tag({ "1", "2", "3", "4", "5", "6", "7", "8", "9" }, s, awful.layout.layouts[1])

	-- Icon each tag
	-- for _, t in pairs(s.tags) do
	-- 	t.icon_only = true
	-- 	t.icon = beautiful.tag_icon[t.index] or nil
	-- end

	-- Create a promptbox for each screen
	s.mypromptbox = awful.widget.prompt()

	-- Create an imagebox widget which will contains an icon indicating which layout we're using.
	-- We need one layoutbox per screen.
	s.mylayoutbox = awful.widget.layoutbox(s)

	s.mylayoutbox:buttons(awful.util.table.join(
	awful.button({ }, 1, function () awful.layout.inc( 1) end),
	awful.button({ }, 3, function () awful.layout.inc(-1) end),
	awful.button({ }, 4, function () awful.layout.inc( 1) end),
	awful.button({ }, 5, function () awful.layout.inc(-1) end)))

	-- Create a taglist widget
	s.mytaglist = awful.widget.taglist(s, awful.widget.taglist.filter.all, taglist_buttons, {spacing = dpi(4)})

	-- Create a tasklist widget
	s.mytasklist = awful.widget.tasklist(s, fleet.widget.client_control.filter.currenttagsnotfocused, tasklist_buttons, {
		disable_task_name = true
	}, fleet.common.list_update)

	-- Create the wibox
	s.mywibox = awful.wibar({ position = "top", height = dpi(28), ontop = true, bg = "#000000AA", screen = s })

	-- Client control
	s.clientcontrols = fleet.widget.client_control(s, {
		{
			id = 'closebutton',
			widget = wibox.widget.imagebox(beautiful.none_normal),
			update = function (w, c)
				local image = fleet.widget.client_control.button_img('close', c)
				if image then
					w:set_image(image)
				end

				fleet.widget.client_control.bind_focus(c, w, awful.button({}, 1, nil, function () c:kill() end))
			end,
			reset = function (w)
				w:set_image(beautiful.none_normal)
				fleet.widget.client_control.unbind_all(w)
			end
		},
		{
			id = 'floatingbutton',
			widget = wibox.widget.imagebox(beautiful.none_normal),
			update = function (w, c, s)
				local image = fleet.widget.client_control.button_img('floating', c)
				if image then
					w:set_image(image)
				end

				fleet.widget.client_control.bind_focus(c, w, awful.button({}, 1, nil, function () awful.client.floating.toggle(c) end))
			end,
			reset = function (w)
				w:set_image(beautiful.none_normal)
				fleet.widget.client_control.unbind_all(w)
			end
		},
		{
			id = 'maximizedbutton',
			widget = wibox.widget.imagebox(beautiful.none_normal),
			update = function (w, c)
				local state = c.maximized
				local image = fleet.widget.client_control.button_img('maximized', c)
				if image then
					w:set_image(image)
				end

				fleet.widget.client_control.bind_focus(c, w, awful.button({}, 1, nil, function ()
					c.maximized = not c.maximized
					c:raise()
				end))
			end,
			reset = function (w)
				w:set_image(beautiful.none_normal)
				fleet.widget.client_control.unbind_all(w)
			end
		},
		{
			id = 'minimizebutton',
			widget = wibox.widget.imagebox(beautiful.none_normal),
			update = function (w, c)
				local image = fleet.widget.client_control.button_img('minimize', c)
				if image then
					w:set_image(image)
				end

				fleet.widget.client_control.bind_focus(c, w, awful.button({}, 1, nil, function () c.minimized = not c.minimized end))
			end,
			reset = function (w)
				w:set_image(beautiful.none_normal)
				fleet.widget.client_control.unbind_all(w)
			end
		},
		{
			id = 'ontopbutton',
			widget = wibox.widget.imagebox(beautiful.none_normal),
			update = function (w, c)
				local image = fleet.widget.client_control.button_img('ontop', c)
				if image then
					w:set_image(image)
				end

				fleet.widget.client_control.bind_focus(c, w, awful.button({}, 1, nil, function () c.ontop = not c.ontop end))
			end,
			reset = function (w)
				w:set_image(beautiful.none_normal)
				fleet.widget.client_control.unbind_all(w)
			end
		},
		{
			id = 'stickybutton',
			widget = wibox.widget.imagebox(beautiful.none_normal),
			update = function (w, c)
				local image = fleet.widget.client_control.button_img('sticky', c)
				if image then
					w:set_image(image)
				end

				fleet.widget.client_control.bind_focus(c, w, awful.button({}, 1, nil, function () c.sticky = not c.sticky end))
			end,
			reset = function (w)
				w:set_image(beautiful.none_normal)
				fleet.widget.client_control.unbind_all(w)
			end
		},
		{
			id = 'title',
			widget = wibox.widget.textbox('<span color="red">~</span>'),
			update = function (w, c)
				local name = (awful.util.escape(c.name) or awful.util.escape("<untitled>"))
				local color = fleet.widget.client_control.fg_color(c)

				w:set_markup('<span foreground="'..color..'">'..name..'</span>')
				fleet.widget.client_control.bind_focus(c, w, tasklist_buttons)
			end,
			reset = function (w)
				w:set_markup('<span color="red">~</span>')
				fleet.widget.client_control.unbind_all(w)
			end
		},
		{
			id = 'icon',
			widget = wibox.widget.imagebox(),
			update = function (w, c)
				if c.icon then
					w:set_image(c.icon)
				else
					w:set_image(beautiful.application_icon)
				end
			end,
			reset = function (w, c)
				w:set_image(beautiful.none_icon)
			end
		},
	})

	s.myclientcontrol = wibox.widget {
		wrap_widget_hmargin(nil),
		{
			wrap_widget_hmargin(s.clientcontrols.widget.icon),
			wrap_widget_hmargin(s.clientcontrols.widget.title),
			wrap_widget_vmargin(bar),
			layout = wibox.layout.align.horizontal
		},
		{
			{
				s.clientcontrols.widget.floatingbutton,
				s.clientcontrols.widget.maximizedbutton,
				s.clientcontrols.widget.stickybutton,
				s.clientcontrols.widget.ontopbutton,
				spacing = dpi(4),
				layout = wibox.layout.fixed.horizontal
			},
			wrap_widget_vmargin(bar),
			s.clientcontrols.widget.closebutton,
			spacing = 0,
			layout = wibox.layout.fixed.horizontal
		},
		buttons = taskalt_buttons,
		layout = wibox.layout.align.horizontal
	}

	-- Add widgets to the wibox
	s.mywibox:setup {
		{
			{ -- Left widgets
				wrap_widget_hmargin(mylauncher),
				--wrap_widget_hmargin(mysesslauncher),
				wrap_widget_hmargin(batwidget),
				wrap_widget_vmargin(bar),
				wrap_widget_hmargin(s.mytaglist),
				wrap_widget_vmargin(bar),
				wrap_widget_hmargin(s.mylayoutbox),
				layout = wibox.layout.fixed.horizontal
			},
			{
				wrap_widget_margin(s.mypromptbox),
				nil,
				wrap_widget_hmargin(s.mytasklist),
				layout = wibox.layout.align.horizontal
			},
			swappable_widget(s, s.myclientcontrol, combwidget),
			layout = wibox.layout.align.horizontal
		},
		left = dpi(2),
		right = dpi(2),
		top = dpi(2),
		bottom = dpi(4),
		widget = wibox.container.margin
	}

	--if 1 == s.index then
		-- Create the bottom wibox
		--s.mybotwibox = wibox({
		--	screen = s,
		--	x = 10,
		--	y = 0,
		--	width = 1024,
		--	height = 34,
		--	type = "normal",
		--	ontop = true,
		--	bg = "#000000AA",
		--	visible = false
		--})

		--s.mybotwibox:setup {
		--	{ -- Left widgets
		--		wrap_widget_vmargin(wrap_widget(keyboardwidget)),
		--		wrap_widget_vmargin(wrap_widget(volumewidget)),
		--		wrap_widget_vmargin(wrap_widget(wibox.widget.systray())),
		--		layout = wibox.layout.fixed.horizontal
		--	},
		--	{ -- Middle widgets
		--		layout = wibox.layout.fixed.horizontal
		--	},
		--	{ -- Right widgets
		--		wrap_widget_vmargin(wrap_widget(cpuwidget)),
		--		wrap_widget_vmargin(wrap_widget(memwidget)),
		--		wrap_widget_vmargin(wrap_widget(diowidget)),
		--		wrap_widget_vmargin(wrap_widget(datewidget)),
		--		wrap_widget_vmargin(wrap_widget(timewidget)),
		--		layout = wibox.layout.fixed.horizontal
		--	},
		--	layout = wibox.layout.align.horizontal
		--}
	--end
end)
-- }}}

-- {{{ Root mouse bindings
root.buttons(awful.util.table.join(
	awful.button({ }, 3, function () myrootmenu:toggle() end)
))
-- }}}

-- {{{ Client mouse bindings
clientbuttons = awful.util.table.join(
	awful.button({ }, 1, function (c) client.focus = c; c:raise() end),
	awful.button({ modkey }, 1, awful.mouse.client.move),
	awful.button({ modkey }, 3, awful.mouse.client.resize)
)
-- }}}

-- {{{ Global key bindings
globalkeys = awful.util.table.join(
	-- Tag modification
	awful.key({ modkey }, "a", add_tag,
	{description = "add a tag", group = "tag"}),

	awful.key({ modkey, "Shift" }, "a", delete_tag,
	{description = "delete the current tag", group = "tag"}),

	awful.key({ modkey, "Control" }, "a", move_to_new_tag,
	{description = "add a tag with the focused client", group = "tag"}),

	awful.key({ modkey, "Mod1" }, "a", copy_tag,
	{description = "create a copy of the current tag", group = "tag"}),

	awful.key({ modkey, "Shift" }, "r", rename_tag,
	{description = "rename the current tag", group = "tag"}),

	-- Screen browsing
	awful.key({ modkey }, "h", function () awful.screen.focus_bydirection("left") end,
	{description = "focus screen to left", group = "screen"}),

	awful.key({ modkey }, "n", function () awful.screen.focus_bydirection("down") end,
	{description = "focus screen down", group = "screen"}),

	awful.key({ modkey }, "e", function () awful.screen.focus_bydirection("up") end,
	{description = "focus screen up", group = "screen"}),

	awful.key({ modkey }, "i", function () awful.screen.focus_bydirection("right") end,
	{description = "focus screen to right", group = "screen"}),

	-- Tag browsing
	awful.key({ modkey }, "Left", awful.tag.viewprev,
	{description = "view previous", group = "tag"}),

	awful.key({ modkey }, "Right", awful.tag.viewnext,
	{description = "view next", group = "tag"}),

	awful.key({ modkey }, "Escape", awful.tag.history.restore,
	{description = "go back", group = "tag"}),

	awful.key({ modkey, "Shift" }, ",", awful.tag.viewprev,
	{description = "view previous", group = "tag"}),

	awful.key({ modkey, "Shift" }, ".", awful.tag.viewnext,
	{description = "view next", group = "tag"}),

	awful.key({ modkey }, ",", fleet.tag.viewprev_with_clients,
	{description = "view previous with clients", group = "tag"}),

	awful.key({ modkey }, ".", fleet.tag.viewnext_with_clients,
	{description = "view next with clients", group = "tag"}),

	-- Client browsing
	awful.key({ modkey }, "Tab", function () awful.client.focus.byidx(1) end,
	{description = "focus previous", group = "client"}),

	awful.key({ modkey, "Shift" }, "Tab", function () awful.client.focus.byidx(-1) end,
	{description = "focus next", group = "client"}),

	awful.key({ modkey }, "u", awful.client.urgent.jumpto,
	{description = "jump to urgent client", group = "client"}),

	-- Layout manipulation
	awful.key({ modkey }, "space", function () awful.layout.inc(1) end,
	{description = "select next", group = "layout"}),

	awful.key({ modkey, "Shift" }, "space", function () awful.layout.inc(-1) end,
	{description = "select previous", group = "layout"}),

	awful.key({ modkey }, "equal", function () awful.tag.incgap(1) end,
	{description = "increase useless gap", group = "layout"}),

	awful.key({ modkey }, "minus", function () awful.tag.incgap(-1) end,
	{description = "decrease useless gap", group = "layout"}),

	awful.key({ modkey }, "l", function () awful.tag.incmwfact(0.05) end,
	{description = "increase master width factor", group = "layout"}),

	awful.key({ modkey, "Control" }, "l", function () awful.tag.incncol(-1, nil, true) end,
	{description = "decrease the number of columns", group = "layout"}),

	--[[
	awful.key({ modkey }, "h", function () awful.tag.incmwfact(-0.05) end,
	{description = "decrease master width factor", group = "layout"}),

	awful.key({ modkey, "Shift" }, "h", function () awful.tag.incnmaster( 1, nil, true) end,
	{description = "increase the number of master clients", group = "layout"}),

	awful.key({ modkey, "Shift" }, "l", function () awful.tag.incnmaster(-1, nil, true) end,
	{description = "decrease the number of master clients", group = "layout"}),

	awful.key({ modkey, "Control" }, "h", function () awful.tag.incncol( 1, nil, true) end,
	{description = "increase the number of columns", group = "layout"}),
	--]]

	-- Client geometry
	awful.key({ modkey, "Shift" }, "j", function () awful.client.swap.byidx(1) end,
	{description = "swap with next client by index", group = "client"}),

	awful.key({ modkey, "Shift" }, "k", function () awful.client.swap.byidx(-1) end,
	{description = "swap with previous client by index", group = "client"}),

	awful.key({ modkey, "Control" }, "k", function ()
		local c = awful.client.restore()

		-- Focus restored client
		if c then
			client.focus = c
			c:raise()
		end
	end,
	{description = "restore minimized", group = "client"}),

	-- Menus
	awful.key({ modkey }, "w", function () mymainmenu:show() end,
	{description = "show main menu", group = "awesome"}),

	awful.key({ modkey }, "p", function() menubar.show() end,
	{description = "show the menubar", group = "launcher"}),

	-- Prompts
	awful.key({ modkey }, "r", function () awful.screen.focused().mypromptbox:run() end,
	{description = "run prompt", group = "launcher"}),

	awful.key({ modkey }, "x",
	function ()
		awful.prompt.run {
			prompt       = " Run Lua code: ",
			textbox      = awful.screen.focused().mypromptbox.widget,
			exe_callback = awful.util.eval,
			history_path = awful.util.get_cache_dir() .. "/history_eval"
		}
	end,
	{description = "lua execute prompt", group = "awesome"}),

	awful.key({ modkey }, "b", function ()
		awful.screen.connect_for_each_screen(function(s)
			if awful.screen.focused() == s then
				swap_swappable(s)
			else
				swap_swappable(s, "a")
			end
		end)
	end,
	{description = "hide the wibars", group = "layout"}),

	-- Help window
	awful.key({ modkey }, "s", hotkeys_popup.show_help,
	{description="show help", group="awesome"}),

	-- Standard program
	awful.key({}, "XF86AudioMute", function() volumecontrol:toggle() end),
	awful.key({}, "XF86AudioRaiseVolume", function() volumecontrol:up() end),
	awful.key({}, "XF86AudioLowerVolume", function() volumecontrol:down() end),
	awful.key({}, "XF86MonBrightnessDown", function () awful.spawn("xbacklight -dec 10") end),
	awful.key({}, "XF86MonBrightnessUp", function () awful.spawn("xbacklight -inc 10") end),
	awful.key({}, "XF86ScreenSaver", function () awful.spawn(lockscreen_cmd) end),
	awful.key({}, "XF86Sleep", function () awful.spawn("systemctl suspend") end),
	awful.key({}, "Num_Lock", function() kbdleds:update_key('Num_Lock') end),
	awful.key({}, "Caps_Lock", function() kbdleds:update_key('Caps_Lock') end),
	awful.key({}, "Print", function () awful.spawn(screenshot) end),

	-- Awesome
	awful.key({ modkey }, "Return", function () awful.spawn(terminal) end,
	{description = "open a terminal", group = "launcher"}),

	awful.key({ modkey, "Control" }, "BackSpace", awesome.restart,
	{description = "reload awesome", group = "awesome"}),

	awful.key({ modkey, "Control" }, "Escape", awesome.quit,
	{description = "quit awesome", group = "awesome"})
)

-- Bind all key numbers to tags.
-- Be careful: we use keycodes to make it works on any keyboard layout.
-- This should map on the top row of your keyboard, usually 1 to 9.
for i = 1, 9 do
	globalkeys = awful.util.table.join(globalkeys,
	-- View tag only.
	awful.key({ modkey }, "#" .. i + 9,
	function ()
		local screen = awful.screen.focused()
		local tag = screen.tags[i]
		if tag then
			tag:view_only()
		end
	end,
	{description = "view tag #"..i, group = "tag"}),
	-- Toggle tag display.
	awful.key({ modkey, "Control" }, "#" .. i + 9,
	function ()
		local screen = awful.screen.focused()
		local tag = screen.tags[i]
		if tag then
			awful.tag.viewtoggle(tag)
		end
	end,
	{description = "toggle tag #" .. i, group = "tag"}),
	-- Move client to tag.
	awful.key({ modkey, "Shift" }, "#" .. i + 9,
	function ()
		if client.focus then
			local tag = client.focus.screen.tags[i]
			if tag then
				client.focus:move_to_tag(tag)
			end
		end
	end,
	{description = "move focused client to tag #"..i, group = "tag"}),
	-- Toggle tag on focused client.
	awful.key({ modkey, "Control", "Shift" }, "#" .. i + 9,
	function ()
		if client.focus then
			local tag = client.focus.screen.tags[i]
			if tag then
				client.focus:toggle_tag(tag)
			end
		end
	end,
	{description = "toggle focused client on tag #" .. i, group = "tag"})
	)
end

-- }}}

-- {{{ Client key bindings
clientkeys = awful.util.table.join(
	awful.key({ modkey, "Control" }, "Return", function (c) c:swap(awful.client.getmaster()) end,
	{description = "move to master", group = "client"}),

	awful.key({ modkey }, "o", function (c) c:move_to_screen() end,
	{description = "move to screen", group = "client"}),

	awful.key({ modkey, "Control" }, "space",  awful.client.floating.toggle,
	{description = "toggle floating", group = "client"}),

	awful.key({ modkey }, "k", function (c)
	-- The client currently has the input focus, so it cannot be
	-- minimized, since minimized clients can't have the focus.
		c.minimized = true
	end ,
	{description = "minimize", group = "client"}),

	awful.key({ modkey }, "m", function (c)
		c.maximized = not c.maximized
		c:raise()
	end ,
	{description = "maximize", group = "client"}),

	awful.key({ modkey }, "f", function (c)
		c.fullscreen = not c.fullscreen
		c:raise()
	end,
	{description = "toggle fullscreen", group = "client"}),

	awful.key({ modkey }, "t", function (c) c.ontop = not c.ontop end,
	{description = "toggle keep on top", group = "client"}),

	awful.key({ modkey, "Shift"   }, "c", function (c) c:kill() end,
	{description = "close", group = "client"})
)

-- Bind keypad to move and resize client
NumericPad = { "KP_End", "KP_Down", "KP_Next", "KP_Left", "KP_Begin", "KP_Right", "KP_Home", "KP_Up", "KP_Prior" }
NumericPadMap = {
	{-20,20,20,20,'left'}, {0,20,0,20,'down'}, {20,20,20,20,'right'},
	{-20,0,20,0,'left'}, {0,0,0,0,'none'}, {20,0,20,0,'right'},
	{-20,-20,20,20,'left'}, {0,-20,0,20,'up'}, {20,-20,20,20,'right'}
}

for i = 1, 9 do
	clientkeys = awful.util.table.join(clientkeys,

	awful.key({ modkey }, NumericPad[i], function (c)
		if awful.client.floating.get(c) or awful.layout.get(c.screen) == awful.layout.suit.floating then
			awful.client.moveresize(NumericPadMap[i][1], NumericPadMap[i][2], 0, 0, c)
		elseif NumericPadMap[i][5] then
			awful.client.swap.bydirection(NumericPadMap[i][5], c)
		end
	end, {description = "move client "..NumericPadMap[i][5], group = "client"}),

	awful.key({ modkey, "Shift" }, NumericPad[i], function (c)
		if not c.is_fixed(c) then
			local x = NumericPadMap[i][1]
			local y = NumericPadMap[i][2]
			if x > 0 then x = 0 end
			if y > 0 then y = 0 end
			awful.client.moveresize(x, y, NumericPadMap[i][3], NumericPadMap[i][4], c)
		end
	end, {description = "grow client "..NumericPadMap[i][5], group = "client"}),

	awful.key({ modkey, "Control" }, NumericPad[i], function (c)
		if not c.is_fixed(c) then
			local x = NumericPadMap[i][1] * -1
			local y = NumericPadMap[i][2] * -1
			if x < 0 then x = 0 end
			if y < 0 then y = 0 end
			awful.client.moveresize(x, y, NumericPadMap[i][3] * -1, NumericPadMap[i][4] * -1, c)
		end
	end, {description = "shrink client "..NumericPadMap[i][5], group = "client"}))
end
-- }}}

-- {{{ Rules
-- Rules to apply to new clients (through the "manage" signal).
awful.rules.rules = {
	-- All clients will match this rule.
	{ rule = { },
		properties = {
			border_width = beautiful.border_width,
			border_color = beautiful.border_normal,
			focus = awful.client.focus.filter,
			raise = true,
			keys = clientkeys,
			buttons = clientbuttons,
			screen = awful.screen.preferred,
			size_hints_honor = true,
			placement = awful.placement.no_overlap+awful.placement.no_offscreen,
			titlebars_enabled = false
		}
	},

	-- No Border clients
	{ rule_any = {
			class = {
				"Plank",
			}
		},
		properties = {
			border_width = 0,
			border_color = 'transparent',
		},
	},

	-- No size hints clients
	{ rule_any = {
			class = {
				"URxvt",
			}
		},
		properties = {
			size_hints_honor = false
		},
	},

	-- Floating and Centered clients.
	{ rule_any = {
			type = {
				"dialog",
			},
			instance = {
				"gnome",
				"eog",
				"gpk",
				"dconf",
				"copyq", -- Includes session name in class.
			},
			class = {
				"Kruler",
				"MessageWin", -- kalarm.
				"pinentry",
				"veromix",
				"xtightvncviewer",
				"Gtk-recordMyDesktop",
				"Wallp",
				"Nautilus",
				"Evolution-alarm-notify",
			},
			role = {
				"AlarmWindow", -- Thunderbird's calendar.
			}
		},
		properties = {
			floating = true,
			placement = awful.placement.centered
		},
	},

	-- Titlebar clients
	{ rule_any = {
			instance = {
				"nitrogen",
				"pavucontrol",
				"zoom",
			},
			class = {
				"Arandr",
				"Nm-connection-editor",
				"MPlayer",
				"vdpau",
			},
			name = {
				"Event Tester", -- xev.
			},
		},
		properties = {
			floating = true,
			titlebars_enabled = true
		},
	},

	-- Floating centered titlebar clients
	{ rule_any = {
			instance = {
				"seahorse",
				"DTA", -- Firefox addon DownThemAll.
				"Devtools",-- Firefox Devtools Window.
				"sun-awt-X11-XDialogPeer",
				"sun-awt-X11-XFramePeer",
			},
			class = {
				"Gpick",
				"Sxiv",
				"Wpa_gui",
			},
			name = {
				"Blender User Preferences",
			},
			role = {
				"app", -- Chrome's app windows
				"pop-up", -- Google Chrome's (detached) Developer Tools.
				"gimp-file-open", -- Gimp open file dialog
			}
		},
		properties = {
			floating = true,
			titlebars_enabled = true,
			placement = awful.placement.centered
		},
	},
}
-- }}}

-- {{{ Signals
-- Re-set wallpaper when a screen's geometry changes (e.g. different resolution)
screen.connect_signal("property::geometry", set_wallpaper)

screen.connect_signal("arrange", function ()
	local clients = awful.client.visible(s)

	if #clients > 0 then
		for _, c in pairs(clients) do
			adjust_client_border(c)
		end
	end
end)

-- Signal function to execute when a new client appears.
client.connect_signal("manage", function (c)
	-- Set the windows at the slave,
	-- i.e. put it at the end of others instead of setting it master.
	-- if not awesome.startup then awful.client.setslave(c) end

	if awesome.startup and
		not c.size_hints.user_position and not c.size_hints.program_position then
		-- Prevent clients from being unreachable after screen count changes.
		awful.placement.no_offscreen(c)
	end
end)

-- Add a titlebar if titlebars_enabled is set to true in the rules.
client.connect_signal("request::titlebars", function(c)
	-- buttons for the titlebar
	local buttons = awful.util.table.join(
		awful.button({ }, 1, function()
			client.focus = c
			c:raise()
			awful.mouse.client.move(c)
		end),
		awful.button({ }, 3, function()
			client.focus = c
			c:raise()
			awful.mouse.client.resize(c)
		end)
	)

	local titlebar = {
		icon = wibox.widget {
			awful.titlebar.widget.iconwidget(c),
			buttons = buttons,
			layout = wibox.layout.fixed.horizontal,
		},
		title = wibox.widget {
			{align = "left", widget = awful.titlebar.widget.titlewidget(c) },
			buttons = buttons,
			layout = wibox.layout.flex.horizontal,
		},
		control = wibox.widget {
			{
				awful.titlebar.widget.floatingbutton(c),
				awful.titlebar.widget.maximizedbutton(c),
				awful.titlebar.widget.stickybutton(c),
				awful.titlebar.widget.ontopbutton(c),
				spacing = dpi(4),
				layout = wibox.layout.fixed.horizontal()
			},
			wrap_widget_vmargin(bar),
			awful.titlebar.widget.closebutton(c),
			layout = wibox.layout.fixed.horizontal()
		},
	}

	awful.titlebar(c, {size = dpi(22)}) : setup {
		wrap_widget_hmargin(titlebar.icon),
		wrap_widget_hmargin(titlebar.title),
		wrap_widget_hmargin(titlebar.control),
		layout = wibox.layout.align.horizontal
	}
end)

-- Enable sloppy focus, so that focus follows mouse.
client.connect_signal("mouse::enter", function(c)
	if awful.layout.get(c.screen) ~= awful.layout.suit.magnifier
		and awful.client.focus.filter(c) then
		client.focus = c
	end
end)

client.connect_signal("request::activate", function (c)
	c:raise()
end)
client.connect_signal("focus", function (c) c.border_color = beautiful.border_focus end)
client.connect_signal("unfocus", function (c) c.border_color = beautiful.border_normal end)
client.connect_signal("property::size", adjust_client_border)
-- }}}

-- {{{ Startup
root.keys(globalkeys)
set_wallpaper()
-- }}}
