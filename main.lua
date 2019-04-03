
-- thread: https://love2d.org/forums/viewtopic.php?f=4&t=79784
-- base code by zorg, some pieces from lua user wiki

--[[
this utility is useful for testing out new things and getting those programmatic graphics juuust right. it was made with syntactic compatibility in mind, but is NOT intended for full game development, unless it doesn't conflict with your libraries* which it probably will.

* particularly gamestate ones. though if the lib allows states to run in parallel, it might be possible to get it working.
]]--

--[[game code goes in reloaded.lua and notreloaded.lua.]]--
--[[ r - reload all  s - save currently selected image ]]--

--  prio:
-- 1. instant code reloading (update, draw) without variable reloading (load) - DONE but in a really shitty way. sometimes doesn't reload... good thing it's abstracted away to M.reload(path) -- think I fixed it, now might reload twice but that's ok probably. tested:kinda, reloads a whole bunch of times but looks like it makes sure it always reloads properly now. remove the "times" counter cuz it might overflow if reloaded a lot. maybe optimize later
-- 1.5. image loading - DONE
-- 1.6. get rid of globals - DONE. fucking lua
-- 1.7. custom load - DONE, necessary for #2
-- 1.8. make files look cleaner - DONE
-- 2. instant image reloading - DONE but EXTREMELY HACKY D: make usage syntax more sane! -- YESSSS I DID IT *happy dance* ...it might fail if named keys are read in arbitrary order OTL gonna probably use http://lua-users.org/wiki/OrderedTable -- YEEEEEEEEEEEEEEEE DONE
-- 3. on demand load reloading -- DONE but in a shitty way that continually reloads when key is held
-- 3.1. reload-enabled error handler (copy errhand from sandbox when done) -- crashes at smaller interval when sleep is longer..? wtfux -- removed sleep, now it eats up cpu but works so DONE but not really
-- 3.2. separate loading of assets from variable inits -- possibly by putting asset loads at the top of reloaded.lua -- WORKS
-- 3.5. instant imagedata reloading (probably required for below) -- also required for placeholders -- check if image metadata exists. if not, the image is created from imagedata
-- 3.5. instant reloading of canvases and composite images that use reloaded images -- eg. Spine objects
-- 3.6. instant reloading of fonts
-- 4. image editing https://love2d.org/wiki/ImageData:encode -- kooltool does this, but not too well  https://love2d.org/forums/viewtopic.php?f=5&t=78534 http://ragzouken.itch.io/kooltool http://forum.makega.me/t/kooltool-game-doodling-tool/1112 -- will need z-ordering to select stuff... -- z-ordering is DONE! next up, detect if the mouse is in a rotated rectangular area that corresponds to image area. http://stackoverflow.com/questions/217578/point-in-polygon-aka-hit-test/2922778#2922778 https://www.love2d.org/forums/viewtopic.php?t=79559&p=179487 -- non-rotated rectangle area hover DONE, rotated shits can wait. into a separate point they go. time for some canvas! -- click selection is DONE and backed up. housekeeping (selection, etc) code will be abstracted from canvas painter code -- writing edits back to file - http://stackoverflow.com/questions/10386672/reading-whole-files-in-lua http://www.lua.org/pil/21.2.2.html Binary Files -- DONE prototyping the writeback! -- I DID IT! DONE -- just one minor detail, clear the canvases after saving so that the same strokes don't draw multiple times -- DONE -- there's still some premultiplication artifacts sometimes but w/e, it's for rough sketching -- drawing on rotated canvas DONE
-- 4.0.0.5. separate the editing into an edit mode so that mouse controls can be tested when making a game
-- 4.0.1. abstracted UXful paint tool -- abstraction DONE, now just gotta get it to paint -- DONE with some variables not handled, like rotation -- it can erase now!
-- 4.0.2. all instances of the same image get selected, drawing continues into them -- maybe optional?
-- 4.0.5. rotated and ox/oy-enabled area hover detection -- highlight DONE, proper hover detection left
-- 4.1. abstract gui code away from reloaded.lua -- DONE
-- 4.2. saving back to original image file's directory -- possibly using lua's built-in filesystem stuff -- DONE
-- 4.2.1. asset backup before editing
-- 4.2.2. ability to edit image layer
-- 4.2.5. save all
-- 4.5. undo function
-- 5. instant reloading of audio
-- 6. placeholders -- when first parameter of love.graphics.draw is a number (all params being (x,y,rot,w,h)), draw an editable blank placeholder that's made visible by the gui -- scratch that. use placeholdme method. make the first param the filename to save the image to, and if it exists, load the image from -- DONE
-- 7. enableable random keypress generator (takes set of keys as arg) for testing player sprite animations
-- ?. fs watching without polling
-- ?. maybe do update and draw the same way as load (like my.update)
-- ?. integrated animation editing, stopping (using the modified anim lib)
-- ?. integrated states
-- ?. move reloader call and gui call from reloaded.lua to a nest function


