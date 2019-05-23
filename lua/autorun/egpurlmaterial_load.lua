if CLIENT then
  file.CreateDir "egpurlmaterial"

  hook.Add("ShutDown", "EGPURLMATERIAL_CLEANUP", function()
    for k, name in ipairs(file.Find("egpurlmaterial/*", "DATA")) do
      file.Delete("egpurlmaterial/" .. name)
    end
  end)
end

hook.Add("Initialize", "EGPURLMATERIAL_LOAD", function()
  if not EGP then
    ErrorNoHalt "[EGPUrlMaterial]: Wiremod is either not installed or hasn't loaded correctly"
    return
  end

  if SERVER then return end

  local urlMatLookup = {}

  function EGP:ReceiveMaterial(tbl)
    local temp = net.ReadString()
    local what, mat = temp:sub(1,1), temp:sub(2)
    if what == "0" then
    if mat:sub(1, 4) == "http" then
        local name, ent = debug.getlocal(4, 3)
        if name ~= "Ent" or not isentity(ent) then
          ent = nil
          ErrorNoHalt "[EGPUrlMaterial]: [ENT] This addons needs to be updated to work with the latest version of wiremod\n"
        end

        local name, obj = debug.getlocal(3, 1)
        if name ~= "self" or not istable(obj) then
          obj = nil
          ErrorNoHalt "[EGPUrlMaterial]: [OBJ] This addons needs to be updated to work with the latest version of wiremod\n"
        end

        tbl.material = tbl.material or false

        local extension = string.match(mat, ".+(%.%w+)$")

        if ent and obj and extension then
          local hash = util.CRC(mat)

          if urlMatLookup[hash] then
            tbl.material = urlMatLookup[hash]
          else
            http.Fetch(mat, function(body)
              if not IsValid(ent) then return end

              local fileName = "egpurlmaterial/" .. tostring(hash) .. extension

              if not file.Exists(fileName, "DATA") then
                file.Write(fileName, body)
              end

              if not urlMatLookup[hash] then
                urlMatLookup[hash] = Material("../data/" .. fileName, "smooth")
              end

              obj.material = urlMatLookup[hash]
              ent:EGP_Update()
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
