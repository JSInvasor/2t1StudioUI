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
	search      = 72296609649861,   -- lucide: search
	command     = 90385430770591,   -- lucide: command
	users       = 85332511060401,   -- lucide: users
	bell        = 84691420588185,   -- lucide: bell
	grid        = 134599229810680,   -- lucide: grid-3x3
	palette     = 127369887384101,   -- lucide: palette
	settings    = 106205298246017,   -- lucide: settings
	gear        = nil,   -- lucide: settings-2
	wrench      = 85345725497834,   -- lucide: wrench
	layers      = 114499998778667,   -- lucide: layers
	layout      = 70433574792490,   -- lucide: layout-dashboard
	keyboard    = 121978468376124,   -- lucide: keyboard
	terminal    = 102379915564176,   -- lucide: terminal
	chevronup   = 73746166761985,   -- lucide: chevron-up
	chevrondown = 112517617090898,   -- lucide: chevron-down
	cornerright = 82061714010896,   -- lucide: corner-down-right
	check       = 101885204738917,   -- lucide: check
	x           = 111132030834422,   -- lucide: x
	info        = 120620848266512,   -- lucide: info
	alert       = 74115333842618,   -- lucide: alert-circle
	refresh     = 112330254035751,   -- lucide: refresh-cw
	trash       = 126010725826757,   -- lucide: trash-2
	copy        = 116378866141355,   -- lucide: copy
	sparkles    = 105634041692696,   -- lucide: sparkles

	-- ========== element decoration ==========
	toggleon    = 129483325318573,   -- lucide: toggle-right
	sliders     = 125396339381135,   -- lucide: sliders-horizontal
	list        = 101699539545687,   -- lucide: list
	type        = 70694319369829,   -- lucide: type
	box         = 117371753006597,   -- lucide: box
	move        = 77028714324861,   -- lucide: move
	filter      = 100930784445785,   -- lucide: filter
	save        = 122894934359450,   -- lucide: save
	edit        = 97622550721067,   -- lucide: pencil
	link        = 86131768436965,   -- lucide: link
	download    = 122841052352556,   -- lucide: download
	upload      = 121807815408739,   -- lucide: upload
	lock        = 119765975153029,   -- lucide: lock
	unlock      = 110263656507369,   -- lucide: unlock
	clock       = 136533241128438,   -- lucide: clock
	star        = 72669221096319,   -- lucide: star
	heart       = 88525382655929,   -- lucide: heart
	bookmark    = 137439152875860,   -- lucide: bookmark
	arrowright  = 134908902120212,   -- lucide: arrow-right
	arrowleft   = 90293255250749,   -- lucide: arrow-left
	arrowupdown = 73746166761985,   -- lucide: arrow-up-down
	plus        = 117262167984222,   -- lucide: plus
	minus       = 95070996149109,   -- lucide: minus
	dot         = 105006331197983,   -- lucide: dot
	circle      = nil,   -- lucide: circle
	package     = 106101842173393,   -- lucide: package

	-- ========== combat and targeting ==========
	sword       = 99199363807265,   -- lucide: sword
	shield      = 106509993556171,   -- lucide: shield
	crosshair   = 83752373575368,   -- lucide: crosshair
	target      = 121091323240554,   -- lucide: target
	scan        = 125367266780285,   -- lucide: scan
	radar       = 132868138496209,   -- lucide: radar
	skull       = 101060850237115,   -- lucide: skull
	zap         = 109718589733073,   -- lucide: zap
	flame       = 125012650497883,   -- lucide: flame

	-- ========== vision ==========
	eye         = 127234874352422,   -- lucide: eye
	eyeoff      = 85207295981701,   -- lucide: eye-off
	sun         = 139232691165198,   -- lucide: sun
	moon        = 98353636264918,   -- lucide: moon

	-- ========== player and world ==========
	user        = 114567720540659,   -- lucide: user
	home        = 109841253338329,   -- lucide: home
	run         = nil,   -- lucide: footprints
	activity    = 137527339160230,   -- lucide: activity
	compass     = 73836660434977,   -- lucide: compass
	globe       = 125685532120024,   -- lucide: globe
	puzzle      = 117598556369229,   -- lucide: puzzle
}
