local QBCore = exports['qb-core']:GetCoreObject()
local isPedSpawned = false
local pedHandle
local isCooldownActive = false
local spawnedVehicle

local currentLocationIndex = 1
local isRunActive = false
local dropLocations = {}

local isCarryingBox = false

function CheckForBox()
    QBCore.Functions.TriggerCallback('QBCore:HasItem', function(hasItem)
        if hasItem and not isCarryingBox then
            StartCarryingBox()
        elseif not hasItem and isCarryingBox then
            StopCarryingBox()
        end
    end, Config.TrunkItem.item)
end

function StartCarryingBox()
    local player = PlayerPedId()

    RequestAnimDict("anim@heists@box_carry@")
    while not HasAnimDictLoaded("anim@heists@box_carry@") do
        Wait(100)
    end

    local boxModel = GetHashKey("prop_mp_drug_package")

    RequestModel(boxModel)
    while not HasModelLoaded(boxModel) do
        Wait(10)
    end

    local box = CreateObject(boxModel, 0.0, 0.0, 0.0, true, true, true)
    AttachEntityToEntity(box, player, GetPedBoneIndex(player, 28422), 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, true, true, false, true, 1, true)

    TaskPlayAnim(player, "anim@heists@box_carry@", "idle", 5.0, -1, -1, 50, 0, false, false, false)

    isCarryingBox = true
end

function StopCarryingBox()
    local player = PlayerPedId()
    ClearPedTasks(player)
    isCarryingBox = false
end

CreateThread(function()
    while true do
        Wait(500)
        if isRunActive then
            CheckForBox()
        end
    end
end)

function StartDrugRun()
    if isRunActive then
        TriggerEvent('QBCore:Notify', "You already have an active run!", "error")
        return
    end

    local totalLocations = #Config.DropSpots
    if totalLocations < 10 then
        TriggerEvent('QBCore:Notify', "Not enough drop locations configured!", "error")
        return
    end

    dropLocations = {}
    while #dropLocations < 10 do
        local randomLocation = Config.DropSpots[math.random(1, totalLocations)]
        if not TableContains(dropLocations, randomLocation) then
            table.insert(dropLocations, randomLocation)
        end
    end

    currentLocationIndex = 1
    isRunActive = true
    TriggerEvent('QBCore:Notify', "The run has started! Head to the first drop location.", "success")

    SetNextLocation()
end

function SetNextLocation()
    if currentLocationIndex > #dropLocations then
        EndDrugRun()
        return
    end

    local location = dropLocations[currentLocationIndex]

    SpawnPed(location)

    SetNewWaypoint(location.x, location.y)
    TriggerEvent('QBCore:Notify', "Go to the marked location for the next drop.", "info")
end

function SpawnPed(location)
    local pedModel = GetHashKey("a_m_m_business_01")
    RequestModel(pedModel)
    while not HasModelLoaded(pedModel) do
        Citizen.Wait(10)
    end

    local ped = CreatePed(4, pedModel, location.x + 3, location.y, location.z - 1, 0.0, true, true)
    SetEntityAsMissionEntity(ped, true, true)
    FreezeEntityPosition(ped, true)
    TaskStartScenarioInPlace(ped, "WORLD_HUMAN_STAND_MOBILE", 0, true)

    exports['qb-target']:AddTargetEntity(ped, {
        options = {
            {
                label = "Deliver Package",
                icon = "fas fa-box",
                action = function(entity)
                    InteractWithPed(entity)
                end
            },
        },
        distance = 2.5,
    })
end

function InteractWithPed(ped)
    QBCore.Functions.TriggerCallback('vivify_drugRun:server:hasItem', function(hasItem)
        if not hasItem then
            TriggerEvent('QBCore:Notify', "You don't have the required package to deliver!", "error")
            return
        end

        TriggerServerEvent('vivify_drugRun:server:removePackage', Config.Package.item, 1)

        ClearPedTasks(ped)

        FreezeEntityPosition(ped, false)

        local boxModel = GetHashKey("prop_mp_drug_package")

        RequestModel(boxModel)
        while not HasModelLoaded(boxModel) do
            Citizen.Wait(10)
        end

        RequestAnimDict("anim@heists@box_carry@")
        while not HasAnimDictLoaded("anim@heists@box_carry@") do
            Wait(100)
        end

        local box = CreateObject(boxModel, 0.0, 0.0, 0.0, true, true, true)
        AttachEntityToEntity(box, ped, GetPedBoneIndex(ped, 28422), 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, true, true, false, true, 1, true)

        TaskPlayAnim(ped, "anim@heists@box_carry@", "idle", 5.0, -1, -1, 50, 0, false, false, false)

        Wait(3000)
    
        TaskWanderStandard(ped, 10.0, 10)

        currentLocationIndex = currentLocationIndex + 1
        SetNextLocation()

        TriggerServerEvent('vivify_drugRun:server:giveReward')

        Wait(5000)
    
        DeleteEntity(box)
        DeleteEntity(ped)
    end, Config.Package.item)
