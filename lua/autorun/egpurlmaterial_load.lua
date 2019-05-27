if CLIENT then
  file.CreateDir "egpurlmaterial"

  hook.Add("ShutDown", "EGPURLMATERIAL_CLEANUP", function()
    for k, name in ipairs(file.Find("egpurlmaterial/*", "DATA")) do
      file.Delete("egpurlmaterial/" .. name)
    end
  end)
end

local function searchForFunction(name, level, getlast)
  level = level or 2
  local found

  while true do
    local info = debug.getinfo(level, 'n')

    if info then
      if info.name == name then
        if getlast then
          found = level
        else
          return level
        end
      end
    else
      return found
    end

    level = level + 1
  end
end

local function searchForVariable(name, level)
  local position = 1

  while true do
    local k, v = debug.getlocal(level, position)

    if not k then
      return false
    elseif k == name then
      return true, v
    end

    position = position + 1
  end
end

local function getObjectAndEnt()
  local objectreceive = searchForFunction "Receive"
  if not objectreceive then
    ErrorNoHalt "[EGPUrlMaterial]: Can't find Object.Receive\n"
    return
  end

  local found, obj = searchForVariable("self", objectreceive)
  if not found then
    ErrorNoHalt "[EGPUrlMaterial]: Can't find Object\n"
    return
  end

  -- Objects commonly have nested receives from baseclasses, we want the upper most one
  local egpreceive = searchForFunction("Receive", objectreceive + 1, true)
  if not egpreceive then
    ErrorNoHalt "[EGPUrlMaterial]: Can't find EGP.Receive\n"
    return
  end

  local found, ent = searchForVariable("Ent", egpreceive)
  if not found then
    ErrorNoHalt "[EGPUrlMaterial]: Can't find Ent\n"
    return
  end

  return obj, ent
end

hook.Add("Initialize", "EGPURLMATERIAL_LOAD", function()
  if not EGP then
    ErrorNoHalt "[EGPUrlMaterial]: Wiremod is either not installed or hasn't loaded correctly"
    return
  end

  if SERVER then return end

  local urlMatLookup = {}
  local urlMatQueue  = {}

  function EGP:ReceiveMaterial(tbl)
    local temp = net.ReadString()
    local what, mat = temp:sub(1,1), temp:sub(2)
    if what == "0" then
    if mat:sub(1, 4) == "http" then
        local obj, ent = getObjectAndEnt()

        tbl.material = tbl.material or false

        local extension = string.match(mat, ".+(%.%w+)$")

        if ent and obj and extension then
          local hash = util.CRC(mat)

          if urlMatLookup[hash] then
            tbl.material = urlMatLookup[hash]
          elseif urlMatQueue[hash] then
            table.insert(urlMatQueue[hash], {obj, ent})
          else
            urlMatQueue[hash] = {{obj, ent}}

            http.Fetch(mat, function(body)
              local fileName = "egpurlmaterial/" .. tostring(hash) .. extension

              if not file.Exists(fileName, "DATA") then
                file.Write(fileName, body)
              end

              if not urlMatLookup[hash] then
                urlMatLookup[hash] = Material("../data/" .. fileName, "smooth")
              end

              for _, data in ipairs(urlMatQueue[hash]) do
                if data[2]:IsValid() then
                  data[1].material = urlMatLookup[hash]
                  data[2]:EGP_Update()
                end
              end

              urlMatQueue[hash] = nil
            end, function()
              -- Should we blacklist the link?
              urlMatQueue[hash] = nil
            end)
          end
        end
      elseif mat == "" then
        tbl.material = false
      else
        tbl.material = Material(mat)
      end
    elseif what == "1" then
      local num = tonumber(mat)
      if not num or not IsValid(Entity(num)) then
        tbl.material = false
      else
        tbl.material = Entity(num)
      end
    end
  end
end)