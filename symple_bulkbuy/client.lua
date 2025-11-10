print("symple_bulkbuy client.lua started")

function ShowNotification(title, message, type)
    if lib and lib.notify then
        lib.notify({
            title = title,
            description = message,
            type = type
        })
    else
        TriggerEvent('QBCore:Notify', message, type)
    end
end

function RemoveBuyerBlip()
    if buyerBlip and DoesBlipExist(buyerBlip) then
        RemoveBlip(buyerBlip)
        buyerBlip = nil
        print("^2[DEBUG]^7 [CLIENT] Buyer blip removed.")
    end
    if buyerWaypoint and DoesBlipExist(buyerWaypoint) then
        RemoveBlip(buyerWaypoint)
        buyerWaypoint = nil
        print("^2[DEBUG]^7 [CLIENT] Buyer waypoint removed.")
    end
end

pedData = {
    model = GetHashKey("a_m_y_downtown_01"),
    scenario = "WORLD_HUMAN_SMOKING",
    dealCooldown = 0,
    lastDealTime = 0
}

pedSpawnLocations = {}
payphoneLocations = {}

ped = nil
isDealing = false
currentOffer = {}
buyerBlip = nil
buyerWaypoint = nil


function AcceptOffer(itemType, quantity, totalPrice)
    print("^2[DEBUG]^7 [CLIENT] Entered AcceptOffer function.")

    local animDict = "mp_common"
    local playerAnim = "givetake1_a"
    local pedAnim = "givetake1_b"
    
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local pedCoords = GetEntityCoords(ped)

    local directionToPlayer = vector3(playerCoords.x - pedCoords.x, playerCoords.y - pedCoords.y, 0.0)
    local directionToPed = vector3(pedCoords.x - playerCoords.x, pedCoords.y - playerCoords.y, 0.0)

    local playerHeading = GetHeadingFromVector_2d(directionToPed.x, directionToPed.y)
    local pedHeading = GetHeadingFromVector_2d(directionToPlayer.x, directionToPlayer.y)

    SetEntityHeading(playerPed, playerHeading)
    SetEntityHeading(ped, pedHeading)

    print("^2[DEBUG]^7 [CLIENT] Requesting animation dictionary: " .. animDict)
    RequestAnimDict(animDict)
    local animLoadTimeout = 0
    while not HasAnimDictLoaded(animDict) do
        Citizen.Wait(100)
        animLoadTimeout = animLoadTimeout + 100
        if animLoadTimeout > 5000 then
            print("^1[ERROR]^7 [CLIENT] Failed to load animation dictionary: " .. animDict .. " after 5 seconds. Skipping animation.")
            break
        end
    end

    if HasAnimDictLoaded(animDict) then
        print("^2[DEBUG]^7 [CLIENT] Animation dictionary loaded.")

        ClearPedTasks(playerPed)
        ClearPedTasks(ped)

        FreezeEntityPosition(playerPed, true)
        FreezeEntityPosition(ped, true)

        TaskPlayAnim(playerPed, animDict, playerAnim, 8.0, -8.0, 3000, 0, 0, false, false, false)
        TaskPlayAnim(ped, animDict, pedAnim, 8.0, -8.0, 3000, 0, 0, false, false, false)
        print("^2[DEBUG]^7 [CLIENT] Exchange animations played.")

        print("^2[DEBUG]^7 [CLIENT] Triggering server event: symple_bulkbuy:completeDeal")
        TriggerServerEvent("symple_bulkbuy:completeDeal", itemType, quantity, totalPrice)

        if math.random(1, 100) <= 40 then
            Citizen.SetTimeout(1500, function()
                local playerCoords = GetEntityCoords(playerPed)
                local streetHash = GetStreetNameAtCoord(playerCoords.x, playerCoords.y, playerCoords.z)
                local streetName = GetStreetNameFromHashKey(streetHash)

                exports['ps-dispatch']:SuspiciousActivity()

                ShowNotification("Alert", "Someone might have spotted your drug deal!", "error")
            end)
        end

        Citizen.Wait(3000)

        FreezeEntityPosition(playerPed, false)
        FreezeEntityPosition(ped, false)

        ClearPedTasks(playerPed)
        ClearPedTasks(ped)
    else
        print("^1[ERROR]^7 [CLIENT] Animation dictionary not loaded, proceeding without animation.")
        TriggerServerEvent("symple_bulkbuy:completeDeal", itemType, quantity, totalPrice)
    end
    
    ShowNotification("Deal Completed", string.format("You sold %s %s for $%s.", quantity, itemType, totalPrice), "success")
    Citizen.SetTimeout(1000, function()
        local weedCount = exports.ox_inventory:GetItemCount("weed_brick")
        local cokeCount = exports.ox_inventory:GetItemCount("coke_brick")
        local cokebaggyCount = exports.ox_inventory:GetItemCount("cokebaggy")
        local lsmethCount = exports.ox_inventory:GetItemCount("ls_meth")
        if (weedCount > 0 or cokeCount > 0 or cokebaggyCount > 0 or lsmethCount > 0) and isDealing then
            ShowDealMenu()
        else
            isDealing = false
            if DoesEntityExist(ped) then
                DeletePed(ped)
                ped = nil
                RemoveBuyerBlip()
            end
        end
    end)
    pedData.lastDealTime = GetGameTimer()
    print("^2[DEBUG]^7 [CLIENT] AcceptOffer function finished.")
