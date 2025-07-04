if not lib.checkDependency('ox_lib', '3.30.0', true) then return end

local QBCore = exports['qb-core']:GetCoreObject()
local availableJobs = Config.AvailableJobs

-- Exports

local function AddCityJob(jobName, toCH)
    if availableJobs[jobName] then return false, 'already added' end
    availableJobs[jobName] = {
        ['label'] = toCH.label,
        ['isManaged'] = toCH.isManaged
    }
    return true, 'success'
end

exports('AddCityJob', AddCityJob)

-- Functions

local function giveStarterItems()
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end
    for _, v in pairs(QBCore.Shared.StarterItems) do
        local info = {}
        if v.item == 'id_card' then
            info.citizenid = Player.PlayerData.citizenid
            info.firstname = Player.PlayerData.charinfo.firstname
            info.lastname = Player.PlayerData.charinfo.lastname
            info.birthdate = Player.PlayerData.charinfo.birthdate
            info.gender = Player.PlayerData.charinfo.gender
            info.nationality = Player.PlayerData.charinfo.nationality
        elseif v.item == 'driver_license' then
            info.firstname = Player.PlayerData.charinfo.firstname
            info.lastname = Player.PlayerData.charinfo.lastname
            info.birthdate = Player.PlayerData.charinfo.birthdate
            info.type = 'Class C Driver License'
        end
        exports['qb-inventory']:AddItem(source, v.item, 1, false, info, 'qb-cityhall:giveStarterItems')
    end
end

-- BL ID Card Support: (https://github.com/Byte-Labs-Studio/bl_idcard)
-- local function giveStarterItems()
--     local Player = QBCore.Functions.GetPlayer(source)
--     if not Player then return end
--     for _, v in pairs(QBCore.Shared.StarterItems) do
--         if v.item == "id_card" or v.item == "driver_license" then
--             exports.bl_idcard:createLicense(source, v.item)
--         else
--             Player.Functions.AddItem(v.item, v.amount)
--         end
--     end
-- end

-- Callbacks

lib.callback.register('qb-cityhall:server:receiveJobs', function()
    return availableJobs
end)

lib.callback.register('qb-cityhall:server:getIdentityData', function(source, hallId)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return {} end

    local licensesMeta = Player.PlayerData.metadata['licences']
    local availableLicenses = {}

    for license, data in pairs(Config.Cityhalls[hallId].licenses) do
        if not data.metadata or licensesMeta[data.metadata] then
            availableLicenses[license] = data
        end
    end

    return availableLicenses
end)

-- Events

RegisterNetEvent('qb-cityhall:server:requestId', function(item, hall)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local itemInfo = Config.Cityhalls[hall].licenses[item]
    if not Player.Functions.RemoveMoney('cash', itemInfo.cost, 'cityhall id') then return TriggerClientEvent('ox_lib:notify', src, { description = ('You don\'t have enough money on you, you need %s cash'):format(itemInfo.cost), position = 'center-right', type = 'error'}) end
    local info = {}
    if item == 'id_card' then
        info.citizenid = Player.PlayerData.citizenid
        info.firstname = Player.PlayerData.charinfo.firstname
        info.lastname = Player.PlayerData.charinfo.lastname
        info.birthdate = Player.PlayerData.charinfo.birthdate
        info.gender = Player.PlayerData.charinfo.gender
        info.nationality = Player.PlayerData.charinfo.nationality
    elseif item == 'driver_license' then
        info.firstname = Player.PlayerData.charinfo.firstname
        info.lastname = Player.PlayerData.charinfo.lastname
        info.birthdate = Player.PlayerData.charinfo.birthdate
        info.type = 'Class C Driver License'
    elseif item == 'weaponlicense' then
        info.firstname = Player.PlayerData.charinfo.firstname
        info.lastname = Player.PlayerData.charinfo.lastname
        info.birthdate = Player.PlayerData.charinfo.birthdate
    else
        return false
    end
    if not exports['qb-inventory']:AddItem(source, item, 1, false, info, 'qb-cityhall:server:requestId') then return end
    TriggerClientEvent('qb-inventory:client:ItemBox', src, QBCore.Shared.Items[item], 'add')
end)

-- BL ID Card Support: (https://github.com/Byte-Labs-Studio/bl_idcard)
-- RegisterNetEvent('qb-cityhall:server:requestId', function(item, hall)
--     local src = source
--     local Player = QBCore.Functions.GetPlayer(src)
--     if not Player then return end
--     local itemInfo = Config.Cityhalls[hall].licenses[item]
--     if not Player.Functions.RemoveMoney('cash', itemInfo.cost, 'cityhall id') then return TriggerClientEvent('QBCore:Notify', src, ('You don\'t have enough money on you, you need %s cash'):format(itemInfo.cost), 'error') end
--     exports.bl_idcard:createLicense(src, item)
-- end)

RegisterNetEvent('qb-cityhall:server:sendDriverTest', function(instructors)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    for i = 1, #instructors do
        local citizenid = instructors[i]
        local SchoolPlayer = QBCore.Functions.GetPlayerByCitizenId(citizenid)
        if SchoolPlayer then
            TriggerClientEvent('qb-cityhall:client:sendDriverEmail', SchoolPlayer.PlayerData.source, Player.PlayerData.charinfo)
        else
            local mailData = {
                sender = 'Township',
                subject = 'Driving lessons request',
                message = 'Hello,<br><br>We have just received a message that someone wants to take driving lessons.<br>If you are willing to teach, please contact them:<br>Name: <strong>' .. Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname .. '<br />Phone Number: <strong>' .. Player.PlayerData.charinfo.phone .. '</strong><br><br>Kind regards,<br>Township Los Santos',
                button = {}
            }
            exports['qb-phone']:sendNewMailToOffline(citizenid, mailData)
        end
    end
    if Config.Notify == 'qb' then
        TriggerClientEvent('QBCore:Notify', src, 'An email has been sent to driving schools, and you will be contacted automatically', 'success', 5000)
    elseif Config.Notify == 'ox' then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Email Sent',
            description = 'An email has been sent to driving schools, and you will be contacted automatically!',
            duration = 5000,
            position = 'center-right',
            type = 'success'
        })
    end
end)

