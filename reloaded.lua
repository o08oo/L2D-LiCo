
local my = require( "notreloaded" )

--my.images = {} -- uncomment when done

-- assets can be loaded outside of a load function to improve workflow.
my.images.hamster = love.graphics.newImage("hamster.png") -- for images to reload, put them in my.images and pass the filename (not imagedata)
my.images.star = love.graphics.newImage("star.png")

-- placeholdme test
my.images.placeholder1 = my.placeholdme("ph-image.png",100,50,3,4)


love.graphics.setBackgroundColor(55,55,55)

function love.update(dt)
	my.reloader() --<-- live reloader function needed for live coding to work. remove after prototyping
  
  my.cake = my.cake + 100*dt -- test preserved var
  
end

function love.draw()

	--asddfdfs -- error test

    love.graphics.print('Hello Wosasadssssddfssffffasd!', 300, 300)
	love.graphics.print("last: "..my.lastModified.."    modified "..my.times.." times", 300, 200)
	love.graphics.rectangle("fill", 300, 400, 60, 160 )
	
	--[[
	love.graphics.draw(my.images.hamster, 300, 90, my.cake/20, 1.5, 1.5, my.images.hamster:getWidth(), my.images.hamster:getHeight())
	love.graphics.draw(my.images.star, my.cake, 90, my.cake/20, 1.5, 1.5, 20, 20)
	love.graphics.draw(my.images.hamster, 500, 100, my.cake/30)
	love.graphics.draw(my.images.hamster, 500, 200)
	love.graphics.draw(my.images.star, 400, 110, my.cake/20, 1.5, 1.5, my.images.star:getWidth()/2, my.images.star:getHeight()/2)
	]]--
	
	love.graphics.print("preserved: "..my.cake, 50, 400)
	
	--love.graphics.print(my.filesString, 0, 0)
	
	-- placeholdme test
	love.graphics.draw(my.images.placeholder1, 100, 250)
	
	
	
	my.editorGui() --<-- what it says on the tin. it should remain at the end of love.draw(). remove after prototyping
end


function love.mousereleased(x, y, button)
   if button == "l" then
      --my.cake = 0
   end
end
