-- Scripted MAME session. Steps file lines: T <text> | E | S <name> | W <frames> | K <hex key> | X
-- In T text: <CK>=Ctrl-K <CA>=Ctrl-A <CR>=Enter <ES>=Esc <xNN>=any key code. Keys are fed one at a time, only when the
-- keyboard latch ($C000 bit 7) is empty, so a program busy on the disk never loses a key.
local m = manager.machine
local mem = m.devices[":maincpu"].spaces["program"]
local steps = {}
for line in io.lines(os.getenv("LTM_STEPS")) do
  local c, rest = line:match("^(%a)%s?(.*)$")
  if c then steps[#steps+1] = {c, rest} end
end
local cpu = m.devices[":maincpu"]
local function dump()
  local o = io.open(os.getenv("LTM_STEPS") .. ".pc", "w")
  local strend = mem:read_u8(0x6D) + 256 * mem:read_u8(0x6E)
  local fretop = mem:read_u8(0x6F) + 256 * mem:read_u8(0x70)
  o:write(string.format("PC=%04X SP=%02X curline=%d VARTAB=%04X FRETOP=%04X STREND=%04X free=%d\n", cpu.state["PC"].value, cpu.state["SP"].value,
    mem:read_u8(0x75) + 256 * mem:read_u8(0x76), mem:read_u8(0x69) + 256 * mem:read_u8(0x6A), fretop, strend, fretop - strend))
  o:close()
end
local function dumpvars(tag)
  local a, b = mem:read_u8(0x69) + 256 * mem:read_u8(0x6A), mem:read_u8(0x6B) + 256 * mem:read_u8(0x6C)
  local lo = mem:read_u8(0x67) + 256 * mem:read_u8(0x68)
  local vt = mem:read_u8(0x69) + 256 * mem:read_u8(0x6A)
  local o = io.open(os.getenv("LTM_STEPS") .. "." .. tag .. ".var", "wb")
  local vs = mem:read_u8(0x6B) + 256 * mem:read_u8(0x6C)
  for addr = vt, vs - 1 do o:write(string.char(mem:read_u8(addr))) end
  o:close()
end
local si, f, wait = 1, 0, tonumber(os.getenv("LTM_BOOTWAIT") or "3600")      -- boot time (LTM_BOOTWAIT: shorter, to watch the boot)
local queue, state, tmo, lastkey, prevkey = {}, "idle", 0, "", ""
local snapn = 0
local gating = true     -- G off: post keys without waiting for the program to be idle (typing ahead)
local function expand(t)
  t = t:gsub("<ES>", string.char(27)):gsub("<x(%x%x)>", function(h) return string.char(tonumber(h, 16)) end)
  t = t:gsub("<CC>", string.char(3)):gsub("<CK>", string.char(11)):gsub("<CA>", string.char(1)):gsub("<CR>", string.char(13)):gsub("<RT>", string.char(21)):gsub("<LT>", string.char(8))
  return t
end
-- LTM_IDLE=lo-hi (hex): log, for every key, the frames from the key being read until the PC is back in [lo,hi)
local idlo, idhi = (os.getenv("LTM_IDLE") or ""):match("^(%x+)-(%x+)$")
idlo = idlo and tonumber(idlo, 16); idhi = idhi and tonumber(idhi, 16)
-- LTM_IDLELINE=lo-hi (decimal BASIC line numbers): the same, idle = the BASIC line being run is in [lo,hi]
-- (a key wait written in BASIC, such as LTM's PEEK loop)
local illo, ilhi = (os.getenv("LTM_IDLELINE") or ""):match("^(%d+)-(%d+)$")
illo = illo and tonumber(illo); ilhi = ilhi and tonumber(ilhi)
local function isidle()
  if illo then local ln = mem:read_u8(0x75) + 256 * mem:read_u8(0x76); return ln >= illo and ln <= ilhi end
  local pc = cpu.state["PC"].value
  return pc >= idlo and pc < idhi
end
if illo then idlo = 1 end
local kread, kst, seen, gate = 0, 0, false, 0     -- kst: 1 key posted, 2 program busy with it
-- Q on / Q off: count, every frame, the BASIC line being run (a profile); written to <steps>.prof at Q off
local prof = nil
emu.register_frame_done(function()
  f = f + 1
  if prof then local ln = mem:read_u8(0x75) + 256 * mem:read_u8(0x76); prof[ln] = (prof[ln] or 0) + 1 end
  if idlo and kst > 0 then
    local idle = isidle()
    if kst == 1 and not idle then kst = 2 end
    if kst == 2 and idle then
      local o = io.open(os.getenv("LTM_STEPS") .. ".idle", "a"); o:write(string.format("%d %d\n", kread, f - kread)); o:close()
      kst = 0
    end
  end
  if wait > 0 then wait = wait - 1; return end
  -- with LTM_IDLE: once the program has been seen waiting for a key, post keys and run steps only while it waits
  -- (at most 900 frames; after that, e.g. when the program has ended, stop gating)
  if idlo and gating and state == "idle" then
    if isidle() then seen = true; gate = 0
    elseif seen then
      gate = gate + 1
      if gate < 900 then return end
      seen = false
    end
  end
  if #queue > 0 or state ~= "idle" then   -- also finish waiting for the last key of a T step
    local latch = mem:read_u8(0xC000)
    if state == "idle" then
      lastkey = table.remove(queue, 1); m.natkeyboard:post(lastkey); state = "sent"; tmo = 0; kread = f; kst = 1
    elseif state == "sent" then
      tmo = tmo + 1
      if latch >= 128 then state = "latched"
      elseif idlo and tmo > 2 and latch == lastkey:byte() % 128 and lastkey ~= prevkey then
        -- a program that polls the keyboard takes the key within the frame: the latch already shows it, strobed
        state = "idle"; wait = (lastkey == string.char(13)) and 150 or 40
      elseif tmo > 120 then state = "idle"; if idlo then wait = 40 end end   -- key swallowed by MAME (or the same key twice); go on
      if state ~= "sent" then prevkey = lastkey end
    elseif state == "latched" then
      tmo = tmo + 1
      if latch < 128 or tmo > 3000 then state = "idle"; wait = (lastkey == string.char(13)) and 150 or 40 end
    end
    return
  end
  state = "idle"
  local s = steps[si]
  if not s then dump(); m:exit(); return end
  si = si + 1
  local c, a = s[1], s[2]
  if c == "T" then
    a = expand(a)
    for i = 1, #a do queue[#queue+1] = a:sub(i, i) end
  elseif c == "E" then queue[#queue+1] = string.char(13)
  elseif c == "W" then wait = tonumber(a)
  elseif c == "S" then wait = 500; steps[si-1] = nil
    -- snapshot after the settle wait: re-run this step as a marker
    table.insert(steps, si, {"s", a})
  elseif c == "s" then m.video:snapshot()
  elseif c == "P" then local o = io.open(os.getenv("LTM_STEPS") .. ".trace", "a"); o:write(string.format("%s f=%d line=%d latch=%02X\n", a, f, mem:read_u8(0x75) + 256 * mem:read_u8(0x76), mem:read_u8(0xC000))); o:close()
  elseif c == "Q" then
    if a == "on" then prof = {}
    else
      local o = io.open(os.getenv("LTM_STEPS") .. ".prof", "a"); o:write("== " .. a .. string.char(10))
      local ks = {}; for k in pairs(prof) do ks[#ks+1] = k end; table.sort(ks)
      for _, k in ipairs(ks) do o:write(string.format("%d %d", k, prof[k]) .. string.char(10)) end
      o:close(); prof = nil
    end
  elseif c == "D" then dumpvars(a)
  elseif c == "G" then gating = (a ~= "off")
  elseif c == "M" then   -- M <hex addr> <count>: hex dump into the trace file
    local ad, n = a:match("^(%x+)%s+(%d+)$"); ad = tonumber(ad, 16); n = tonumber(n)
    local o = io.open(os.getenv("LTM_STEPS") .. ".trace", "a"); o:write(string.format("M %04X:", ad))
    for i = 0, n - 1 do o:write(string.format(" %02X", mem:read_u8(ad + i))) end
    o:write("\n"); o:close()
  elseif c == "K" then   -- K <hex>: one key through K-HANGEUL's type-ahead ring, which KEDIT reads first. For the
    -- codes MAME's natural keyboard cannot type as themselves ($0A arrives as Return). Its frames are logged like a T key
    mem:write_u8(0x95AE + (mem:read_u8(0x942C) % 32), tonumber(a, 16) | 0x80); mem:write_u8(0x942B, 1)
    kread = f; kst = 1; wait = 3
  elseif c == "X" then dump(); m:exit() end
end)