end

function MakePedWalkAway()
    if not ped then return end
    FreezeEntityPosition(ped, false)
    SetEntityInvincible(ped, true)
    local pedCoords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    local forwardX = math.sin(math.rad(heading)) * 50.0
    local forwardY = math.cos(math.rad(heading)) * 50.0
    local targetX = pedCoords.x + forwardX
    local targetY = pedCoords.y + forwardY
    TaskGoStraightToCoord(ped, targetX, targetY, pedCoords.z, 1.0, -1, heading, 0.0)
    Citizen.SetTimeout(10000, function()
        if DoesEntityExist(ped) then
            DeletePed(ped)
            ped = nil
        end
    end)
    RemoveBuyerBlip()
end


Citizen.CreateThread(function()
    local timeout = 0
    while not exports.ox_lib do
        Citizen.Wait(100)
        timeout = timeout + 1
        if timeout % 10 == 0 then
            print("Waiting for ox_lib to be ready...")
        end
        if timeout > 100 then
            print("ox_lib not found after timeout, proceeding anyway")
            break
        end
    end
    print("ox_lib is ready.")

    TriggerServerEvent("symple_bulkbuy:requestLocations")

    while #payphoneLocations == 0 do
        Citizen.Wait(100)
    end

    for i, payphoneData in ipairs(payphoneLocations) do
        print("Requesting payphone model: " .. payphoneData.model)
        RequestModel(payphoneData.model)
        local modelTimeout = 0
        while not HasModelLoaded(payphoneData.model) do
            Citizen.Wait(100)
            modelTimeout = modelTimeout + 100
            if modelTimeout > 5000 then
                print("^1[ERROR]^7 Failed to load payphone model: " .. payphoneData.model .. " after 5 seconds.")
                break
            end
        end

        if HasModelLoaded(payphoneData.model) then
            print("Payphone model loaded: " .. payphoneData.model)
            local payphoneProp = CreateObject(payphoneData.model, payphoneData.coords.x, payphoneData.coords.y, payphoneData.coords.z, false, false, false)
            SetEntityHeading(payphoneProp, payphoneData.coords.w)
            FreezeEntityPosition(payphoneProp, true)
            SetEntityInvincible(payphoneProp, true)
            SetModelAsNoLongerNeeded(payphoneData.model)

            if DoesEntityExist(payphoneProp) and exports.ox_target then
                print("Payphone spawned and adding ox_target interaction.")
                exports.ox_target:addLocalEntity(payphoneProp, {
                    {
                        name = 'symple_bulkbuy:callPayphone' .. i,
                        icon = "fas fa-phone",
                        label = "Make a Call",
                        distance = 2.5,
                        onSelect = function()
                            TriggerEvent("symple_bulkbuy:makeCall", i)
                        end
                    }
                })
            else
                print("^1[ERROR]^7 Failed to spawn payphone prop or ox_target not available for payphone " .. i)
            end
        else
            print("^1[ERROR]^7 Payphone model failed to load for location " .. i)
        end
    end

    print("Finished spawning payphones.")
end)

function IsBuyerAvailableNow(locationData)
    local currentHour = GetClockHours()
    for i, timeRange in ipairs(locationData.availableTimes) do
        if currentHour >= timeRange.start and currentHour < timeRange["end"] then
            return true
        end
    end
    return false
