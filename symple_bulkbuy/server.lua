pedSpawnLocations = {
    { coords = vector4(1240.19, -3322.32, 5.03, 242.36), availableTimes = { { start = 15, ["end"] = 24 } } },
    { coords = vector4(473.62, -978.31, 26.98, 353.57), availableTimes = { { start = 8, ["end"] = 18 } } },
    { coords = vector4(-306.32, 6275.25, 30.49, 42.87), availableTimes = { { start = 14, ["end"] = 24 } } },
}

payphoneLocations = {
    { coords = vector4(69.66, 3760.87, 38.74, 0.85), model = GetHashKey("prop_phonebox_04"), buyerLocationIndex = 1 },
    { coords = vector4(813.36, -2527.26, 39.53, 90.79), model = GetHashKey("prop_phonebox_04"), buyerLocationIndex = 2 },
    { coords = vector4(1141.61, -2049.46, 30.02, 80.06), model = GetHashKey("prop_phonebox_04"), buyerLocationIndex = 3 }
}

RegisterNetEvent("symple_bulkbuy:completeDeal", function(itemType, quantity, totalPrice)
    print("^3[SERVER]^7 completeDeal event received with: itemType=" .. tostring(itemType) .. ", quantity=" .. tostring(quantity) .. ", totalPrice=" .. tostring(totalPrice))
    local _source = source
    local QBCore = exports['qb-core']:GetCoreObject()
    local Player = QBCore.Functions.GetPlayer(_source)
    print("^3[SERVER]^7 Player found: " .. tostring(Player ~= nil))

    if Player then
        local hasItems = exports.ox_inventory:GetItem(_source, itemType, nil, true)
        print("^3[SERVER]^7 Player has " .. tostring(hasItems) .. " of " .. itemType .. " according to server")

        if hasItems < quantity then
            print("^1[SERVER ERROR]^7 Player attempted to sell more items than they have! Possible exploitation attempt.")
            TriggerClientEvent('QBCore:Notify', _source, "Transaction failed: You don't have enough items.", 'error')
            return
        end

        print("^3[SERVER]^7 Player cash before: " .. tostring(Player.Functions.GetMoney('cash')))
        print("^3[SERVER]^7 Adding $" .. totalPrice .. " to player's cash")
        local success = Player.Functions.AddMoney('cash', totalPrice)
        print("^3[SERVER]^7 AddMoney result: " .. tostring(success ~= nil))
        print("^3[SERVER]^7 Player cash after: " .. tostring(Player.Functions.GetMoney('cash')))

        local removed = exports.ox_inventory:RemoveItem(_source, itemType, quantity)
        print("^3[SERVER]^7 RemoveItem result: " .. tostring(removed ~= nil))

        if not removed then
            print("^1[SERVER ERROR]^7 Failed to remove items from inventory, rolling back money")
            Player.Functions.RemoveMoney('cash', totalPrice)
            TriggerClientEvent('QBCore:Notify', _source, "Transaction failed: Inventory error.", 'error')
            return
        end

        TriggerClientEvent('QBCore:Notify', _source, string.format("You received $%s for your %s %s.", totalPrice, quantity, itemType), 'success')

        TriggerClientEvent('ox_lib:notify', _source, {
            title = 'Deal Complete',
            description = string.format("You received $%s for your %s %s.", totalPrice, quantity, itemType),
            type = 'success'
        })
    else
        print("^1[SERVER ERROR]^7 Player not found for completeDeal event.")
    end
end)

RegisterNetEvent("symple_bulkbuy:requestLocations", function()
    local _source = source
    TriggerClientEvent("symple_bulkbuy:receiveLocations", _source, pedSpawnLocations, payphoneLocations)
end)
