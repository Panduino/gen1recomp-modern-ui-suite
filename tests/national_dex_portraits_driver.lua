-- Real National Dex + G9 Battle Sprites; runner supplies original geometric art.
return function(game)
  local U = dofile(assert(os.getenv('PC_REPO')) .. '/tests/drivers/util.lua')
  local Screens = require('src.ui.Screens')
  local Runtime = require('src.mods.Runtime')
  local gen2 = require('src.core.GameVersion').generation() == 2
  local baseline = os.getenv('PORTRAIT_BASELINE') == '1'
  local options = game.mods.modOptions.modern_ui_suite
  local checks = 0
  local function check(ok, label)
    assert(ok, label); checks = checks + 1; print('[DEX COMPAT] ' .. label)
  end
  local function press(menu, key)
    local old = game.input
    game.input = setmetatable({wasPressed=function(_, k) return k == key end,
      isDown=function() return false end}, {__index=old})
    local ok, err = pcall(menu.update, menu, 0); game.input = old; assert(ok, err)
  end
  local known, drawn, recolored = {}, 0, 0
  local originalDraw = love.graphics.draw
  love.graphics.draw = function(image, ...)
    if known[image] then
      drawn = drawn + 1
      if love.graphics.getShader() then recolored = recolored + 1 end
    end
    return originalDraw(image, ...)
  end
  local function frame(species)
    local image = Runtime.call('battle.mon_pic', function(value) return value end, nil,
      {mon={species=species}, species=species, side='front', kind='dex'})
    if image then known[image] = true end
    return image
  end
  local function observe(menu, species, label)
    drawn, recolored = 0, 0
    for _ = 1, 50 do frame(species); U.wait(1) end
    print('[DEX COMPAT] ' .. label .. ': draws=' .. drawn .. ' recolored=' .. recolored)
    check(frame(species), species .. ' provider frame available')
    if not baseline then
      check(drawn > 0, label .. ' displays installed provider artwork')
      check(recolored == 0, label .. ' retains authored colours')
    end
    local path = os.getenv('SHOT_DIR') .. '/' .. label .. '.png'
    check(U.shot(game, path), 'capture ' .. label)
    if not baseline then
      local file = assert(io.open(path,'rb')); local bytes = file:read('*a');file:close()
      local data = love.image.newImageData(love.filesystem.newFileData(bytes,'capture.png'))
      local count = 0
      for y = 0, data:getHeight()-1 do
        for x = 0, data:getWidth()-1 do
          local r,g,b = data:getPixel(x,y)
          if (math.abs(r-240/255)<.01 and math.abs(g-45/255)<.01 and math.abs(b-100/255)<.01)
            or (math.abs(r-25/255)<.01 and math.abs(g-210/255)<.01 and math.abs(b-225/255)<.01) then count=count+1 end
        end
      end
      if count == 0 then
        local image = frame(species)
        local canvas = love.graphics.newCanvas(image:getDimensions())
        love.graphics.push('all');love.graphics.setCanvas(canvas);love.graphics.origin()
        love.graphics.setShader();love.graphics.setColor(1,1,1,1);love.graphics.clear()
        originalDraw(image,0,0);love.graphics.pop()
        local raw=canvas:newImageData():encode('png')
        local f=assert(io.open(os.getenv('SHOT_DIR')..'/provider-raw.png','wb'));f:write(raw:getString());f:close()
      end
      check(count > 20, label .. ' screenshot preserves fixture RGB pixels')
    end
  end
  love.window.setMode(1280,720,{resizable=true,vsync=0})
  -- Authentic palette modes intentionally remap even true-colour assets.
  -- Exercise the colour modes that honour provider artwork, as in the report.
  if gen2 then require('src.render.GbcPalette').setMode('gbc')
  else require('src.render.PaletteFX').setMode('redpp') end
  options.menu_sprite_source = 'battle_art'
  game.save.pokedex.owned = game.save.pokedex.owned or {}
  for _, species in ipairs({'VIGOROTH','LATIAS','PACHIRISU','GARCHOMP','SCOLIPEDE'}) do
    check(game.data.pokemon[species], 'National Dex registered ' .. species)
    game.save.pokedex.seen[species] = true
    game.save.pokedex.owned[species] = true
    if game.save.pokedex.caught then game.save.pokedex.caught[species] = true end
    while game.stack:top() do game.stack:pop() end
    local menu = Screens.push(game, gen2 and 'Gen2PokedexMenu' or 'PokedexMenu')
    local found = false
    for i, row in ipairs(gen2 and menu.rows or menu.modernDexEntries) do
      if (row.species or row.def.id) == species then
        menu.index = i; menu.scroll = math.max(0, i - 3); found = true; break
      end
    end
    check(found, species .. ' listed')
    if gen2 then menu:ensureVisible() end
    observe(menu, species, species .. '-index')
    if gen2 then press(menu,'a'); press(menu,'a')
    else menu = Screens.push(game,'DexEntryMenu',species) end
    observe(menu, species, species .. '-entry')
  end
  if not baseline then
    local menu = game.stack:top()
    options.menu_sprite_source = 'default'
    options['pokedex.theme'] = 'dark'
    options['pokedex.aspect_ratio'] = '4:3'
    love.window.setMode(480,900,{resizable=true,vsync=0})
    observe(menu,'SCOLIPEDE','default-dark-portrait')
    game.mods.modOptions['g9-battle-sprites'] = game.mods.modOptions['g9-battle-sprites'] or {}
    local providerOptions = game.mods.modOptions['g9-battle-sprites']
    providerOptions.dex_sprites = false
    drawn = 0;U.wait(8)
    check(drawn == 0, 'DEX SPRITES off restores native artwork')
    providerOptions.dex_sprites = true
    providerOptions.animate_sprites = false
    observe(menu,'SCOLIPEDE','animation-off')
    local still = frame('SCOLIPEDE')
    for _=1,12 do U.wait(1);check(frame('SCOLIPEDE')==still,'animation off stays on first frame') end
    providerOptions.animate_sprites = true
    local variants = {}
    for _=1,120 do variants[frame('SCOLIPEDE')] = true;U.wait(1) end
    local count=0;for _ in pairs(variants) do count=count+1 end
    check(count==2,'both installed animation frames advance')
  end
  love.graphics.draw = originalDraw
  check(not love.window.hasFocus() and love.audio.getVolume() == 0, 'muted and unfocused')
  print('[DISCORD QA] PASS ' .. checks .. ' national portrait checks' .. (baseline and ' (baseline observations)' or ''))
  love.event.quit(0)
end
