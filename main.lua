-- The shader that creates a lightmap out of the visible triangles
-- origin: the position the light source is at
-- radius: the maximum distance of the light
-- falloff: the distance from where the intensity of the light drops
local light = love.graphics.newShader([[

    extern vec2 origin;
    extern float radius;
    extern float falloff;
    extern vec3 clr;

    vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords)
    {
        float alpha = 1.0;

        float dist = distance(origin, screen_coords);   // Distance from the current pixel to the origin (player)

        // The following makes sure you don't use a shorter radius than falloff
        float safeFalloff= falloff;

        if (falloff > radius) {
            safeFalloff = radius;
        }

        if (dist > safeFalloff) {
            alpha = (radius - dist)/(radius - safeFalloff);
        }

        return vec4(clr.r, clr.g, clr.b, alpha);
    }

]])

bgSource = love.graphics.newImage("assets/tiles.png")
bgSource:setWrap("repeat", "repeat")
bgQuad = love.graphics.newQuad(0, 0, 800, 600, bgSource:getWidth(), bgSource:getHeight())

-- The canvas on which the lightmap will be drawn
--love.graphics.setDefaultFilter("nearest", "nearest")
local lightmap = love.graphics.newCanvas()

-- The "player" which is also our light source
local player = {
    x = 400,
    y = 300
}

local newEdge = {
    x1 = 0, y1 = 0, x2 = 0, y2 = 0, draw = false
}

-- All the edges of our world
local edges = {

    -- These are the borders of the level
    { x1 = 10, y1 = 10, x2 = 790, y2 = 10 },
    { x1 = 10, y1 = 590, x2 = 790, y2 = 590 },
    { x1 = 10, y1 = 10, x2 = 10, y2 = 590 },
    { x1 = 790, y1 = 10, x2 = 790, y2 = 590 }
}

-- The polygon which represents the visible area
local visiblePolygon = {}
local aPolygon = {}

-- The main attraction: this function calculates the visible area in form of a polygon
function calculateVisiblePolygon(originX, originY, radius)

    local areaTable = {}
    local triangles = {}

    -- Iterate over every edge
    for _, edge1 in ipairs(edges) do

        -- Do this for the start point and the end point
        for i = 1, 2 do

            local rdx, rdy = nil
            if i == 1 then 
                rdx, rdy = edge1.x1-originX, edge1.y1-originY
            else
                rdx, rdy = edge1.x2-originX, edge1.y2-originY
            end

            local baseAngle = math.atan2(rdy, rdx)
            local ang = 0

            -- cast three slighlty different Rays
            for j = -1, 1 do

                ang = baseAngle + j * 0.0001

                -- Create a ray along the angle with the radius as distance
                rdx = math.cos(ang) * radius
                rdy = math.sin(ang) * radius

                local min_t1 = 1/0 -- infinity
                local min_px = 0
                local min_py = 0
                local min_ang = 0
                local valid = false

                -- Check for intersections with every edge
                for _, edge2 in ipairs(edges) do

                    -- create vector of current edge
                    local edgeVectorX = edge2.x2 - edge2.x1
                    local edgeVectorY = edge2.y2 - edge2.y1

                    -- Check that Edge and Ray are not on the same line
                    if edgeVectorX - rdx ~= 0 and edgeVectorY - rdy ~= 0 then

                        -- t2 = distance from startpoint to intersection point (0-1)
                        local t2 = (rdx * (edge2.y1 - originY) + (rdy * (originX - edge2.x1))) / (edgeVectorX * rdy - edgeVectorY * rdx)
                        -- t1 = distance from source along ray to ray length of intersect point (0-1)
                        local t1 = (edge2.x1 + edgeVectorX * t2 - originX) / rdx

                        if t1 > 0 and t2 >= 0 and t2 <= 1 then

                            -- Get the closest intersection point
                            if t1 < min_t1 then
                                min_t1 = t1
                                min_px = originX + rdx * t1
                                min_py = originY + rdy * t1
                                min_ang = math.atan2(min_py-originY, min_px-originX)
                                valid = true
                            end

                        end

                    end

                end

                if valid then
                    local exists = false
                    for _, pt in ipairs(areaTable) do

                        if min_px <= pt[2]+0.2 and min_px >= pt[2]-0.2 and
                           min_py <= pt[3]+0.2 and min_py >= pt[3]-0.2 then

                            exists = true 
                            break
                        end

                    end

                    if not exists then
                        table.insert(areaTable, {min_ang, min_px, min_py})
                    end
                end

            end

        end

    end

    -- sort by angle
    table.sort(areaTable, function(a, b)
        return a[1] < b[1]
    end)

    -- create actual Polygon
    local triangle = {}
    count = 0
    done = false

    while not done do

        count = count + 1

        table.insert(triangle, areaTable[count][2])
        table.insert(triangle, areaTable[count][3])

        if #triangle == 4 then

            table.insert(triangle, originX)
            table.insert(triangle, originY)
            table.insert(triangles, triangle)
            triangle = {}
            count = count - 1

        end

        if count >= #areaTable then 
            table.insert(triangle, areaTable[1][2])
            table.insert(triangle, areaTable[1][3])
            table.insert(triangle, originX)
            table.insert(triangle, originY)
            table.insert(triangles, triangle)
            triangle = {}
            done = true 
        end

    end

    return triangles

