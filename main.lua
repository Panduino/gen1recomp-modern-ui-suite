return function(mod)
  local DexEntryMenu = require("src.ui.DexEntryMenu")
  local PokedexMenu = require("src.ui.PokedexMenu")
  local Sprites = require("src.pokemon.Sprites")

  local function blankVanillaSprite(next, self, ...)
    local oldPath = Sprites.path
    Sprites.path = function()
      return nil
    end
    local ok, a, b, c, d = pcall(next, self, ...)
    Sprites.path = oldPath
    if not ok then error(a, 0) end
    return a, b, c, d
  end

  if type(DexEntryMenu.draw) == "function" then
    local draw = DexEntryMenu.draw
    DexEntryMenu.draw = function(self, ...)
      return blankVanillaSprite(draw, self, ...)
    end
  end

  if type(PokedexMenu.draw) == "function" then
    local draw = PokedexMenu.draw
    PokedexMenu.draw = function(self, ...)
      return blankVanillaSprite(draw, self, ...)
    end
  end
end