end

RegisterNetEvent("symple_bulkbuy:makeCall", function(payphoneIndex)
    ShowNotification("Connecting...", "Attempting to contact the buyer...", "info")

    local usedPayphoneIndex = payphoneIndex or 1

    local payphoneData = payphoneLocations[usedPayphoneIndex]
    if not payphoneData then
        print("^1[ERROR]^7 Invalid payphone index: " .. tostring(usedPayphoneIndex))
        return
    end

    local playerPed = PlayerPedId()
    local payPhoneCoords = payphoneData.coords

    local heading = payPhoneCoords.w
    local playerHeading = heading

    SetEntityHeading(playerPed, playerHeading)

    local animDict = "cellphone@"
    local animName = "cellphone_call_listen_base"

    RequestAnimDict(animDict)
    local animLoadTimeout = 0
    while not HasAnimDictLoaded(animDict) do
        Citizen.Wait(100)
        animLoadTimeout = animLoadTimeout + 100
        if animLoadTimeout > 5000 then
            print("^1[ERROR]^7 Failed to load phone animation dictionary: " .. animDict .. " after 5 seconds.")
            break
        end
    end

    if HasAnimDictLoaded(animDict) then
        DisableControlAction(0, 24, true)
        DisableControlAction(0, 257, true)
        DisableControlAction(0, 25, true)
        DisableControlAction(0, 263, true)

        TaskPlayAnim(playerPed, animDict, animName, 8.0, -8.0, 6000, 49, 0, false, false, false)

        local phoneModel = GetHashKey("prop_npc_phone_02")
        RequestModel(phoneModel)
        local modelLoadTimeout = 0
        while not HasModelLoaded(phoneModel) and modelLoadTimeout < 1000 do
            Citizen.Wait(10)
            modelLoadTimeout = modelLoadTimeout + 10
        end

        local phoneObj = nil
        if HasModelLoaded(phoneModel) then
            phoneObj = CreateObject(phoneModel, 1.0, 1.0, 1.0, true, true, false)
            local boneIndex = GetPedBoneIndex(playerPed, 28422)
            AttachEntityToEntity(phoneObj, playerPed, boneIndex, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, true, true, false, true, 1, true)
        end

        PlaySoundFrontend(-1, "Dial_and_Remote", "Phone_SoundSet_Michael", 1)

        if math.random(1, 100) <= 30 then
            Citizen.SetTimeout(3000, function()
                local playerCoords = GetEntityCoords(playerPed)
                local streetHash = GetStreetNameAtCoord(playerCoords.x, playerCoords.y, playerCoords.z)
                local streetName = GetStreetNameFromHashKey(streetHash)

                exports['ps-dispatch']:SuspiciousActivity({
                    dispatchCode = '10-31',
                    description = 'Suspicious Person Using Payphone',
                    callerName = 'Concerned Citizen',
                    location = streetName,
                    recipientList = {'police'},
                    blipSprite = 480,
                    blipColor = 5,
                    blipScale = 1.0,
                    blipLength = 2*60*1000,
                    sound = '10-31'
                })

                ShowNotification("Alert", "Someone might have reported your suspicious activity.", "error")
            end)
        end

        Citizen.Wait(6000)

        ClearPedTasks(playerPed)
        if phoneObj and DoesEntityExist(phoneObj) then
            DeleteObject(phoneObj)
        end
        SetModelAsNoLongerNeeded(phoneModel)
    else
        ShowNotification("Call Failed", "Could not play calling animation.", "error")
    end

    if DoesEntityExist(ped) then
        DeletePed(ped)
        ped = nil
        RemoveBuyerBlip()
    end

    local buyerLocationIndex = 1
    if payphoneLocations[usedPayphoneIndex] then
        buyerLocationIndex = payphoneLocations[usedPayphoneIndex].buyerLocationIndex
    end

    local spawnData = pedSpawnLocations[buyerLocationIndex]
    if not spawnData or not IsBuyerAvailableNow(spawnData) then
        ShowNotification("No Buyer", "No buyer is available at this location and time. Try again later or try a different payphone.", "info")
        isDealing = false
        return
    end
    pedData.coords = spawnData.coords
    pedData.heading = spawnData.coords.w

    print("Requesting ped model: " .. pedData.model)
    RequestModel(pedData.model)
    local modelTimeout = 0
    while not HasModelLoaded(pedData.model) do
        Citizen.Wait(100)
        modelTimeout = modelTimeout + 100
        if modelTimeout > 5000 then
            print("Failed to load ped model after timeout: " .. pedData.model)
            ShowNotification("Call Failed", "Buyer could not be reached (ped model failed to load).", "error")
            isDealing = false
            return
        end
    end

    if HasModelLoaded(pedData.model) then
        print("Ped model loaded successfully: " .. pedData.model)
    else
        print("Ped model failed to load: " .. pedData.model)
        ShowNotification("Call Failed", "Buyer could not be reached (ped model not loaded).", "error")
        isDealing = false
        return
    end

    print("Creating ped at coordinates: x=" .. pedData.coords.x .. ", y=" .. pedData.coords.y .. ", z=" .. pedData.coords.z)
    ped = CreatePed(4, pedData.model, pedData.coords.x, pedData.coords.y, pedData.coords.z, pedData.coords.w, false, false)
    SetEntityHeading(ped, pedData.coords.w)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    TaskStartScenarioInPlace(ped, pedData.scenario, 0, true)
    SetModelAsNoLongerNeeded(pedData.model)

    if DoesEntityExist(ped) and exports.ox_target then
        print("Ped spawned successfully: " .. pedData.model .. " at " .. tostring(pedData.coords.x) .. ", " .. tostring(pedData.coords.y) .. ", " .. tostring(pedData.coords.z))
        exports.ox_target:addLocalEntity(ped, {
            {
                name = 'symple_bulkbuy:negotiate_deal',
                icon = "fas fa-handshake",
                label = "Negotiate Bulk Deal",
                distance = 2.5,
                onSelect = function()
                    RemoveBuyerBlip()

                    local hasWeed = exports.ox_inventory:GetItemCount("weed_brick") > 0
                    local hasCoke = exports.ox_inventory:GetItemCount("coke_brick") > 0

                    if not hasWeed and not hasCoke then
                        ShowNotification("No Items", "You don't have any weed_brick or coke_brick to sell.", "info")
                        return
                    end
                    TriggerEvent("symple_bulkbuy:startNegotiation")
                end
            }
        })
        buyerBlip = AddBlipForEntity(ped)
        SetBlipSprite(buyerBlip, 1)
        SetBlipDisplay(buyerBlip, 4)
        SetBlipScale(buyerBlip, 0.8)
        SetBlipColour(buyerBlip, 2)
        SetBlipAsShortRange(buyerBlip, true)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentSubstringPlayerName("Special Buyer")
        EndTextCommandSetBlipName(buyerBlip)

        buyerWaypoint = AddBlipForCoord(pedData.coords.x, pedData.coords.y, pedData.coords.z)
        SetBlipSprite(buyerWaypoint, 8)
        SetBlipDisplay(buyerWaypoint, 4)
        SetBlipScale(buyerWaypoint, 1.0)
        SetBlipColour(buyerWaypoint, 2)
        SetBlipAsShortRange(buyerWaypoint, true)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentSubstringPlayerName("Buyer Location")
        EndTextCommandSetBlipName(buyerWaypoint)

        ShowNotification("Meeting Point", "The buyer is waiting at a discreet location. Check your map!", "success")

        Citizen.CreateThread(function()
            Citizen.Wait(900 * 1000)
            if DoesEntityExist(ped) then
                DeletePed(ped)
                ped = nil
                RemoveBuyerBlip()
                ShowNotification("Buyer Left", "The special buyer has left the area.", "info")
            end
        end)
    else
        print("^1[ERROR]^7 Failed to spawn ped or ox_target not available for new ped.")
        ShowNotification("Call Failed", "Buyer could not be reached.", "error")
        isDealing = false
    end
end)

