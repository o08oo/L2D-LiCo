-- this is the drawing module, separate from canvas management

local draw = {}

draw.drawing = false
draw.erasing = false

draw.brushsize = 4
draw.circlebrushsize = draw.brushsize/2
draw.brushcolor = {255, 0, 255}

draw.currentlayer = 1

function draw.onCanvas(canvas, x_offset, y_offset, rot, scalex, scaly, ox, oy) -- offsets are the canvas drawing coords
	
	x_offset = x_offset or 0
	y_offset = y_offset or 0
	ox = ox or 0
	oy = oy or 0
	scalex = scalex or 1
	scaley = scaley or 1
	
	draw.oldx, draw.oldy = draw.x, draw.y
	draw.x, draw.y = love.mouse.getPosition()
	draw.mouse_x, draw.mouse_y = love.mouse.getPosition()
	
	draw.y = draw.y - y_offset
	draw.x = draw.x - x_offset
	--draw.x = 0
	--draw.y = 0
	
	if draw.drawing == true then
		
		--[[love.graphics.push()
		
		love.graphics.translate( draw.x-x_offset, draw.y-y_offset )
		love.graphics.rotate( rot )
		love.graphics.scale(scalex, scaley)
		love.graphics.translate( -ox, -oy )]]
		
		love.graphics.setColor(draw.brushcolor)
		love.graphics.setCanvas(canvas[draw.currentlayer])
		
		if rot==0 and scalex==1 and scaly==1 then -- unscaled, unrotated image
			--print(canvas[draw.currentlayer])
			love.graphics.circle("fill", draw.oldx, draw.oldy, draw.circlebrushsize, draw.brushsize)
			love.graphics.setLineWidth( draw.brushsize )
			love.graphics.line(draw.oldx, draw.oldy, draw.x, draw.y)
			love.graphics.setLineWidth( 1 )
			love.graphics.circle("fill", draw.x, draw.y, draw.circlebrushsize, draw.brushsize)
		else -- oh crap
			local newpointx, newpointy = draw.rotatePointAroundPoint(canvas[draw.currentlayer]:getWidth()/2, canvas[draw.currentlayer]:getHeight()/2, rot, draw.x, draw.y) -- rotate
			
			newpointx = newpointx + ox 
			newpointy = newpointy + oy
			
			love.graphics.circle("fill", draw.oldx, draw.oldy, draw.circlebrushsize, draw.brushsize)
			love.graphics.setLineWidth( draw.brushsize )
			love.graphics.line(draw.oldx, draw.oldy, newpointx, newpointy)
			love.graphics.setLineWidth( 1 )
			love.graphics.circle("fill", newpointx, newpointy, draw.circlebrushsize, draw.brushsize)
			
			draw.x, draw.y = newpointx, newpointy -- so that it can be used as draw.oldx,draw.oldy later
		end
		
		love.graphics.setCanvas()
		love.graphics.setColor(255,255,255)
		
		--love.graphics.pop()
		
	end
	
	if draw.erasing == true then
		love.graphics.setColor(0,0,0,0)
		love.graphics.setBlendMode("replace")
		
		love.graphics.setCanvas(canvas[draw.currentlayer])
		--print(canvas[draw.currentlayer])
		love.graphics.circle("fill", draw.oldx, draw.oldy, draw.circlebrushsize, draw.brushsize)
		love.graphics.setLineWidth( draw.brushsize )
		love.graphics.line(draw.oldx, draw.oldy, draw.x, draw.y)
		love.graphics.setLineWidth( 1 )
		love.graphics.circle("fill", draw.x, draw.y, draw.circlebrushsize, draw.brushsize)
		
		love.graphics.setCanvas()
		
		love.graphics.setBlendMode("alpha")
		love.graphics.setColor(255,255,255)
	end
	
	-- mouse coords
	love.graphics.print("X:"..draw.mouse_x, 10, 10)
	love.graphics.print("Y:"..draw.mouse_y, 10, 40)
	
	-- Draws A brush That Follows The Mouse
	love.graphics.circle("line", draw.mouse_x, draw.mouse_y, draw.circlebrushsize, draw.brushsize)
	
end

-- Mouse control --
function draw.start() -- when mouse pressed
draw.drawing = true
end
function draw.stop() -- when mouse released
draw.drawing = false
end

function draw.start_e() -- when r mouse pressed
draw.erasing = true
end
function draw.stop_e() -- when r mouse released
draw.erasing = false
end


draw.savekey = 's' -- key for saving the resulting rasterized image (and clearing layers, at least for now)


function draw.rotatePointAroundPoint(cx, cy, angle, px, py) -- cx,cy is pivot point, px,py is unrotated point

  local s = math.sin(angle)
  local c = math.cos(angle)

  -- translate point back to origin:
  local px2 = px - cx
  local py2 = px - cy

  -- rotate point
  local xnew = px2 * c - py2 * s
  local ynew = px2 * s + py2 * c

  -- translate point back:
  px2 = xnew + cx
  py2 = ynew + cy
  return px2, py2
  
end



return draw