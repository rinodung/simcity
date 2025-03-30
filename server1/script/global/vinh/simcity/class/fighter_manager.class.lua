Include("\\script\\misc\\eventsys\\type\\player.lua")
Include("\\script\\misc\\eventsys\\type\\map.lua")
Include("\\script\\global\\vinh\\simcity\\config.lua")
Include("\\script\\global\\vinh\\simcity\\class\\fighter.class.lua")
IncludeLib("NPCINFO")
FighterManager = {
    fighterList = {},
    counter = 0,
    fighterByPlayer = {}
}

function FighterManager:Add(config)

    local worldInfo = SimCityWorld:Get(config.nMapId)

    -- All good generate name for Thanh Thi
    if config.mode == nil or config.mode == "thanhthi" or config.mode == "train" then
        if worldInfo.showName == 1 then
            if (not config.szName) or config.szName == "" then
                config.szName = SimCityNPCInfo:getName(config.nNpcId)
            end
        else
            config.szName = " "
        end
    end

    local id = NpcFighter:New(config)
    if id ~= nil then
        self.fighterList["n" .. id] = id

        if config.playerID and config.playerID ~= "" then
            if not self.fighterByPlayer[config.playerID] then
                self.fighterByPlayer[config.playerID] = {}
            end
            tinsert(self.fighterByPlayer[config.playerID], id)
        end
        return id
    else
        return 0
    end
end

function FighterManager:Get(nListId)
    return NpcFighter:getTbNpc(nListId)
end

function FighterManager:Remove(nListId)
    NpcFighter:Remove(nListId)
    self.fighterList["n" .. nListId] = nil
end

function FighterManager:ClearMap(nW, targetListId)
    -- Get info for npc in this world
    for key, id in self.fighterList do
        local fighter = self:Get(id)
        if fighter.nMapId == nW and fighter.role ~= "vantieu" and fighter.role ~= "keoxe" then
            if (not targetListId) or (targetListId == fighter.id) then
                self:Remove(fighter.id)
            end
        end
    end
end

function _sortByScore(tb1, tb2)
    return tb1[2] > tb2[2]
end

function FighterManager:ThongBaoBXH(nW)
    -- Collect all data
    local allPlayers = {}
    for i, id in self.fighterList do
        local fighter = self:Get(id)
        if fighter.nMapId == nW then
            tinsert(allPlayers, { i, fighter.fightingScore, "npc" })
        end
    end

    if (SimCityTongKim.playerInTK and SimCityTongKim.playerInTK[nW]) then
        for pId, data in SimCityTongKim.playerInTK[nW] do
            tinsert(allPlayers, { pId, data.score, "player" })
        end
    end

    if getn(allPlayers) > 1 then
        local maxIndex = getn(allPlayers)
        if maxIndex > 10 then
            maxIndex = 10
        end

        sort(allPlayers, _sortByScore)

        Msg2Map(nW, "<color=yellow>========= B¶NG XÕP H¹NG =========<color>")
        Msg2Map(nW, "<color=yellow>=================================<color>")

        for j = 1, maxIndex do
            local info = allPlayers[j]

            if info[3] == "npc" then
                local fighter = self:Get(self.fighterList[info[1]])
                if fighter then
                    local phe = ""

                    if (fighter.tongkim == 1) then
                        if (fighter.tongkim_name) then
                            phe = fighter.tongkim_name
                        else
                            phe = "Kim"
                            if fighter.camp == 1 then
                                phe = "Tèng"
                            end
                        end
                    end

                    if phe == "Kim" then
                        phe = "K"
                    else
                        phe = "T"
                    end

                    local msg = "<color=white>" .. j .. " <color=yellow>[" .. phe .. "] " ..
                        SimCityTongKim.RANKS[fighter.rank] .. " <color>" ..
                        (fighter.hardsetName or SimCityNPCInfo:getName(fighter.nNpcId)) .. "<color=white> (" ..
                        allPlayers[j][2] .. ")<color>"
                    Msg2Map(nW, msg)
                end
            else
                local tbPlayer = SimCityTongKim.playerInTK[nW][info[1]]
                local msg = "<color=white>" .. j .. " <color=red>[" .. (tbPlayer.phe) .. "] " .. (tbPlayer.rank) ..
                    " <color>" .. (tbPlayer.name) .. "<color=white> (" .. (tbPlayer.score) .. ")<color>"
                Msg2Map(nW, msg)
            end
        end
        Msg2Map(nW, "<color=yellow>=================================<color>")
    end
end 