function ShowDealMenu()
    isDealing = true
    local weedCount = exports.ox_inventory:GetItemCount("weed_brick")
    local cokeCount = exports.ox_inventory:GetItemCount("coke_brick")
    local cokebaggyCount = exports.ox_inventory:GetItemCount("cokebaggy")
    local lsmethCount = exports.ox_inventory:GetItemCount("ls_meth")

    if weedCount <= 0 and cokeCount <= 0 and cokebaggyCount <= 0 and lsmethCount <= 0 then
        ShowNotification("No Items", "You don't have any items to sell.", "info")
        isDealing = false
        if DoesEntityExist(ped) then
            DeletePed(ped)
            ped = nil
            RemoveBuyerBlip()
        end
        return
    end

    local menuOptions = {}
    if weedCount > 0 then
        table.insert(menuOptions, {
            title = string.format("Sell All Weed Bricks (x%d)", weedCount),
            description = string.format("Sell all for $%d", weedCount * 12000),
            icon = "fas fa-cannabis",
            onSelect = function()
                AcceptOffer("weed_brick", weedCount, weedCount * 12000)
            end
        })
    end
    if cokeCount > 0 then
        table.insert(menuOptions, {
            title = string.format("Sell All Coke Bricks (x%d)", cokeCount),
            description = string.format("Sell all for $%d", cokeCount * 18000),
            icon = "fas fa-capsules",
            onSelect = function()
                AcceptOffer("coke_brick", cokeCount, cokeCount * 18000)
            end
        })
    end
    if cokebaggyCount >= 500 then
        local numBatches = math.floor(cokebaggyCount / 500)
        table.insert(menuOptions, {
            title = string.format("Sell All Cocaine (x%d bags)", numBatches * 500),
            description = string.format("Sell all for $%d", numBatches * 8500),
            icon = "fas fa-snowflake",
            onSelect = function()
                AcceptOffer("cokebaggy", numBatches * 500, numBatches * 8500)
            end
        })
    end
    if lsmethCount >= 500 then
        local numBatches = math.floor(lsmethCount / 500)
        table.insert(menuOptions, {
            title = string.format("Sell All Meth (x%d bags)", numBatches * 500),
            description = string.format("Sell all for $%d", numBatches * 8000),
            icon = "fas fa-flask",
            onSelect = function()
                AcceptOffer("ls_meth", numBatches * 500, numBatches * 8000)
            end
        })
    end
    table.insert(menuOptions, {
        title = "Decline Offer",
        description = "Walk away from the deal",
        icon = "fas fa-times",
        onSelect = function()
            isDealing = false
            ShowNotification("Deal Declined", "You declined the buyer's offer.", "info")
            if DoesEntityExist(ped) then
                DeletePed(ped)
                ped = nil
                RemoveBuyerBlip()
            end
        end
    })

    if lib and lib.registerContext then
        lib.registerContext({
            id = 'deal_menu',
            title = 'Negotiate Deal',
            options = menuOptions
        })
        lib.showContext('deal_menu')
    else
        local optionText = ""
        for i, opt in ipairs(menuOptions) do
            optionText = optionText .. string.format("%d for %s ", i, opt.title)
            if i < #menuOptions then optionText = optionText .. "or " end
        end
        TriggerEvent('QBCore:Notify', "Press " .. optionText, 'primary', 5000)
    end
