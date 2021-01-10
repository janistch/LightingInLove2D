local light = love.graphics.newShader([[

    extern vec2 origin;

    vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords)
    {
        vec4 currentColor = Texel(texture, texture_coords);

        float dist = distance(origin, screen_coords);

        if (dist > 50) {
            currentColor.a = (300 - dist)/250;
        }

        return vec4(1, 0.87, 0.52, currentColor.a);
    }

]])

bgSource = love.graphics.newImage("assets/tiles.png")
bgSource:setWrap("repeat", "repeat")
bgQuad = love.graphics.newQuad(0, 0, 800, 600, bgSource:getWidth(), bgSource:getHeight())


local fakeLight = {
    x = 500,
    y = 100
}

-- The "player" which is also our light source
local player = {
    x = 400,
    y = 300
}

-- All the edges of our world
local edges = {
    { x1 = 10, y1 = 10, x2 = 790, y2 = 10 },
    { x1 = 10, y1 = 590, x2 = 790, y2 = 590 },
    { x1 = 10, y1 = 10, x2 = 10, y2 = 590 },
    { x1 = 790, y1 = 10, x2 = 790, y2 = 590 },
    { x1 = 150, y1 = 200, x2 = 200, y2 = 100 },
    { x1 = 200, y1 = 100, x2 = 250, y2 = 150 },
    { x1 = 500, y1 = 350, x2 = 600, y2 = 250 },
    { x1 = 300, y1 = 500, x2 = 450, y2 = 500 },
    { x1 = 250, y1 = 420, x2 = 400, y2 = 420 },
}

-- The polygon which represents the visible area
local visiblePolygon = {}
local aPolygon = {}

-- Checks if two line segments intersect
-- Returns coordinates if they do and false if they don't
function segmentIntersect(x1, y1, x2, y2)



end

-- The main attraction: this function calculates the visible area in form of a polygon
function calculateVisiblePolygon(originX, originY, radius)

    visiblePolygon = {}

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
                    for _, pt in ipairs(visiblePolygon) do

                        if min_px <= pt[2]+0.2 and min_px >= pt[2]-0.2 and
                           min_py <= pt[3]+0.2 and min_py >= pt[3]-0.2 then

                            exists = true 
                            break
                        end

                    end

                    if not exists then
                        table.insert(visiblePolygon, {min_ang, min_px, min_py})
                    end
                end

            end

        end

    end

    -- sort by angle
    table.sort(visiblePolygon, function(a, b)
        return a[1] < b[1]
    end)

    -- create actual Polygon
    aPolygon = {}
    triangle = {}
    count = 0
    done = false

    while not done do

        count = count + 1

        table.insert(triangle, visiblePolygon[count][2])
        table.insert(triangle, visiblePolygon[count][3])

        if #triangle == 4 then

            table.insert(triangle, originX)
            table.insert(triangle, originY)
            table.insert(aPolygon, triangle)
            triangle = {}
            count = count - 1

        end

        if count >= #visiblePolygon then 
            table.insert(triangle, visiblePolygon[1][2])
            table.insert(triangle, visiblePolygon[1][3])
            table.insert(triangle, originX)
            table.insert(triangle, originY)
            table.insert(aPolygon, triangle)
            triangle = {}
            done = true 
        end

    end

end

function love.load()

    love.graphics.setLineStyle("rough")
    love.window.setVSync(0)

    calculateVisiblePolygon(player.x, player.y, 2000)

end

function love.update(dt)

    if love.mouse.isDown(1) then
        player.x = love.mouse.getX()
        player.y = love.mouse.getY()

        calculateVisiblePolygon(player.x, player.y, 2000)
    end

end

local canvas = love.graphics.newCanvas()

function love.draw()

    -- Draw background texture
    love.graphics.draw(bgSource, bgQuad, 0, 0)

    love.graphics.setCanvas(canvas)
        love.graphics.clear()

        -- draw darkness
        love.graphics.setColor(0.1,0.1,0.1)
        love.graphics.rectangle("fill", 0, 0, 800, 600)
        love.graphics.setColor(1,1,1)

        -- draw Polygon
        love.graphics.setShader(light)
            light:send("origin", { player.x, player.y })
            for _, triangle in ipairs(aPolygon) do
                love.graphics.polygon("fill", triangle)
            end
        love.graphics.setShader()
    
    love.graphics.setCanvas()

    -- Draw the player
    love.graphics.setColor(0,0.1,0.5)
    love.graphics.circle("fill", player.x, player.y, 10, 5)
    love.graphics.setColor(1,1,1)

    -- Draw light
    love.graphics.setBlendMode("multiply", "premultiplied")
    love.graphics.draw(canvas)
    love.graphics.setBlendMode("alpha", "alphamultiply")

    -- Draw all edges
    for k, edge in ipairs(edges) do
        love.graphics.line(edge.x1,edge.y1,edge.x2,edge.y2)
    end

    love.graphics.print("FPS: "..love.timer.getFPS(), 10, 10)

end