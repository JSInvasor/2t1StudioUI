--[[
	2t1 Studio - Icon Pack

	HOW TO FILL THIS IN
	  1. open  https://icons.rest
	  2. search the Lucide name shown in the comment on each line
	  3. copy the asset id and paste it in place of the nil

	You do not have to fill in all of them. Any line left as nil falls back
	to the built-in vector icon, so the interface never breaks half-finished.
	Fill in the ones you look at most and leave the rest for later.

	Format is just the number. Both of these work:
	  gear = 1234567890,
	  gear = "rbxassetid://1234567890",

	Then point the library at this file:
	  local Pack = loadstring(game:HttpGet(".../icons.lua"))()
	  Library:LoadIconPack(Pack)

	Run  Library:VerifyIcons()  afterwards and the console prints which ids
	loaded and which did not.
]]

return {

	-- ========== used by the interface chrome ==========
	-- these show up the most, worth doing first
	search      = nil,   -- lucide: search
	command     = nil,   -- lucide: command
	users       = nil,   -- lucide: users
	bell        = nil,   -- lucide: bell
	grid        = nil,   -- lucide: grid-3x3
	palette     = nil,   -- lucide: palette
	settings    = nil,   -- lucide: settings
	gear        = nil,   -- lucide: settings-2
	wrench      = nil,   -- lucide: wrench
	layers      = nil,   -- lucide: layers
	layout      = nil,   -- lucide: layout-dashboard
	keyboard    = nil,   -- lucide: keyboard
	terminal    = nil,   -- lucide: terminal
	chevronup   = nil,   -- lucide: chevron-up
	chevrondown = nil,   -- lucide: chevron-down
	cornerright = nil,   -- lucide: corner-down-right
	check       = nil,   -- lucide: check
	x           = nil,   -- lucide: x
	info        = nil,   -- lucide: info
	alert       = nil,   -- lucide: alert-circle
	refresh     = nil,   -- lucide: refresh-cw
	trash       = nil,   -- lucide: trash-2
	copy        = nil,   -- lucide: copy
	sparkles    = nil,   -- lucide: sparkles

	-- ========== element decoration ==========
	toggleon    = nil,   -- lucide: toggle-right
	sliders     = nil,   -- lucide: sliders-horizontal
	list        = nil,   -- lucide: list
	type        = nil,   -- lucide: type
	box         = nil,   -- lucide: box
	move        = nil,   -- lucide: move
	filter      = nil,   -- lucide: filter
	save        = nil,   -- lucide: save
	edit        = nil,   -- lucide: pencil
	link        = nil,   -- lucide: link
	download    = nil,   -- lucide: download
	upload      = nil,   -- lucide: upload
	lock        = nil,   -- lucide: lock
	unlock      = nil,   -- lucide: unlock
	clock       = nil,   -- lucide: clock
	star        = nil,   -- lucide: star
	heart       = nil,   -- lucide: heart
	bookmark    = nil,   -- lucide: bookmark
	arrowright  = nil,   -- lucide: arrow-right
	arrowleft   = nil,   -- lucide: arrow-left
	arrowupdown = nil,   -- lucide: arrow-up-down
	plus        = nil,   -- lucide: plus
	minus       = nil,   -- lucide: minus
	dot         = nil,   -- lucide: dot
	circle      = nil,   -- lucide: circle
	package     = nil,   -- lucide: package

	-- ========== combat and targeting ==========
	sword       = nil,   -- lucide: sword
	shield      = nil,   -- lucide: shield
	crosshair   = nil,   -- lucide: crosshair
	target      = nil,   -- lucide: target
	scan        = nil,   -- lucide: scan
	radar       = nil,   -- lucide: radar
	skull       = nil,   -- lucide: skull
	zap         = nil,   -- lucide: zap
	flame       = nil,   -- lucide: flame

	-- ========== vision ==========
	eye         = nil,   -- lucide: eye
	eyeoff      = nil,   -- lucide: eye-off
	sun         = nil,   -- lucide: sun
	moon        = nil,   -- lucide: moon

	-- ========== player and world ==========
	user        = nil,   -- lucide: user
	home        = nil,   -- lucide: home
	run         = nil,   -- lucide: footprints
	activity    = nil,   -- lucide: activity
	compass     = nil,   -- lucide: compass
	globe       = nil,   -- lucide: globe
	puzzle      = nil,   -- lucide: puzzle
}