local M = {}
local name2 = "notreloaded"
local filename2 = name2..".lua"
local M2 = require( name2 )
local T = require( "tableUtils" )
M2.lastModified = 0
M2.times = 0

M2.images = T.orderedTable {} -- image objects
M2.drawOrder = {} -- ordered list of drawn images, represented as indexed in M2.images (eg. 1, 1, 5, 2). it gets reset every frame
M.imageMetadata = {}

local filename = "reloaded.lua"

-- abstracted libs --
M2.placeholdme = require 'placeholdme'
--local input = require 'input/input'


local function readAll(file)
    local f = io.open(file, "rb")
    local content = f:read("*all")
    f:close()
    return content
end

local function saveToSameDir(filename, imagedata)
	print("saving")
	local dir = love.filesystem.getSaveDirectory( )
	
	-- make sure getRealDirectory returns the game dir and not appdata
	love.filesystem.remove( "main.lua" )

	local realdir = love.filesystem.getRealDirectory( "main.lua" )
	print(dir.."\n"..realdir)
	imagedata:encode( filename ) -- write to appdata

	local filecontent = readAll( dir .. "/" .. filename )
	--print(filecontent)

	love.filesystem.remove( filename ) -- clean up

	local out = io.open(realdir.."/"..filename, "wb")
	--local str = string.char(72,101,108,108,111,10) -- "Hello\n"
	out:write(filecontent)
	out:close()
	
end

