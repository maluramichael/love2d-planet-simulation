lume = require("thirdparty.lume.lume")
lurker = require("thirdparty.lurker.lurker")
Object = require("thirdparty.classic.classic")
vector = require("thirdparty.hump.vector")

Body = Object:extend()
Planet = Body:extend()
BlackHole = Body:extend()
Asteroid = Body:extend()

function Body:new(location, radius, mass)
  self.location = location or vector.new(0, 0)
  self.velocity = velocity or vector.new(0, 0)
  self.radius = radius or 200
  self.mass = mass or 10.0e8
  self.color = {love.math.random(), love.math.random(), love.math.random()}
  self.destroyed = false
end

function BlackHole:new(location)
  BlackHole.super.new(self, location, 100, 10.0e9)
  self.color = {0, 0, 0}
end

function Body:draw()
  love.graphics.push("all")
  love.graphics.setLineWidth(4)
  love.graphics.setColor(self.color)
  love.graphics.setShader(shader)
  love.graphics.circle("fill", self.location.x, self.location.y, self.radius)
  love.graphics.setShader()
  love.graphics.setColor(1, 1, 1)
  love.graphics.circle("line", self.location.x, self.location.y, self.radius)
  love.graphics.pop()
end

function Body:update(dt)
  if self.destroyed == true then
    return
  end

  local acceleration, collision = getForceForObject(self)

  self.acceleration = acceleration * dt
  self.velocity = self.velocity + self.acceleration
  self.location = self.location + self.velocity

  if collision then
    if self.mass > collision.mass then
      collision.destroyed = true
      self.mass = self.mass + collision.mass
      self.velocity = self.velocity * 0.8
      self.radius = self.radius + collision.radius * 0.1
    else
      self.destroyed = true
      collision.mass = collision.mass + self.mass
      collision.velocity = collision.velocity * 0.8
      collision.radius = collision.radius + 5
    end
  end
end

function Asteroid:new(location, direction, initialVelocity)
  Asteroid.super.new(self, location, 10, 10.0e3)
  self.location = location or vector.new(0, 0)
  self.velocity = direction * initialVelocity
end

-- function Asteroid:update(dt)
--   local acceleration, collision = getForceForObject(self)

--   self.acceleration = acceleration * dt
--   self.velocity = self.velocity + self.acceleration
--   self.location = self.location + self.velocity

--   if collision ~= nil then
--     local direction = (self.location - collision.location):normalized()
--     local outerLocation = direction * (collision.radius + self.radius)
--     local newPosition = outerLocation + collision.location
--     self.location = newPosition
--     self.velocity = vector.new(0, 0)
--     self.acceleration = vector.new(0, 0)
--   end
-- end

bodies = {}

local G = 6.67e-11 -- N*(m/kg)^2

function distanceSquared(a, b)
  return a.location:dist(b.location) ^ 2
end

function collide(a, b)
  local d = a.location:dist(b.location)
  return d < a.radius + b.radius, d
end

function force(a, b)
  return G * a.mass * b.mass / distanceSquared(a, b)
end

function generateBodies()
  bodies = {}
  local w, h = love.graphics.getDimensions()
  for i = 1, 10 do
    table.insert(bodies, Planet(vector.new(love.math.random(0, w), love.math.random(0, h)), 50, 10.0e6))
  end
end

function love.load()
  math.randomseed(os.time())

  generateBodies()

  local pixelcode =
    [[
  extern number t;
  vec4 effect( vec4 color, Image texture, vec2 texture_coords, vec2 screen ) {
    float c = (
      sin(
        (screen.x + sin(screen.y / 50) * 20
      ) / 30.0 + t) + 1
    ) / 2.0;
    color *= c;
  /*return vec4(
    c * ((cos((screen.y + t + screen.x) / 10) + 1) / 2), 
    c * ((sin((screen.x - screen.y) / 10) + 1) / 2), 
    c * ((atan(screen.x / 10) + 1) / 2), 
    1
  );*/

  return vec4(color.rgb, 1);
  }]]
  shader = love.graphics.newShader(pixelcode)

  t = 0
  drag = {
    active = false,
    from = vector.new(),
    to = vector.new()
  }
end

function love.draw()
  love.graphics.clear(0.3, 0.3, 0.4)
  love.graphics.setColor(1, 1, 1, 1)
  shader:send("t", t)

  for _, body in ipairs(bodies) do
    body:draw()
  end

  love.graphics.push("all")
  love.graphics.setColor(1, 0, 0)
  -- for _, body in ipairs(bodies) do
  --   love.graphics.print(string.format("%d %d", body.location.x, body.location.y), 10, 20 * _)
  -- end

  if drag.active then
    local f = (drag.to - drag.from):len()

    love.graphics.print(string.format("%d %d %d %d", drag.from.x, drag.from.y, drag.to.x, drag.to.y), 0, 50)

    love.graphics.setLineWidth(3 + f * 0.05)
    love.graphics.line(drag.from.x, drag.from.y, drag.to.x, drag.to.y)
  end
  love.graphics.pop()

  love.graphics.print("Press R to reset planets\nPress ESC to quit\nClick, drag and release to launch an asteroid")
end

function spawnAsteroid(from, direction, strength)
  table.insert(bodies, Asteroid(from, direction, strength))
end

function getForceForObject(object)
  local acceleration = vector.new(0, 0)
  local collision = false
  -- local collisionDistance = 0

  for _, body in ipairs(bodies) do
    if body ~= object then
      local F = force(body, object)
      local direction = body.location - object.location
      local distance = direction:len()
      acceleration = acceleration + direction:normalized() * F

      if distance < body.radius + object.radius then
        collision = body
      end
    -- if collision == false then
    --   local didCollide = false
    --   didCollide, collision = collide(object, body)
    -- end
    end
  end

  return acceleration, collision
end

function love.update(dt)
  lurker.update(dt)
  t = t + dt

  if drag.active == false and love.mouse.isDown(1) then
    drag.active = true
    drag.from = vector.new(love.mouse.getPosition())
    drag.to = vector.new(love.mouse.getPosition())
  elseif drag.active == true and love.mouse.isDown(1) then
    drag.to = vector.new(love.mouse.getPosition())
  elseif drag.active == true and not love.mouse.isDown(1) then
    drag.active = false
    drag.to = vector.new(love.mouse.getPosition())
    spawnAsteroid(drag.from, (drag.to - drag.from):normalized(), (drag.to - drag.from):len() * 0.05)
  end

  for _, body in ipairs(bodies) do
    body:update(dt)
  end

  for i = #bodies, 1, -1 do
    if bodies[i].destroyed then
      table.remove(bodies, i)
    end
  end
end

function love.mousedown(button)
  if button == 1 then
    drag.active = true
  end
end

function love.mousemove()
  if drag.active == true then
  end
end

function love.mouseup(button)
  if button == 1 then
    drag.active = false
  end
end

function love.keypressed(key, scancode, isrepeat)
  if key == "escape" then
    love.event.quit()
  end
  if key == "r" then
    generateBodies()
  end
end
