local QBCore = exports['qb-core']:GetCoreObject()

RegisterNetEvent('vivify_drugRun:server:startRunCheck', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)

    if not Player then return end

    local money = Player.Functions.GetMoney("cash")
    local hasItem = Player.Functions.GetItemByName(Config.StartItem)

    if money >= Config.StartMoney and hasItem then
        Player.Functions.RemoveMoney("cash", Config.StartMoney, "Started Drug Run")
        Player.Functions.RemoveItem(Config.StartItem, 1)
        TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[Config.StartItem], 'remove')

        TriggerClientEvent('QBCore:Notify', src, "You paid $" .. Config.StartMoney .. " and handed over your " .. Config.StartItem .. " to start the run.", "success")
        TriggerClientEvent('vivify_drugRun:client:startRun', src)
    else
        if money < Config.StartMoney then
            TriggerClientEvent('QBCore:Notify', src, "You don't have enough money to start the run.", "error")
        end
        if not hasItem then
            TriggerClientEvent('QBCore:Notify', src, "You need a " .. Config.StartItem .. " to start the run.", "error")
        end
    end
end)

RegisterNetEvent("vivify_drugRun:server:storeTrunkItems", function(randomPlate)
    local src = source
    local trunkId = "trunk-" .. tostring(randomPlate)

    local items = {
        [1] = {name = Config.TrunkItem.item, amount = Config.TrunkItem.count}
    }

    if Config.TrunkItem and Config.TrunkItem.item and Config.TrunkItem.count then
        exports['qb-inventory']:CreateInventory(trunkId)
        Wait(5)
        exports['qb-inventory']:AddItem(trunkId, Config.TrunkItem.item, Config.TrunkItem.count)
    else
        print("Error: Config values missing.")
    end
end)

QBCore.Functions.CreateCallback('vivify_drugRun:server:hasItem', function(source, cb, itemName)
    local Player = QBCore.Functions.GetPlayer(source)
    if Player then
        local item = Player.Functions.GetItemByName(itemName)
        cb(item ~= nil and item.amount > 0)
    else
        cb(false)
    end
end)

-- Server event to remove the trunk item
RegisterNetEvent('vivify_drugRun:server:removePackage', function(item, amount)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)

    if Player then
        if Player.Functions.RemoveItem(item, amount) then
            TriggerClientEvent('QBCore:Notify', src, "Package delivered successfully!", "success")
        else
            TriggerClientEvent('QBCore:Notify', src, "You don't have the required package!", "error")
        end
    end
end)

RegisterNetEvent("vivify_drugRun:server:addItem", function(itemName, amount)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)

    if Player then
        Player.Functions.AddItem(itemName, amount)
        TriggerClientEvent("inventory:client:ItemBox", src, QBCore.Shared.Items[itemName], "add")
    end
end)

RegisterNetEvent('vivify_drugRun:server:giveReward', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)

    if Player then
        local rewardItem = Config.RewardItem
        local rewardAmount = math.random(1,3)

        Player.Functions.AddItem(rewardItem, rewardAmount)
        TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[rewardItem], 'add')
    end
end)

RegisterNetEvent('vivify_drugRun:server:endRun', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)

    if not Player then return end

    Player.Functions.AddMoney("cash", Config.StartMoney, "Refunded for ending Drug Run")
    TriggerClientEvent('QBCore:Notify', src, "You received your $" .. Config.StartMoney .. " back for returning the van.", "success")

--[[     if Config.RewardItem then
        Player.Functions.AddItem(Config.RewardItem, math.random(2, 6))
        TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[Config.RewardItem], 'add')
        TriggerClientEvent('QBCore:Notify', src, "You received a " .. Config.RewardItem .. " as a bonus.", "success")
    end ]]
end)
