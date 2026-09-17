-- Native regression for the September 14 Discord money/key reports.
-- Use the isolated muted, nonactivating runner; never a live player profile.
return function(game)
  local U = dofile(assert(os.getenv('PC_REPO')) .. '/tests/drivers/util.lua')
  local Screens = require('src.ui.Screens')
  local Bag = require('src.inventory.Bag')
  local Font = require('src.render.Font')
  local gen2 = require('src.core.GameVersion').generation() == 2
  local opts = game.mods.modOptions.modern_ui_suite
  local checks = 0
  local function check(ok, label)
    checks = checks + 1
    assert(ok, label)
    print('[BAG REPORTS] ' .. label)
  end
  local function clear() while game.stack:top() do game.stack:pop() end end
  local function press(menu, key)
    local old = game.input
    game.input = setmetatable({wasPressed=function(_, k) return k == key end,
      isDown=function() return false end}, {__index=old})
    local ok, err = pcall(menu.update, menu, 0)
    game.input = old
    assert(ok, err)
  end
  local function shot(name)
    U.wait(3)
    check(U.shot(game, os.getenv('SHOT_DIR') .. '/' .. name .. '.png'), 'captured ' .. name)
    check(not love.window.hasFocus() and love.audio.getVolume() == 0, 'muted and unfocused')
  end
  local wallet = gen2 and game.save.player or game.save
  -- Gen 2 stores money in player; the previous fixture seeded Gen 1's field.
  if gen2 then game.save.money = nil end
  wallet.money = 13000
  game.save.inventory = {}; game.save.bagOrder = nil
  for _, id in ipairs({'BICYCLE', 'OLD_ROD', 'POTION', 'POKE_BALL'}) do
    check(Bag.add(game.save, id, 1, game.data), 'seeded ' .. id)
  end
  opts['bag.skin'] = 'modern'; opts['bag.open_on'] = 'all'
  opts['bag.aspect_ratio'] = '16:9'
  love.window.setMode(1280, 720, {resizable=true, vsync=0})
  local function open(save)
    clear()
    return Screens.push(game, gen2 and 'Gen2PackMenu' or 'BagMenu',
      gen2 and {save=save or game.save, world={useFieldItem=function() end}} or {})
  end
  local bag = open()
  for _ = 1, 5 do press(bag, 'right') end
  shot('key-items-13000')
  local function balance(menu, expected)
    U.wait(2)
    local info = menu:modernBagQolInfo()
    check(info.headerCash == '¥' .. expected,
      'visible header matches native wallet ¥' .. expected .. ' (got ' .. tostring(info.headerCash) .. ')')
    check(info.money == '¥' .. expected, 'presentation reads native wallet')
    local b = info.header
    if b and b.leftRight then
      check(b.twoRows or b.leftRight <= b.titleX, 'money fits before pocket title')
      check(b.twoRows or b.titleRight <= b.capacityLeft, 'title fits before capacity or on its own row')
    end
  end
  balance(bag, 13000)
  -- Capture the actual Trainer Card print calls, rather than a duplicate formatter.
  if gen2 then
    clear()
    local trainer = Screens.push(game, 'Gen2TrainerCard', {save=game.save})
    local seen = false
    local original = trainer.print
    trainer.print = function(self, text, ...)
      if tostring(text):find('¥13000', 1, true) then seen = true end
      return original(self, text, ...)
    end
    shot('trainer-card-13000')
    check(seen, 'native Trainer Card agrees with Bag at ¥13000')
    bag = open()
  end
  for _, skin in ipairs({'modern', 'classic_pocket'}) do
    opts['bag.skin'] = skin
    bag = open()
    for _, amount in ipairs({0, 1, 13000, 999999, 12800}) do
      wallet.money = amount
      balance(bag, amount)
      for _ = 1, (skin == 'modern' and 6 or (gen2 and 4 or 6)) do
        press(bag, 'right'); balance(bag, amount)
      end
      check(wallet.money == amount, 'rendering and pocket navigation preserve balance')
      if gen2 then check(game.save.money == nil, 'does not create a Gen 1 money field') end
    end
    shot(skin .. '-12800')
  end
  if gen2 then
    -- PACK accepts an explicit save, including the item-PC deposit chooser.
    local other = setmetatable({player={name='GOLD', money=4321}}, {__index=game.save})
    for _, skin in ipairs({'modern', 'classic_pocket'}) do
      opts['bag.skin'] = skin
      bag = open(other); balance(bag, 4321)
      check(wallet.money == 12800, 'explicit menu save leaves game wallet unchanged')
    end
  end
  opts['bag.skin'] = 'modern'; wallet.money = 999999
  bag = open()
  for _ = 1, 5 do press(bag, 'right') end
  for _, size in ipairs({{'compact',800,720,'4:3'}, {'portrait',480,900,'fill'}, {'wide',1280,720,'16:9'}}) do
    opts['bag.aspect_ratio'] = size[4]
    love.window.setMode(size[2],size[3],{resizable=true,vsync=0})
    shot('key-' .. size[1]); balance(bag, 999999)
  end
  check(Font.width('¥999999') > 0, 'native money glyphs are available')
  print('[DISCORD QA] PASS ' .. checks .. ' Bag report checks')
  love.event.quit(0)
end