RegisterNetEvent('qb-cityhall:server:ApplyJob', function(job, cityhallCoords)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local ped = GetPlayerPed(src)
    local pedCoords = GetEntityCoords(ped)

    local data = {
        ['src'] = src,
        ['job'] = job
    }
    if #(pedCoords - cityhallCoords) >= 20.0 or not availableJobs[job] then
        return false
    end
    local JobInfo = QBCore.Shared.Jobs[job]
    Player.Functions.SetJob(data.job)
    if Config.Notify == 'qb' then
        TriggerClientEvent('QBCore:Notify', data.src, Lang:t('info.new_job', { job = JobInfo.label }))
    elseif Config.Notify == 'ox' then
        TriggerClientEvent('ox_lib:notify', data.src, {
            title = 'New Job',
            description = Lang:t('info.new_job', { job = JobInfo.label }),
            duration = 5000,
            position = 'center-right',
            type = 'success'
        })
    end
end)

RegisterNetEvent('qb-cityhall:server:getIDs', giveStarterItems)

RegisterNetEvent('QBCore:Client:UpdateObject', function()
    QBCore = exports['qb-core']:GetCoreObject()
end)

-- Commands

QBCore.Commands.Add('drivinglicense', 'Give a drivers license to someone', { { 'id', 'ID of a person' } }, true, function(source, args)
    local Player = QBCore.Functions.GetPlayer(source)
    local SearchedPlayer = QBCore.Functions.GetPlayer(tonumber(args[1]))
    if SearchedPlayer then
        if not SearchedPlayer.PlayerData.metadata['licences']['driver'] then
            for i = 1, #Config.DrivingSchools do
                for id = 1, #Config.DrivingSchools[i].instructors do
                    if Config.DrivingSchools[i].instructors[id] == Player.PlayerData.citizenid then
                        SearchedPlayer.PlayerData.metadata['licences']['driver'] = true
                        SearchedPlayer.Functions.SetMetaData('licences', SearchedPlayer.PlayerData.metadata['licences'])
                            if Config.Notify == 'qb' then
                                TriggerClientEvent('QBCore:Notify', SearchedPlayer.PlayerData.source, 'You have passed! Pick up your drivers license at the town hall', 'success', 5000)
                                TriggerClientEvent('QBCore:Notify', source, ('Player with ID %s has been granted access to a driving license'):format(SearchedPlayer.PlayerData.source), 'success', 5000)
                            elseif Config.Notify == 'ox' then
                                TriggerClientEvent('ox_lib:notify', SearchedPlayer.PlayerData.source, {
                                    title = 'Test Passed',
                                    description = 'You have passed! Pick up your drivers license at the town hall',
                                    duration = 5000,
                                    position = 'center-right',
                                    type = 'success'
                                })
                                TriggerClientEvent('ox_lib:notify', source, {
                                    title = 'Driving License Granted',
                                    description = ('Player with ID %s has been granted access to a driving license'):format(SearchedPlayer.PlayerData.source),
                                    duration = 5000,
                                    position = 'center-right',
                                    type = 'success'
                                })
                            end
                        break
                    end
                end
            end
        else
                if Config.Notify == 'qb' then
                    TriggerClientEvent('QBCore:Notify', source,
                        "Can't give permission for a drivers license, this person already has permission", 'error')
                elseif Config.Notify == 'ox' then
                    TriggerClientEvent('ox_lib:notify', source, {
                        title = 'Permission Error',
                        description = "Can't give permission for a drivers license, this person already has permission",
                        duration = 5000,
                        position = 'center-right',
                        type = 'error'
                    })
                end
        end
    else
            if Config.Notify == 'qb' then
                TriggerClientEvent('QBCore:Notify', source, 'Player Not Online', 'error')
            elseif Config.Notify == 'ox' then
                TriggerClientEvent('ox_lib:notify', source, {
                    title = 'Player Not Online',
                    duration = 5000,
                    position = 'center-right',
                    type = 'error'
                })
            end
    end
end)