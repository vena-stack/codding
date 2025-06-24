local FileCollapsePath = FileCollapsePath
local doscript = doscript
local pcall = pcall
local setmetatable = setmetatable

local LOG = LOG
local SPEW = SPEW
local WARN = WARN
local error = error

__modules = {}
local oldModules = {}

__module_metatable = {
    __index = _G
}


local informDevOfLoad = false

local function LoadModule(module)
    local modules = __modules

    local moduleinfo = module.__moduleinfo
    local name = moduleinfo.name

    local oldMod = oldModules[name]
    if oldMod then
        moduleinfo.old = oldMod
    end

    setmetatable(module, __module_metatable)

    local ok, msg = pcall(doscript, name, module)
    if oldMod then
        oldModules[name] = nil
        moduleinfo.old = nil
        local onReload = oldMod.__moduleinfo.OnReload
        if onReload then
            onReload(module)
        end
    end

    if not ok then
        modules[name] = nil
        WARN(msg)
        error("Error importing '" .. name .. "'", 2)
    end

    moduleinfo.track_imports = false
    return module

end

local __lazyimport_metatable = {
    __index = function(tbl, key)
        LoadModule(tbl)
        return tbl[key]
    end,

    __newindex = function(tbl, key, val)
        LoadModule(tbl)
         tbl[key]=val
    end,
}
local indent = 0

-- Table to track module load counts and actions
local unit_config = {
    --
    --["/units//_script.lua"] = { max_loads = 5, action = function() PrintText("", 30, "ff00ff00", 4 , 'rightcenter') end },
    --["/units//_script.lua"] = { max_loads = 5, action = function() PrintText("", 30, "00ffff00", 4 , 'rightcenter') end },
    --["/units//_script.lua"] = { max_loads = 5, action = function() PrintText("", 30, "ffff0000", 4 , 'rightcenter') end },
    --["/units//_script.lua"] = { max_loads = 5, action = function() PrintText("", 30, "ff0000ff", 4 , 'rightcenter') end },

}

local module_load_counts = {}


function import(name, isLazy)
    local modules = __modules 

    if string.find(name, "/units/") then

        local config = unit_config[name]

        if config then
            local max_loads = config.max_loads or 9999  
            local action = config.action

            if (module_load_counts[name] or 0) < max_loads then
                if action then
                    action() 
                end
                module_load_counts[name] = (module_load_counts[name] or 0) + 1
            end
        end
    end

    local existing = modules[name]
    if existing then
        return existing
    end

    name = name:lower()
    existing = modules[name]
    if existing then
        return existing
    end

    if informDevOfLoad then
        SPEW(string.format("%sLoading module: %s", string.rep("-> ", indent) or "", name))
        indent = indent + 1
    end

    local moduleinfo = {
        name = name,
        used_by = {},
        track_imports = true,
    }

    local _import = function(name2, isLazy)
        if name2:sub(1, 1) != '/' then
            name2 = FileCollapsePath(name .. '/../' .. name2)
        end
        local module2 = import(name2, isLazy) 
        if __modules[name].__moduleinfo.track_imports then
            module2.__moduleinfo.used_by[name] = true
        end
        return module2
    end

    local module = {
        __moduleinfo = moduleinfo,
        import = _import,
        lazyimport = function (name2)
            return _import(name2, true)
        end
    }
    modules[name] = module

    if isLazy then
        setmetatable(module, __lazyimport_metatable)
    else
        LoadModule(module)
    end

    if informDevOfLoad then
        indent = indent + 1
    end

    return module
end

function lazyimport(name)
    return import(name, true)
end


function dirty_module(name, why)
    local modules = __modules
    local module = modules[name]
    if module then
        if why then LOG("Module '", name, "' changed on disk") end
        LOG("  marking '", name, "' for reload")

        local moduleinfo = module.__moduleinfo
        local onDirty = moduleinfo.OnDirty
        if onDirty then
            local ok, msg = pcall(onDirty)
            if not ok then
                WARN(msg)
            end
        end
        oldModules[name] = module

        modules[name] = nil
        local deps = moduleinfo.used_by
        if deps then
            for k, _ in deps do
                dirty_module(k)
            end
        end
    end
end

table.insert(__diskwatch, dirty_module)
