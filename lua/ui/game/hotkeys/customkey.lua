KeyOrderZ = function(clearCommands)
    local info = GetRolloverInfo()
    if info.userUnit then
        SimCallback({ Func = 'CopyOrders', Args = { Target = , ClearCommands = clearCommands or false } }, true)
    end
end