-- override image loading function for later reloading --
function M.newImage(arg, arg2, arg3)
	if arg2 == "is placeholder" then -- placeholdme passes arg2 and arg3. a bit ugly but whatev.
		M.imageMetadata[#M.imageMetadata+1] = {lastModified=os.time(), filename=arg3, fromData=true, fromPlaceholder=true}
		saveToSameDir(arg3, arg)
		
	else
		if type(arg) == "string" then
		--print("arg is string")
			M.imageMetadata[#M.imageMetadata+1] = {lastModified=os.time(), filename=arg, fromData=true}
			else -- imagedata
			M.imageMetadata[#M.imageMetadata+1] = 1 -- skip it
		end
	end
		--table.insert(M.imageMetadata, {lastModified=os.time(), filename = arg})
	return M.oldNewImage(arg)
end
M.oldNewImage = love.graphics.newImage
love.graphics.newImage = M.newImage


-- override drawing function to know order for live editing --
function M.draw(...)
	local arg = {...}
	--print(arg[1])
	if type(arg[2]) == "number" then -- not quad
		
		local img_id
		local metadataindex = 1
		for i,v in T.ordered(M2.images) do -- find which image this is
			if v == arg[1] then
			img_id = i
				--print(i)
				-- put index and coords in M2.drawOrder
				table.insert( M2.drawOrder, {i, arg[2],arg[3], arg[4] or 0, arg[1]:getWidth(),arg[1]:getHeight(), arg[7],arg[8], arg[5],arg[6], meta=metadataindex} ) -- index, x, y, rot, w, h, ox, oy, scale, metadata id
			end
			metadataindex=metadataindex+1
		end
		
		M.oldDraw( unpack(arg) ) -- draw the image
		
		if M2.canvese[img_id] then
			love.graphics.setBlendMode('premultiplied')
			M.oldDraw(M2.canvese[img_id][1][1],arg[2],arg[3],arg[4],arg[5],arg[6],arg[7],arg[8],arg[9]) -- draw its overlayers (just one for now)
			love.graphics.setBlendMode('alpha')
		end
		
	else -- quad
		
		-- leaving this for now...
		
		M.oldDraw( unpack(arg) )
	end
end
M.oldDraw = love.graphics.draw
love.graphics.draw = M.draw

function initcanvas(clickSelected)
	M2.canvese[clickSelected[1]] = {{}, clickSelected[2], clickSelected[3], clickSelected[4]} -- layers, coords, rotation
	M2.canvese[clickSelected[1]][1][1] = love.graphics.newCanvas(clickSelected[5],clickSelected[6]) -- first layer -- makes a short flash sometimes for some reason...
	love.graphics.setCanvas(M2.canvese[clickSelected[1]][1][1])
	local r, g, b, a = love.graphics.getBackgroundColor( )
	love.graphics.setBackgroundColor(0,0,0,0)
	M2.canvese[clickSelected[1]][1][1]:clear( ) -- make it transparent
	--M2.canvese[clickSelected[1]][1][1]:clear( 255, 255, 255, 255 )
	--love.graphics.rectangle( "fill",0, 0, 50, 50 ) -- test
	love.graphics.setCanvas()
	love.graphics.setBackgroundColor(r,g,b,a)
	--print("created") -- test
end


function love.load()
   M2.lastModified = os.time()
   --M.filesString = M.recursiveEnumerate("", "", M.assets) ---test
   
   M2.load()
   M2.reload(filename)
end

local function printError(chunk)
	local oldr,oldg,oldgb = love.graphics.getColor()
	local oldbgr,oldbgg,oldbgb = love.graphics.getBackgroundColor()
	love.graphics.setBackgroundColor(0,0,0)
	love.graphics.setColor(255,255,255)
	love.graphics.clear()
	love.graphics.print("exec. error: " .. chunk .. "\nSaving the file will trigger an automatic retry", 40, 40)
	love.graphics.setBackgroundColor(oldbgr, oldbgg, oldbgb)
	love.graphics.setColor(oldr, oldg, oldgb)
end

function M2.reload(path)
   local result, chunk
   result, chunk = pcall(love.filesystem.load, path)
   if not result then 
		--print("exec. error: " .. chunk) 
		-- replace love.draw with love.draw + an error message (or just error 	message?)
		love.draw = function()
			printError(chunk)
			end
   return false end
   result, chunk = pcall(chunk)
   if not result then
		--print("exec. error: " .. chunk) 
		-- replace love.draw with love.draw + an error message (or just error 	message?)
		love.draw = function()
			printError(chunk)
		end
   return false end
   return true
end

function M2.reloader()
	-- code reloading --
	if love.filesystem.getLastModified(filename) >= M2.lastModified then 
		--print(love.filesystem.getLastModified(filename).." "..M2.lastModified.." "..type(love.filesystem.getLastModified(filename)))
		if M2.reload(filename) then
			M2.times= M2.times+1
		end
		M2.lastModified = os.time()
	end
	--print(M.imageMetadata["hamster.png"].filename)
	-- image reloading --
	local j=1
	for i,v in T.ordered(M2.images) do
	
	-- detect modifications and reload --
	
	--print("j: "..j)
		--if not M.imageMetadata[j].filename:typeOf("ImageData") then
		--if type(M.imageMetadata[j].filename) == "string" then
		if (not (M.imageMetadata[j] == 1)) and (love.filesystem.exists(M.imageMetadata[j].filename)) then 
			if love.filesystem.getLastModified(M.imageMetadata[j].filename) >= M.imageMetadata[j].lastModified then 
				--v.object:refresh()
				--v.object = M.oldNewImage(v.filename)
				M2.images[i] = M.oldNewImage(M.imageMetadata[j].filename)
				--local data = M2.images[i]:getData()
				--data = love.image.newImageData( v.filename )
				--M2.images[i]:refresh()
				M2.times= M2.times+1
				M.imageMetadata[j].lastModified = os.time()
			end
		else -- it's from imagedata. get filename from imagedataMetadata
			
		end
		j=j+1
		
		
	end
	

    -- reload if r is being pressed -- should be if released
	if love.keyboard.isDown("r") then
		love.load()
   end

	
end

function M.isempty(s)
  return s == nil or s == ''
end



-- gives error otherwise, idk why
function love.quit()
  love.event.quit()
end

function love.errhand(msg)

if not love.window or not love.graphics or not love.event or not love.filesystem then
		return
	end
	
	-- Reset state.
	if love.mouse then
		love.mouse.setVisible(true)
		love.mouse.setGrabbed(false)
	end
	if love.joystick then
		for i,v in ipairs(love.joystick.getJoysticks()) do
			v:setVibration() -- Stop all joystick vibrations.
		end
	end
	if love.audio then love.audio.stop() end
	
  love.graphics.reset()
  love.graphics.origin()
  love.graphics.setBackgroundColor(40,40,40)
  love.graphics.setColor(255,255,255)
  M2.lastModified = love.filesystem.getLastModified(filename)
  while true do
        love.event.pump()

        for e, a, b, c in love.event.poll() do
            if e == "quit" then
                return
            end
            if e == "keypressed" and a == "escape" then
                return
			end
			if e == "keypressed" and a == "r" then -- mod starts here
				if M2.lastModified ~= love.filesystem.getLastModified(filename) 	then
						M2.lastModified = love.filesystem.getLastModified(filename)
						--love.filesystem.load('main.lua')()
						--love.run()
						love.graphics.reset()
						M2.reload("main.lua")
						M2.reload(filename2)
						love.load()
						M2.reload(filename)
						love.run()
						love.graphics.setBackgroundColor(89, 157, 220)
							love.graphics.setColor(255,255,255)
						--love.load()
						--M2.reload(filename) -- and ends here.
					end
				end
			end

love.graphics.clear()

  love.graphics.print(debug.traceback(),40,400)
  love.graphics.print(msg,4,100)
  --love.graphics.print("press 'r' to reload",4,20)
  love.graphics.present()
  
  if M2.lastModified ~= love.filesystem.getLastModified(filename) 	then
  print("fffffff")
						M2.lastModified = love.filesystem.getLastModified(filename)
						--love.filesystem.load('main.lua')()
						--love.run()
						love.graphics.reset()
						M2.reload("main.lua")
						M2.reload(filename2)
						love.load()
						M2.reload(filename)
						love.run()
						love.graphics.setBackgroundColor(89, 157, 220)
							love.graphics.setColor(255,255,255)
						--love.load()
						--M2.reload(filename) -- and ends here.
	end

        if love.timer then
            --love.timer.sleep(0.4)
        end
    end

end


--[[
local oldDraw = love.graphics.draw
local newDraw = function()
	
	
	
	
end]]
--love.graphics.draw = newDraw




--[[my.assetFormats = {"png","json"} -- files of these extensions will be reloaded when modified. remove after prototyping 

-- This function will return a string filetree of all files
-- in the folder and files in all subfolders
-- I added: put all non-lua filenames in a table
function M.recursiveEnumerate(folder, fileTree, returnNonlua)
    local lfs = love.filesystem
    local filesTable = lfs.getDirectoryItems(folder)
    for i,v in ipairs(filesTable) do
        local file = folder.."/"..v
        if lfs.isFile(file) then
            fileTree = fileTree.."\n"..file
			--fileObject = love.filesystem.newFile(file)
			--for i,v in ipairs(ImageFormat) do
			local ext = M.getExtension(file)
			fileTree = fileTree.." ext:"..ext
			--if M.tableContains(M.assetFormats, ext) then --do not remove
			if ext ~= "lua" then
				fileTree = fileTree.." (reloadable asset)"
				table.insert(returnNonlua, file)
			end
        elseif lfs.isDirectory(file) then
            fileTree = fileTree.."\n"..file.." (DIR)"
            fileTree = M.recursiveEnumerate(file, fileTree)
        end
    end
    return fileTree
end


function M.getExtension(filepath)
	return string.match(filepath, "^.*%.(.*)$")
end]]--




--local function show(t)
 -- for k, v in ordered(t) do print(k, v) end
--end

local selected
local selected_k
local clickSelected
local clickSelected_k

M2.canvese = {}

local function ghettoMousereleased(k)
	
	if M2.wasdown == true and not love.mouse.isDown( "l" ) then -- released
		clickSelected = M2.drawOrder[k]
		clickSelected_k = k
	end
	
end

-- funcs for saving back to original image --

local function merge_and_save(img_id, metadata)
	local dir = love.filesystem.getSaveDirectory( )
	local filename
	if not (M.imageMetadata[metadata] == 1) then
		filename = M.imageMetadata[metadata].filename
	else -- imagedata
		
	end
	local canvasdata = M2.canvese[img_id][1][1]:getImageData() -- but get all the layers
	local canvasimage = love.graphics.newImage(canvasdata)
	
	local mergecanvas = love.graphics.newCanvas(M2.images[img_id]:getWidth(), M2.images[img_id]:getHeight())
	-- clear
	local r, g, b, a = love.graphics.getBackgroundColor( )
	love.graphics.setBackgroundColor(0,0,0,0)
	mergecanvas:clear( ) -- make it transparent
	love.graphics.setBackgroundColor(r,g,b,a)
	-- merge
	love.graphics.setCanvas(mergecanvas)
		love.graphics.setBlendMode('premultiplied')
		love.graphics.draw(M2.images[img_id])
		love.graphics.draw(canvasimage)
		love.graphics.setBlendMode('alpha')
	love.graphics.setCanvas()
	local imagedata = mergecanvas:getImageData()

	-- make sure getRealDirectory returns the game dir and not appdata
	love.filesystem.remove( "main.lua" )

	local realdir = love.filesystem.getRealDirectory( "main.lua" )
	print(dir.."\n"..realdir)
	imagedata:encode( filename ) -- write to appdata

	local filecontent = readAll( dir .. "/" .. filename )
	--print(filecontent)

	love.filesystem.remove( filename ) -- clean up

	local out = io.open(realdir.."/"..filename, "wb")
	--local str = string.char(72,101,108,108,111,10) -- "Hello\n"
	out:write(filecontent)
	out:close()
	
	-- clear canvas to prevent double draw
	love.graphics.setCanvas(M2.canvese[img_id][1][1])
	love.graphics.setBackgroundColor(0,0,0,0)
	M2.canvese[img_id][1][1]:clear( ) -- make it transparent
	love.graphics.setCanvas()
	love.graphics.setBackgroundColor(r,g,b,a)

end




local function initselect(k)
	selected = M2.drawOrder[k]
	ghettoMousereleased(k)
end


local draw = require "editor"

function M2.editorGui()
	
	
	for k in pairs (M2.drawOrder) do

		love.graphics.print(k.." - "..M2.drawOrder[k][1], M2.drawOrder[k][2], M2.drawOrder[k][3]) -- display draw order
		
		--[[local nvert = 4
		local j = nvert-1
		for i = 0; i < nvert; i++ do
			if  ((verty[i]>testy) ~= (verty[j]>testy)) and (testx < (vertx[j]-vertx[i]) * (testy-verty[i]) / (verty[j]-verty[i]) + vertx[i]) then -- if mouse over image then
				selected = M2.drawOrder[k]
			end
			j = i+1
		end]]
		
		
		if M2.drawOrder[k][4] ~= nil and M2.drawOrder[k][4] ~= 0 then -- has rotation
			if M2.drawOrder[k][7] or M2.drawOrder[k][8] then -- has offset
				if M2.rotated_rect_vs_pt2(M2.drawOrder[k][2]+M2.drawOrder[k][5]/2,M2.drawOrder[k][3]+M2.drawOrder[k][6]/2, M2.drawOrder[k][5]/2,M2.drawOrder[k][6]/2, M2.drawOrder[k][4], love.mouse.getX( ),love.mouse.getY( )) then
					initselect(k)
				end
			else -- no offset
				if M2.rotated_rect_vs_pt(M2.drawOrder[k][2],M2.drawOrder[k][3], M2.drawOrder[k][5],M2.drawOrder[k][6], M2.drawOrder[k][4], love.mouse.getX( ),love.mouse.getY( )) then
					initselect(k)
				end
			end
		else -- no rotation
			if M2.rect_vs_pt(M2.drawOrder[k][2],M2.drawOrder[k][3], M2.drawOrder[k][5],M2.drawOrder[k][6], love.mouse.getX( ),love.mouse.getY( )) then
				initselect(k)
			end
		end


		--M2.drawOrder[k] = nil -- IMPORTANT - reset for next frame
	end
	
	if M2.wasdown == true and not love.mouse.isDown( "l" ) and clickSelected then -- released
		print(clickSelected_k)
		--print(selected[2])
		--print(selected[3].. selected[4])
		if M2.canvese[clickSelected[1]] == nil then
			initcanvas(clickSelected)
		end
	end
	
	if clickSelected then
	-- highlight the selected image
		love.graphics.setColor(255,0,0,220)
		love.graphics.push()
		
		love.graphics.translate( M2.drawOrder[clickSelected_k][2], M2.drawOrder[clickSelected_k][3] )
		 -- x, y
		
		love.graphics.rotate( M2.drawOrder[clickSelected_k][4] or 0 ) -- rot
		
		love.graphics.scale(M2.drawOrder[clickSelected_k][9] or 1, M2.drawOrder[clickSelected_k][10] or M2.drawOrder[clickSelected_k][9] or 1) -- scale
		
		--love.graphics.translate( -(M2.drawOrder[clickSelected_k][7] or 0)/2, -(M2.drawOrder[clickSelected_k][8] or 0)/2 ) -- ox, oy
		love.graphics.translate( -(M2.drawOrder[clickSelected_k][7] or 0), -(M2.drawOrder[clickSelected_k][8] or 0) ) -- ox, oy
		
		love.graphics.rectangle( "line",0, 0, M2.drawOrder[clickSelected_k][5], M2.drawOrder[clickSelected_k][6] )
		love.graphics.pop()
		love.graphics.setColor(255,255,255)
	-- painter gui
		draw.onCanvas(M2.canvese[clickSelected[1]][1], M2.drawOrder[clickSelected_k][2], M2.drawOrder[clickSelected_k][3], M2.drawOrder[clickSelected_k][4], M2.drawOrder[clickSelected_k][9] or 1, M2.drawOrder[clickSelected_k][10] or M2.drawOrder[clickSelected_k][9] or 1, M2.drawOrder[clickSelected_k][7],M2.drawOrder[clickSelected_k][8])
	-- mouse control of painter
		if M2.wasdown == false and love.mouse.isDown( "l" ) then -- pressed
			print("draw.start()")
			draw.start()
		end
		if M2.wasdown == true and not love.mouse.isDown( "l" ) then -- released
			print("draw.stop()")
			draw.stop()
		end
		if M2.rwasdown == false and love.mouse.isDown( "r" ) then -- pressed
			print("draw.start_e()")
			draw.start_e()
		end
		if M2.rwasdown == true and not love.mouse.isDown( "r" ) then -- released
			print("draw.stop_e()")
			draw.stop_e()
		end
	-- keyboard control of painter
		if love.keyboard.isDown( draw.savekey ) == true then -- should be if released
			merge_and_save(clickSelected[1], clickSelected.meta)
		end
	end
	
	M2.wasdown = false
	M2.rwasdown = false
	
	
	if selected then
	-- draw rectangle at hover
		--[[
		translate(x, y);
		rotate(angle);
		scale(sx, sy);
		translate(-ox, -oy);
		]]
		
		if love.mouse.isDown("l") then
			love.graphics.setColor(255,255,255,220)
			M2.wasdown = true
		elseif love.mouse.isDown("r") then
			love.graphics.setColor(255,255,255,150)
			M2.rwasdown = true
		else

			love.graphics.setColor(255,255,255,150)
		
		end
		love.graphics.push()
		--love.graphics.translate( -(selected[7] or 0)/2, -(selected[8] or 0)/2 )
		--love.graphics.translate( selected[2]+(selected[5]/2 or 0), selected[3]+(selected[6]/2 or 0) )
		love.graphics.translate( selected[2], selected[3] )
		 -- x, y
		
		love.graphics.rotate( selected[4] or 0 ) -- rot
		
		love.graphics.scale(selected[9] or 1, selected[10] or selected[9] or 1) -- scale
		
		--love.graphics.translate( -(selected[7] or 0)/2, -(selected[8] or 0)/2 ) -- ox, oy
		love.graphics.translate( -(selected[7] or 0), -(selected[8] or 0) ) -- ox, oy
		
		love.graphics.rectangle( "line",0, 0, selected[5], selected[6] )
		love.graphics.pop()
		love.graphics.setColor(255,255,255)
	end
	selected = nil
	
	
	for k in pairs (M2.drawOrder) do
		M2.drawOrder[k] = nil -- IMPORTANT - reset for next frame
	end
	
	
end


 ---------- hover detection functions ----------

 -- "l", "t" being the top-left corner of the rectangle
-- "w", "h" being the width and height
-- "a" being the angle in radians
function M2.rotated_rect_vs_pt(l,t, w,h, a, px,py)
  local hw, hh = w/2, h/2
  -- find the center of the rect
  local rx, ry = math.cos(a)*hw + l, math.sin(a)*hh + t
  return M2.rotated_rect_vs_pt2(rx,ry, hw,hh, a, px,py)
end
 
 -- "rx","ry" being the center of the rectangle
-- "hw","hh being the half-width and height extents of the rectangle
-- "a" being the angle in radians
function M2.rotated_rect_vs_pt2(rx,ry, hw,hh, a, px,py)
	-- translate the point
	local dx, dy = rx - px, ry - py
	-- rotate the point
	local c, s = math.cos(a or 0), math.sin(a or 0)
	local lpx, lpy = c*dx - s*dy, s*dx + c*dy
	-- now the point in is in rect coords
	return not (lpx*lpx > hw*hw or lpy*lpy > hh*hh)
end

-- "l","t" being the left-top corner of the rectangle
-- "w","h" being the width and height
function M2.rect_vs_pt(l,t, w,h, px,py)
  return not (px < l or py < t or px > l + w or py > t + h)
end



 