end

function GenerateOffer(itemType)
    local itemCount = exports.ox_inventory:GetItemCount(itemType)

    local minRequired = 1
    local pricePerUnit = 0
    local minPrice = 0
    local maxPrice = 0

    if itemType == "weed_brick" then
        minRequired = 1
        minPrice = 12000
        maxPrice = 12000
        pricePerUnit = 12000
    elseif itemType == "coke_brick" then
        minRequired = 1
        minPrice = 18000
        maxPrice = 18000
        pricePerUnit = 18000
    elseif itemType == "cokebaggy" then
        minRequired = 500
        minPrice = 10000
        maxPrice = 10000
        pricePerUnit = 20
    elseif itemType == "ls_meth" then
        minRequired = 500
        minPrice = 8500
        maxPrice = 8500
        pricePerUnit = 17
    end

    if itemCount < minRequired then
        ShowNotification("Not Enough Items", string.format("You need at least %d of %s to sell.", minRequired, itemType:gsub("_", " ")), "error")
        isDealing = false
        if DoesEntityExist(ped) then
            DeletePed(ped)
            ped = nil
            RemoveBuyerBlip()
        end
        return
    end

    local totalQuantityToSell = minRequired
    if itemType == "weed_brick" or itemType == "coke_brick" then
        totalQuantityToSell = 1
        local randomPrice = math.random(minPrice, maxPrice)
        pricePerUnit = randomPrice
        totalPrice = randomPrice * totalQuantityToSell
    else
        totalPrice = math.random(minPrice, maxPrice)
    end

    currentOffer = {
        item = itemType,
        quantity = totalQuantityToSell,
        pricePerItem = pricePerUnit,
        totalPrice = totalPrice,
        counterHigh = math.floor(pricePerUnit * 1.1) * totalQuantityToSell
    }

    local offerText = string.format("I'll give you $%s for all %d of your %s. That's $%s per %s.",
        currentOffer.totalPrice, currentOffer.quantity, itemType:gsub("_", " "), currentOffer.pricePerItem, (itemType == "weed_brick" or itemType == "coke_brick") and "brick" or "bag")

    if lib and lib.registerContext then
        lib.registerContext({
            id = 'negotiation_menu',
            title = 'Buyer Offer',
            menu = 'deal_menu',
            onExit = function()
                isDealing = false
                ShowNotification("Deal Cancelled", "You walked away from the deal.", "info")
                if DoesEntityExist(ped) then
                    DeletePed(ped)
                    ped = nil
                    RemoveBuyerBlip()
                end
            end,
            options = {
                {
                    title = "Accept Offer",
                    description = offerText,
                    arrow = true,
                    onSelect = function()
                        AcceptOffer(currentOffer.item, currentOffer.quantity, currentOffer.totalPrice)
                    end
                },
                {
                    title = "Counter Offer",
                    description = "Try to get a better price (10% higher)",
                    icon = "fas fa-hand-holding-usd",
                    onSelect = function()
                        ShowNotification("Negotiation", "Negotiation in progress...", "info")

                        local counterOfferPrice = math.floor(currentOffer.pricePerItem * 1.1) * currentOffer.quantity

                        local playerPed = PlayerPedId()
                        local playerCoords = GetEntityCoords(playerPed)
                        local pedCoords = GetEntityCoords(ped)

                        local directionToPlayer = vector3(playerCoords.x - pedCoords.x, playerCoords.y - pedCoords.y, 0.0)
                        local directionToPed = vector3(pedCoords.x - playerCoords.x, pedCoords.y - playerCoords.y, 0.0)

                        local playerHeading = GetHeadingFromVector_2d(directionToPed.x, directionToPed.y)
                        local pedHeading = GetHeadingFromVector_2d(directionToPlayer.x, directionToPlayer.y)

                        SetEntityHeading(playerPed, playerHeading)
                        SetEntityHeading(ped, pedHeading)

                        local animDict = "misscarsteal4@actor"
                        local playerAnim = "actor_berating_loop"
                        local pedAnim = "car_steal_1_ext_leadin"

                        RequestAnimDict(animDict)
                        local timeout = 0
                        while not HasAnimDictLoaded(animDict) and timeout < 1000 do
                            Citizen.Wait(10)
                            timeout = timeout + 10
                        end

                        if HasAnimDictLoaded(animDict) then
                            TaskPlayAnim(playerPed, animDict, playerAnim, 8.0, -8.0, 3000, 0, 0, false, false, false)
                            TaskPlayAnim(ped, animDict, pedAnim, 8.0, -8.0, 3000, 0, 0, false, false, false)
                        end

                        Citizen.SetTimeout(3000, function()
                            if math.random(1, 100) <= 70 then
                                local finalOfferTotal = counterOfferPrice
                                ShowNotification("Offer Accepted!", string.format("Buyer accepted your counter offer of $%s for %d %s!", finalOfferTotal, currentOffer.quantity, currentOffer.item:gsub("_", " ")), "success")
                                AcceptOffer(currentOffer.item, currentOffer.quantity, finalOfferTotal)
                            else
                                ShowNotification("Buyer Declined", "Your counter offer was rejected. Buyer is walking away.", "error")
                                isDealing = false

                                if DoesEntityExist(ped) then
                                    FreezeEntityPosition(ped, false)
                                    SetEntityInvincible(ped, true)
                                    SetBlockingOfNonTemporaryEvents(ped, true)

                                    ClearPedTasksImmediately(ped)

                                    local pedCoords = GetEntityCoords(ped)
                                    local heading = GetEntityHeading(ped)
                                    local forwardX = math.sin(math.rad(heading)) * 50.0
                                    local forwardY = math.cos(math.rad(heading)) * 50.0
                                    local targetX = pedCoords.x + forwardX
                                    local targetY = pedCoords.y + forwardY

                                    TaskGoStraightToCoord(ped, targetX, targetY, pedCoords.z, 1.0, -1, heading, 0.0)

                                    Citizen.SetTimeout(10000, function()
                                        if DoesEntityExist(ped) then
                                            DeletePed(ped)
                                            ped = nil
                                        end
                                    end)

                                    RemoveBuyerBlip()
                                end
                            end
                        end)
                    end
                },
                {
                    title = "Decline Offer",
                    description = "Walk away from the deal",
                    icon = "fas fa-times",
                    onSelect = function()
                        isDealing = false
                        ShowNotification("Deal Declined", "You declined the buyer's offer.", "info")
                        if DoesEntityExist(ped) then
                            DeletePed(ped)
                            ped = nil
                            RemoveBuyerBlip()
                        end
                    end
                }
            }
        })

        lib.showContext('negotiation_menu')
    else
        TriggerEvent('QBCore:Notify', offerText .. " Press 1 to Accept, 2 to Counter, 3 to Decline.", 'primary', 7000)

        Citizen.CreateThread(function()
            local keyPressed = false
            local startTime = GetGameTimer()

            while not keyPressed and GetGameTimer() - startTime < 10000 do
                Citizen.Wait(0)
                if IsControlJustPressed(0, 157) then
                    keyPressed = true
                    AcceptOffer(currentOffer.item, currentOffer.quantity, currentOffer.totalPrice)
                elseif IsControlJustPressed(0, 158) then
                    keyPressed = true
                    ShowNotification("Counter Not Supported", "Counter offers not supported in simple UI. Accepted original offer.", "info")
                    AcceptOffer(currentOffer.item, currentOffer.quantity, currentOffer.totalPrice)
                elseif IsControlJustPressed(0, 194) then
                    keyPressed = true
                    isDealing = false
                    TriggerEvent('QBCore:Notify', "Deal timed out", 'error')
                    if DoesEntityExist(ped) then
                        DeletePed(ped)
                        ped = nil
                        RemoveBuyerBlip()
                    end
                end
            end

            if not keyPressed then
                isDealing = false
                TriggerEvent('QBCore:Notify', "Deal timed out", 'error')
                if DoesEntityExist(ped) then
                    DeletePed(ped)
                    ped = nil
                    RemoveBuyerBlip()
                end
            end
        end)
    end
