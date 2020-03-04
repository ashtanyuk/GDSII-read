-- A basic GDSII reader that reads from standard input and writes serialized
-- text to standard output

local gdsii = {}

gdsii.types = {
  [0] = "HEADER",
  [1] = "BGNLIB",
  [2] = "LIBNAME",
  [3] = "UNITS",
  [4] = "ENDLIB",
  [5] = "BGNSTR",
  [6] = "STRNAME",
  [7] = "ENDSTR",
  [8] = "BOUNDARY",
  [9] = "PATH",
  [10] = "SREF",
  [11] = "AREF",
  [12] = "TEXT",
  [13] = "LAYER",
  [14] = "DATATYPE",
  [15] = "WIDTH",
  [16] = "XY",
  [17] = "ENDEL",
  [18] = "SNAME",
  [19] = "COLROW",
  [20] = "TEXTNODE",
  [21] = "NODE",
  [22] = "TEXTTYPE",
  [23] = "PRESENTATION",
  [24] = "SPACING",
  [25] = "STRING",
  [26] = "STRANS",
  [27] = "MAG",
  [28] = "ANGLE",
  [29] = "UINTEGER",
  [30] = "USTRING",
  [31] = "REFLIBS",
  [32] = "FONTS",
  [33] = "PATHTYPE",
  [34] = "GENERATIONS",
  [35] = "ATTRTABLE",
  [36] = "STYPTABLE",
  [37] = "STRTYPE",
  [38] = "ELFLAGS",
  [39] = "ELKEY",
  [40] = "LINKTYPE",
  [41] = "LINKKEYS",
  [42] = "NODETYPE",
  [43] = "PROPATTR",
  [44] = "PROPVALUE",
  [45] = "BOX",
  [46] = "BOXTYPE",
  [47] = "PLEX",
  [48] = "BGNEXTN",
  [49] = "ENDEXTN",
  [50] = "TAPENUM",
  [51] = "TAPECODE",
  [52] = "STRCLASS",
  [53] = "RESERVED",
  [54] = "FORMAT",
  [55] = "MASK",
  [56] = "ENDMASKS",
  [57] = "LIBDIRSIZE",
  [58] = "SRFNAME",
  [59] = "LIBSECUR",
}

gdsii.datatypes = {
  [0] = "NONE",
  [1] = "BITARRAY",
  [2] = "INT16",
  [3] = "INT32",
  [4] = "REAL",
  [5] = "DOUBLE",
  [6] = "STRING",
}

gdsii.read_string = function(f, n)
  local data = f:read(n)
  assert(#data == n)
  return data
end

gdsii.to_uint = function(data)
  local n = 0
  for i=1,#data do
    n = 256*n + string.byte(data, i)
  end
  return n
end

gdsii.to_int = function(data)
  if bit32.band(string.byte(data, 1), 128) == 0 then
    return gdsii.to_uint(data)
  end
  local n = 0
  for i=1,#data do
    n = 256*n + 255 - string.byte(data, i)
  end
  return -n - 1
end

gdsii.read_u8 = function(f)
  local data = f:read(1)
  assert(#data == 1)
  return gdsii.to_uint(data)
end

gdsii.read_u16 = function(f)
  local data = f:read(2)
  assert(#data == 2)
  return gdsii.to_uint(data)
end

gdsii.read_i16 = function(f)
  local data = f:read(2)
  assert(#data == 2)
  return gdsii.to_int(data)
end

gdsii.read_i32 = function(f)
  local data = f:read(4)
  assert(#data == 4)
  return gdsii.to_int(data)
end

gdsii.read_real8 = function(f)
  local data = f:read(8)
  assert(#data == 8)
  local n = 0
  for i=2,8 do
    n = 256*n + string.byte(data, i)
  end
  if bit32.band(string.byte(data, 1), 128) ~= 0 then
    n = -n
  end
  local exp = bit32.band(string.byte(data, 1), 127) - 64 - 14
  return n * (16 ^ exp)
end

gdsii.read_bitarray = function(f)
  local data = f:read(2)
  assert(#data == 2)
  local bits = {}
  local n = gdsii.to_uint(data)
  for i=1,16 do
    table.insert(bits, bit32.band(n, 2^(i-1)) ~= 0) 
  end
  return bits
end

gdsii.tokenizer = function(f)
  local token = nil
  return function()
    if token and token.id == "ENDLIB" then return nil end
    token = {
      length   = gdsii.read_u16(f),
      id       = gdsii.types[gdsii.read_u8(f)],
      datatype = gdsii.datatypes[gdsii.read_u8(f)],
    }
    return token
  end
end

gdsii.serialize = function(data)
  if type(data) == "string" then
    return string.format("%q", data)
  elseif type(data) == "table" then
    local s = "["
    for k,v in pairs(data) do
      if k == 1 then
        s = s .. gdsii.serialize(v)
      else
        s = s .. "," .. gdsii.serialize(v)
      end
    end
    return s .. "]"
  else
    return tostring(data)
  end
end

gdsii.read_data = function(f, token)
  local data = {}
  if token.datatype == "BITARRAY" then
    data = gdsii.read_bitarray(f)
  elseif token.datatype == "INT16" then
    for i=1,(token.length-4)/2 do
      table.insert(data, gdsii.read_i16(f))
    end
  elseif token.datatype == "INT32" then
    for i=1,(token.length-4)/4 do
      table.insert(data, gdsii.read_i32(f))
    end
  elseif token.datatype == "DOUBLE" then
    for i=1,(token.length-4)/8 do
      table.insert(data, gdsii.read_real8(f))
    end
  elseif token.datatype == "STRING" then
    table.insert(data, gdsii.read_string(f, token.length-4))
  else
    f:seek("cur", token.length-4)
  end
  return data
end

local f = io.input()
for token in gdsii.tokenizer(f) do
  local data = gdsii.read_data(f, token)
  print(token.id, token.datatype, gdsii.serialize(data))
end
f:close()