end

function love.load()

    love.window.setTitle("Lighting")
    love.window.setVSync(0)
    love.graphics.setLineStyle("rough")

    aPolygon = calculateVisiblePolygon(player.x, player.y, 2000)

end

function love.update(dt)

    if love.mouse.isDown(1) then

        player.x = love.mouse.getX()
        player.y = love.mouse.getY()

        aPolygon = calculateVisiblePolygon(player.x, player.y, 2000)

    end

end

function love.mousepressed(mx, my, btn)

    if btn == 2 and not newEdge.draw then
        newEdge.draw = true
        newEdge.x1 = mx
        newEdge.y1 = my
    end

end

function love.mousereleased(mx, my, btn)

    if btn == 2 and newEdge.draw then
        newEdge.draw = false
        newEdge.x2 = mx
        newEdge.y2 = my
        table.insert(edges, { x1=newEdge.x1, y1=newEdge.y1, x2=newEdge.x2, y2=newEdge.y2 })
        aPolygon = calculateVisiblePolygon(player.x, player.y, 2000)
    end

end

function love.draw()

    -- Draw background texture
    love.graphics.draw(bgSource, bgQuad, 0, 0)

    -- 
    love.graphics.setCanvas(lightmap)
        love.graphics.clear()

        -- Draw a black rectangle as the background
        love.graphics.setColor(0.1,0.1,0.1)
        love.graphics.rectangle("fill", 0, 0, 800, 600)
        love.graphics.setColor(1,1,1)

        -- Draw all the visible triangles with the "light" shader
        love.graphics.setShader(light)
            light:send("origin", { player.x, player.y })
            light:send("radius", 300)
            light:send("falloff", 20)
            light:send("clr", { 1, 0.8, 0.2 })
            for _, triangle in ipairs(aPolygon) do
                love.graphics.polygon("fill", triangle)
            end
        love.graphics.setShader()
    
    love.graphics.setCanvas()

    -- Draw light
    love.graphics.setBlendMode("multiply", "premultiplied")
        love.graphics.draw(lightmap)
    love.graphics.setBlendMode("alpha", "alphamultiply")

    -- Draw the player
    love.graphics.circle("fill", player.x, player.y, 10)
    love.graphics.setColor(0,0,0)
    love.graphics.setLineWidth(3)
    love.graphics.setLineStyle("smooth")
        love.graphics.circle("line", player.x, player.y, 10)
    love.graphics.setColor(1,1,1)
    love.graphics.setLineWidth(1)
    love.graphics.setLineStyle("rough")

    -- Draw all the triangles of the visible area
    -- for _, triangle in ipairs(aPolygon) do
    --     love.graphics.polygon("line", triangle)
    -- end

    -- Draw all edges
    for k, edge in ipairs(edges) do
        love.graphics.line(edge.x1,edge.y1,edge.x2,edge.y2)
    end

    -- Draw wall placer helper
    if newEdge.draw then
        love.graphics.line(newEdge.x1, newEdge.y1, love.mouse.getX(), love.mouse.getY())
        love.graphics.circle("fill", newEdge.x1, newEdge.y1, 5)
        love.graphics.circle("fill", love.mouse.getX(), love.mouse.getY(), 5)
    end

    love.graphics.print("FPS: "..love.timer.getFPS(), 10, 10)
    love.graphics.printf("Hold the left mouse button to move the player around.", 0, 550, 800, "center")
    love.graphics.printf("Hold the right mouse button to create a wall.", 0, 570, 800, "center")

end