local video

return function(mod)
  -- Gen1Recomp's bundled LÖVE build includes love.graphics.newVideo and
  -- the Theora video backend. Add title.ogv beside this file for the test.
  local ok, result = pcall(function()
    return love.graphics.newVideo("title.ogv", { audio = true })
  end)

  if not ok or not result then
    mod.log:warn("Title video could not be opened: %s", tostring(result))
    return
  end

  video = result

  mod.content.screens:override("TitleState", {
    new = function(game, opts)
      local state = {
        game = game,
        opts = opts,
        screenId = "TitleState",
        isOpaque = true,
      }

      function state:enter()
        if video.rewind then video:rewind() end
        if video.play then video:play() end
      end

      function state:exit()
        if video.pause then video:pause() end
      end

      function state:update(dt)
        if video.update then video:update(dt) end

        if game.input:wasPressed("a") or game.input:wasPressed("start") then
          if self.opts and self.opts.onNewGame then
            self.opts.onNewGame()
          end
        elseif game.input:wasPressed("b") then
          if self.opts and self.opts.onContinue then
            self.opts.onContinue()
          end
        end
      end

      function state:draw()
        local w, h = love.graphics.getDimensions()
        local vw, vh = video:getDimensions()
        if vw > 0 and vh > 0 then
          local scale = math.max(w / vw, h / vh)
          local dw, dh = vw * scale, vh * scale
          love.graphics.draw(video, (w - dw) / 2, (h - dh) / 2, 0, scale, scale)
        end
      end

      return state
    end,
  })

  mod.log:info("Title screen video test installed")
end