end

function EndDrugRun()
    TriggerEvent('QBCore:Notify', "All locations completed! Return to the DrugDealer to end the run.", "success")
    SetNewWaypoint(Config.PedLocation.x, Config.PedLocation.y)
    TriggerServerEvent('vivify_drugRun:server:giveReward')
end

function TableContains(tbl, value)
    for _, v in ipairs(tbl) do
        if v == value then return true end
    end
    return false
end


function SpawnDrugDealer()
    if isPedSpawned then return end

    RequestModel(Config.PedModel)
    while not HasModelLoaded(Config.PedModel) do
        Wait(10)
    end

    pedHandle = CreatePed(0, Config.PedModel, Config.PedLocation.x, Config.PedLocation.y, Config.PedLocation.z - 1.0, Config.PedLocation.w, false, true)
    SetEntityInvincible(pedHandle, true)
    SetBlockingOfNonTemporaryEvents(pedHandle, true)
    FreezeEntityPosition(pedHandle, true)

    isPedSpawned = true
end

function SetupQbTarget()
    exports['qb-target']:AddTargetEntity(pedHandle, {
        options = {
            {
                label = Config.TargetLabel,
                icon = "fas fa-comment",
                action = function()
                    if isCooldownActive then
                        QBCore.Functions.Notify("The dealer is not ready yet. Please wait.", "error")
                    else
                        CheckPlayerRole()
                    end
                end
            },
            {
                label = "End Run",
                icon = "fas fa-comment",
                action = function()
                    if not isRunActive then
                        QBCore.Functions.Notify("There is no run currently going on.", "error")
                    else
                        TriggerEvent('vivify_drugRun:client:removeVehicle')
                    end
                end
            }
        },
        distance = 2.5
    })
end

RegisterNetEvent('vivify_drugRun:client:startRun', function()
    TriggerEvent('vivify_drugRun:client:spawnVehicle')
end)

function CheckPlayerRole()
    QBCore.Functions.GetPlayerData(function(playerData)
        if playerData.job.name == "police" then
            QBCore.Functions.Notify("This person has nothing to say to you.", "error")
        else
            TriggerServerEvent('vivify_drugRun:server:startRunCheck')
        end
    end)
end


local function generateRandomPlate()
    local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    local plate = "RUN"
    for i = 1, 5 do
        local rand = math.random(1, #chars)
        plate = plate .. chars:sub(rand, rand)
    end
    return plate
end

RegisterNetEvent("vivify_drugRun:client:spawnVehicle", function(drugType)
    local spawnCoords = Config.VehicleSpawnLocation

    QBCore.Functions.SpawnVehicle(Config.VehicleModel, function(vehicle)
        local randomPlate = generateRandomPlate()
        SetVehicleNumberPlateText(vehicle, randomPlate)
        SetEntityHeading(vehicle, spawnCoords.w)
        SetEntityCoords(vehicle, spawnCoords.x, spawnCoords.y, spawnCoords.z, false, false, false, true)

        spawnedVehicle = vehicle

        TriggerServerEvent("vivify_drugRun:server:storeTrunkItems", randomPlate)
        QBCore.Functions.Notify("Your vehicle is ready!", "success")
        TriggerEvent('vehiclekeys:client:SetOwner', QBCore.Functions.GetPlate(vehicle))
        StartCooldown()
        StartDrugRun()
    end, spawnCoords, true)
end)


RegisterNetEvent('vivify_drugRun:client:removeVehicle', function()
    if spawnedVehicle and DoesEntityExist(spawnedVehicle) then
        DeleteVehicle(spawnedVehicle)
        QBCore.Functions.Notify('Vehicle removed!', 'success')
        TriggerServerEvent('vivify_drugRun:server:endRun')
        spawnedVehicle = nil
        isRunActive = false
        isCooldownActive = false
    else
        QBCore.Functions.Notify('No vehicle found to remove!', 'error')
    end
end)


function StartCooldown()
    isCooldownActive = true
    QBCore.Functions.Notify("The dealer is now on cooldown.", "info")
    SetTimeout(Config.GlobalCooldown * 1000, function()
        isCooldownActive = false
        QBCore.Functions.Notify("The dealer is ready again.", "success")
    end)
end

CreateThread(function()
    SpawnDrugDealer()
    SetupQbTarget()
end)