
-- game var initializations and love.load(). after prototyping, they may be declared and stored in another manner --

local my = {} -- everything in here will be preserved between reloads

function my.load() -- after prototyping, rename as love.load() and move to same file as love.update and love.draw

-- vars can be reloaded on demand by pressing 'r' if declared here --
my.cake = 0


end

return my