end

RegisterNetEvent("symple_bulkbuy:startNegotiation", function()
    local hasWeed = exports.ox_inventory:GetItemCount("weed_brick") > 0
    local hasCoke = exports.ox_inventory:GetItemCount("coke_brick") > 0

    if not hasWeed and not hasCoke then
        ShowNotification("No Items", "You don't have any weed_brick or coke_brick to sell.", "info")
        isDealing = false
        return
    end

    if isDealing then
        ShowNotification("Negotiation in Progress", "You are already in a negotiation.", "warning")
        return
    end

    if (GetGameTimer() - pedData.lastDealTime) < pedData.dealCooldown then
        ShowNotification("Cooldown", "The buyer is busy. Try again later.", "warning")
        return
    end

    isDealing = true

    local pedDialogues = {
        "What do you got?",
        "Let's see what you're selling.",
        "You here to make a deal?",
        "Show me the goods."
    }
    local randomDialogue = pedDialogues[math.random(#pedDialogues)]

    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local pedCoords = GetEntityCoords(ped)

    TaskTurnPedToFaceEntity(playerPed, ped, 1000)
    TaskTurnPedToFaceEntity(ped, playerPed, 1000)

    Citizen.Wait(1000)

    local animDict = "mp_common"
    local animName = "givetake1_a"

    RequestAnimDict(animDict)
    while not HasAnimDictLoaded(animDict) do
        Citizen.Wait(10)
    end

    TaskPlayAnim(ped, animDict, animName, 8.0, -8.0, -1, 48, 0, false, false, false)

    ShowDealMenu()

end)

RegisterNetEvent("symple_bulkbuy:receiveLocations", function(spawnLocs, phoneLocs)
    pedSpawnLocations = spawnLocs
    payphoneLocations = phoneLocs
    print("Received location data from server.")
end)

RegisterNetEvent("symple_bulkbuy:showNotification", function(title, message, type)
    ShowNotification(title, message, type)
end)
