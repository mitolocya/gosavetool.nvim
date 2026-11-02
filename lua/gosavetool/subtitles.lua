-- SRT and WebVTT: read cues, write them in either format, shift and repair timings.
-- The Lua version of @gosavetool/subtitles: https://www.gosavetool.com/vtt-subtitle-generator

local M = {}

local STAMP = '%d%d?:?%d?%d?:?%d%d?[,.]%d%d?%d?'

--- "00:01:02,500" or "01:02.5" -> 62500; nil when it is not a timestamp
function M.to_ms(s)
  local h, m, sec, frac = s:match('^%s*(%d%d?):(%d%d?):(%d%d?)[,.](%d%d?%d?)%s*$')
  if not h then
    m, sec, frac = s:match('^%s*(%d%d?):(%d%d?)[,.](%d%d?%d?)%s*$')
    h = '0'
  end
  if not m then return nil end
  frac = frac .. string.rep('0', 3 - #frac)
  return ((tonumber(h) * 60 + tonumber(m)) * 60 + tonumber(sec)) * 1000 + tonumber(frac)
end

--- 62500 -> "00:01:02,500" (sep ",", SRT) or "00:01:02.500" (sep ".", WebVTT)
function M.from_ms(ms, sep)
  sep = sep or ','
  ms = math.max(0, math.floor(ms + 0.5))
  return string.format('%02d:%02d:%02d%s%03d', math.floor(ms / 3600000), math.floor(ms / 60000) % 60, math.floor(ms / 1000) % 60, sep, ms % 1000)
end

--- The start, end and settings of a "start --> end settings" line, or nil
local function arrow(line)
  local a, b, rest = line:match('^%s*(' .. STAMP .. ')%s*%-%->%s*(' .. STAMP .. ')(.*)$')
  if not a then return nil end
  local start, stop = M.to_ms(a), M.to_ms(b)
  if not start or not stop then return nil end
  return start, stop, vim.trim(rest)
end

--- Cues of an SRT or WebVTT text: { { start = ms, ['end'] = ms, settings = '', text = '' }, ... }
function M.parse(src)
  -- "\r\r\n" too: a file saved twice with Windows line endings
  local text = src:gsub('^\239\187\191', ''):gsub('\r*\n', '\n'):gsub('\r', '\n')
  local cues = {}
  for block in (text .. '\n\n'):gmatch('(.-)\n\n+') do
    local lines = vim.split(block, '\n', { plain = true })
    for i, line in ipairs(lines) do
      local start, stop, settings = arrow(line)
      if start then
        local body = vim.trim(table.concat(lines, '\n', i + 1))
        cues[#cues + 1] = { start = start, ['end'] = stop, settings = settings, text = body }
        break
      end
    end
  end
  return cues
end

--- True when the text starts with the WEBVTT signature
function M.is_vtt(src)
  return src:gsub('^\239\187\191', ''):sub(1, 6) == 'WEBVTT'
end

function M.to_srt(cues)
  local out = {}
  for i, c in ipairs(cues) do
    out[i] = i .. '\n' .. M.from_ms(c.start, ',') .. ' --> ' .. M.from_ms(c['end'], ',') .. '\n' .. c.text
  end
  return table.concat(out, '\n\n') .. '\n'
end

function M.to_vtt(cues)
  local out = {}
  for i, c in ipairs(cues) do
    local settings = (c.settings and c.settings ~= '') and (' ' .. c.settings) or ''
    out[i] = M.from_ms(c.start, '.') .. ' --> ' .. M.from_ms(c['end'], '.') .. settings .. '\n' .. c.text
  end
  return 'WEBVTT\n\n' .. table.concat(out, '\n\n') .. '\n'
end

--- Converts a subtitle text to "srt" or "vtt"
function M.convert(src, to)
  if to ~= 'srt' and to ~= 'vtt' then error('the target format must be "srt" or "vtt"') end
  local cues = M.parse(src)
  return to == 'vtt' and M.to_vtt(cues) or M.to_srt(cues)
end

--- Moves every cue by ms (negative = earlier); cues pushed before zero are clipped or dropped
function M.shift(cues, ms)
  local out = {}
  for _, c in ipairs(cues) do
    local stop = math.max(0, c['end'] + ms)
    if stop > 0 then
      out[#out + 1] = { start = math.max(0, c.start + ms), ['end'] = stop, settings = c.settings, text = c.text }
    end
  end
  return out
end

--- Sorts cues, fixes end times before the start and overlaps, drops empty cues.
--- Returns the repaired cues and the number of changes.
function M.repair(cues, min_duration)
  min_duration = min_duration or 2000
  local fixed, out = 0, {}
  for i, c in ipairs(cues) do
    if c.text == '' then
      fixed = fixed + 1
    else
      out[#out + 1] = { start = c.start, ['end'] = c['end'], settings = c.settings, text = c.text, i = i }
    end
  end
  local before = {}
  for i, c in ipairs(out) do before[i] = c.start end
  -- Stable: equal starts keep their order
  table.sort(out, function(a, b)
    if a.start ~= b.start then return a.start < b.start end
    return a.i < b.i
  end)
  for i, c in ipairs(out) do
    if c.start ~= before[i] then
      fixed = fixed + 1
      break
    end
  end
  for i, c in ipairs(out) do
    local next_cue = out[i + 1]
    if not (c['end'] > c.start) then
      c['end'] = c.start + min_duration
      fixed = fixed + 1
    end
    if next_cue and c['end'] > next_cue.start then
      c['end'] = math.max(c.start + 1, next_cue.start - 1)
      fixed = fixed + 1
    end
    c.i = nil
  end
  return out, fixed
end

return M
