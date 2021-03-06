
-- modified version of placeholdme by EntranceJew
-- todo:
-- take filename as param for saving and reloading image
-- add optional forced new placeholder creation even if file exists

-- a lib to generate placeholder images
local placeholdme = {}

-- from: http://lua-users.org/wiki/StringInterpolation
local function interp(s, tab)
	return (s:gsub('%%%((%a%w*)%)([-0-9%.]*[cdeEfgGiouxXsq])',
			function(k, fmt) return tab[k] and ("%"..fmt):format(tab[k]) or
				'%('..k..')'..fmt end))
end
-- refer to: https://docs.python.org/2/library/stdtypes.html#string-formatting if confused

-- from: https://github.com/rxi/lume/#lumemerge
local function tableMerge(t, t2, retainkeys)
	for k, v in pairs(t2) do
		t[retainkeys and k or (#t + 1)] = v
	end
	return t
end

local function newPlaceHolder(self, filename, width, height, columns, rows, sprintstring, sprintvars, fontcolor, fillcolor)
	love.filesystem.remove( filename ) -- make sure an irrelevant file is not preventing placeholder creation
	if love.filesystem.exists(filename) then
		return love.graphics.newImage(filename)
	end
	
	if type(width) == 'table' then
		height = width.height
		columns = width.columns
		rows = width.rows
		sprintstring = width.sprintstring
		sprintvars = width.sprintvars
		fontcolor = width.fontcolor
		fillcolor = width.fillcolor
		
		-- do this last so we don't overwrite the table
		width = width.width
	end
	columns = columns or 1
	rows = rows or 1
	sprintstring = sprintstring or "%(defstring)s\n%(width)sx%(height)s \n%(column)s,%(row)s"
	if type(sprintvars) == 'string' then
		sprintvars = {defstring = sprintvars}
	elseif type(sprintvars) ~= 'table' then
		sprintvars = {defstring = 'placeholder'}
	end
	fontcolor = fontcolor or {255, 255, 255, 255}
	fillcolor = fillcolor or {128, 128, 128, 255}
	--[[
		valid vars:
			column	column number of frame
			row		row number of frame
			width	frame width
			height	frame height
	]]
	local prefont = love.graphics.getFont()
	local precolor = {love.graphics.getColor()}
	local precanvas = love.graphics.getCanvas()
	local iData = love.image.newImageData(width*columns, height*rows)
	local canvas = love.graphics.newCanvas(width, height)
	
	love.graphics.setCanvas(canvas)
	-- make it transparent
	local r, g, b, a = love.graphics.getBackgroundColor( )
	love.graphics.setBackgroundColor(255,255,255,0)
	canvas:clear( )
	
	
	
	for h=1,rows do
		for w=1,columns do
			-- fill
			--canvas:clear(fillcolor)
			
			canvas:clear(255,255,255,0)
			
			-- do the text
			--[[love.graphics.setColor(fontcolor)
			local providedVars = {column=w, row=h, width=width, height=height}
			local str2sprint = interp(sprintstring, tableMerge(providedVars, sprintvars, true))]]
			
			-- vertically center it, draw
			--[[local _, nolines = prefont:getWrap(str2sprint, width)
			-- the height of a line * lines, divided amongst the area available
			local drawy = (height-prefont:getHeight()*nolines)/2
			love.graphics.printf(str2sprint, 0, drawy, width, "center")]]
			
			-- draw rectangle
			love.graphics.setColor(0,0,0,150)
			love.graphics.rectangle("fill",0,0,width,height)
			love.graphics.setColor(255,255,255)
			love.graphics.rectangle("line",0,0,width,height)
			
			-- print sprite number 
			love.graphics.setColor(255,255,255)
			love.graphics.printf(w..", "..h, 0, height/2-prefont:getHeight()/2, width, "center")
			
			-- put the canvas on the master image
			local canvasData = canvas:getImageData()
			iData:paste(canvasData, width*(w-1), height*(h-1), 0, 0, width, height)
		end
	end
	
	-- reset the graphical state
	love.graphics.setBackgroundColor(r,g,b,a)
	love.graphics.setCanvas(precanvas)
	love.graphics.setColor(precolor)
	--return iData
	return love.graphics.newImage(iData, "is placeholder", filename)
end

local metaTable = {
	__call = newPlaceHolder
}

setmetatable(placeholdme, metaTable)

return placeholdme