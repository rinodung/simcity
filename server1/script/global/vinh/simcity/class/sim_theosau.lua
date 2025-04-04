Include("\\script\\global\\vinh\\simcity\\config.lua")

IncludeLib("NPCINFO")
SimTheoSau = {

    fighterList = {},
    counter = 1,
    removedIds = {}
}

function SimTheoSau:New(fighter)

    -- Setup minimum config
    self:initCharConfig(fighter)

    local nListId
    if getn(self.removedIds) > 0 then
        nListId = tremove(self.removedIds)
    else
        nListId = self.counter
        self.counter = self.counter + 1
    end

    local tbNpc = {
        id = nListId     
    }
 
    for k, v in fighter do
        tbNpc[k] = v
    end


    self.fighterList[nListId] = tbNpc

    -- Setup walk paths
    if self:HardResetPos(nListId) == 0 then
        return nil
    end

    -- Bugfix series
    tbNpc.series = tbNpc.series or random(0,4)

    -- Create the character on screen
    self:Show(nListId, 1, tbNpc.goX, tbNpc.goY)

 
    return nListId
end

function SimTheoSau:Get(nListId)
    return self.fighterList[nListId]
end

function SimTheoSau:Remove(nListId)
    local tbNpc = self.fighterList[nListId]
    if tbNpc then
        DelNpcSafe(tbNpc.finalIndex)
        self.fighterList[nListId] = nil
        tinsert(self.removedIds, nListId)
    end
end

function SimTheoSau:Show(nListId, isNew, goX, goY)
    local tbNpc = self.fighterList[nListId]
    
    local nMapIndex = SubWorldID2Idx(tbNpc.nMapId)

    if nMapIndex >= 0 then
        local nNpcIndex

        local tX, tY
        local pW, pX, pY = CallPlayerFunction(self:GetPlayer(nListId), GetWorldPos)
        tX = pX
        tY = pY

        if goX and goY and goX > 0 and goY > 0 then
            tX = goX
            tY = goY
        end

        local name = tbNpc.szName or SimCityNPCInfo:getName(tbNpc.nNpcId)

        if (tbNpc.tongkim == 1) then
            if (tbNpc.tongkim_name) then
                name = tbNpc.tongkim_name
            else
                name = "Kim"
                if tbNpc.camp == 1 then
                    name = "Tèng"
                end
            end
            name = name .. " " .. SimCityTongKim.RANKS[tbNpc.rank]
        end

        if (tbNpc.hardsetName) then
            name = tbNpc.hardsetName
        end

        nNpcIndex = AddNpcEx(tbNpc.nNpcId, tbNpc.level, tbNpc.series, nMapIndex, tX * 32, tY * 32, 1, name, 0)

        if nNpcIndex > 0 then
            local kind = GetNpcKind(nNpcIndex)
            if kind ~= 0 then
                DelNpcSafe(nNpcIndex)
            else
                tbNpc.szName = GetNpcName(nNpcIndex)
                tbNpc.finalIndex = nNpcIndex
                tbNpc.isDead = 0
                tbNpc.lastPos = {
                    nX32 = tX * 32,
                    nY32 = tY * 32
                }

                -- Otherwise choose side
                SetNpcCurCamp(nNpcIndex, tbNpc.camp)                
                SetNpcActiveRegion(nNpcIndex, 1)
                SetNpcParam(nNpcIndex, PARAM_LIST_ID, tbNpc.id)
                SetNpcScript(nNpcIndex, "\\script\\global\\vinh\\simcity\\class\\sim_theosau.timer.lua")
                SetNpcTimer(nNpcIndex, REFRESH_RATE)

                -- Ngoai trang?
                if (tbNpc.ngoaitrang and tbNpc.ngoaitrang == 1) then
                    SimCityNgoaiTrang:makeup(tbNpc, nNpcIndex)
                end


                -- Disable fighting?
                if (tbNpc.isFighting == 0) then
                    -- TODO An hien
                    -- if (tbNpc.isAttackable == 1) then
                    --     SetNpcKind(nNpcIndex, 0)
                    -- else
                    --     SetNpcKind(nNpcIndex, tbNpc.kind or 4)
                    -- end
                    SetNpcKind(nNpcIndex, 0)
                    self:SetFightState(nListId, 0)
                end

                -- Set NPC MAX life
                if tbNpc.maxHP then
                    NPCINFO_SetNpcCurrentMaxLife(nNpcIndex, tbNpc.maxHP)
                end

                -- Life?
                if tbNpc.lastHP then
                    NPCINFO_SetNpcCurrentLife(nNpcIndex, tbNpc.lastHP)
                elseif tbNpc.maxHP then
                    NPCINFO_SetNpcCurrentLife(nNpcIndex, tbNpc.maxHP)
                end
                return tbNpc.id
            end
        end

        return 0
    end
    return 0
end

function SimTheoSau:Respawn(nListId, code, reason)
    local tbNpc = self.fighterList[nListId]
    -- code: 0: con nv con song 1: da chet toan bo 2: keo xe qua map khac 3: chuyen sang chien dau 4: bi lag dung 1 cho nay gio ko di duoc
    --print(tbNpc.role .. " " .. tbNpc.szName .. ": respawn " .. code .. " " .. reason)


    local isAllDead = code == 1 and 1 or 0

    local nX, nY, nMapIndex = GetNpcPos(tbNpc.finalIndex)

    -- Do calculation
    nX = nX / 32
    nY = nY / 32

    -- 3 = bi lag? tim cho khac hien len nao
    if code == 4 then
        nX = 0
        nY = 0
        self:HardResetPos(nListId)

        -- 2 = qua map khac?
    elseif code == 2 then
        nX = 0
        nY = 0
        self:HardResetPos(nListId)

        -- otherwise reset
    elseif isAllDead == 1 then
        nX = tbNpc.parentAppointPos[1]
        nY = tbNpc.parentAppointPos[2]    
    else
        tbNpc.lastPos = {
            nX32 = nX,
            nY32 = nY
        }
    end

    tbNpc.tick_checklag = nil
    tbNpc.lastHP = NPCINFO_GetNpcCurrentLife(tbNpc.finalIndex)
    if (isAllDead == 1) then
        tbNpc.lastHP = nil
    end


    -- Normal respawn ? Can del NPC
    DelNpcSafe(tbNpc.finalIndex)


    self:Show(nListId, 0, nX, nY)
end

function SimTheoSau:IsNpcEnemyAround(nListId)
    local tbNpc = self.fighterList[nListId]
    local allNpcs = {}
    local nCount = 0
    local radius = tbNpc.RADIUS_FIGHT_SCAN or RADIUS_FIGHT_SCAN
    -- Keo xe?
    allNpcs, nCount = CallPlayerFunction(self:GetPlayer(nListId), GetAroundNpcList, radius)
    for i = 1, nCount do
        local fighter2Kind = GetNpcKind(allNpcs[i])
        local fighter2Camp = GetNpcCurCamp(allNpcs[i])
        if fighter2Kind == 0 and (IsAttackableCamp(tbNpc.camp, fighter2Camp) == 1) then
            return 1
        end
    end
    return 0
end

function SimTheoSau:IsPlayerEnemyAround(nListId)
    local tbNpc = self.fighterList[nListId]
    -- FIGHT other player
    if GetNpcAroundPlayerList then
        local allNpcs, nCount = GetNpcAroundPlayerList(tbNpc.finalIndex, tbNpc.RADIUS_FIGHT_PLAYER or RADIUS_FIGHT_PLAYER)
        for i = 1, nCount do
            if (CallPlayerFunction(allNpcs[i], GetFightState) == 1 and
                    IsAttackableCamp(CallPlayerFunction(allNpcs[i], GetCurCamp), tbNpc.camp) == 1 and
                    tbNpc.camp ~= 0) then
                return 1
            end
        end
    end
    return 0
end

function SimTheoSau:JoinFight(nListId, reason)
    local tbNpc = self.fighterList[nListId]
    tbNpc.isFighting = 1
    tbNpc.tick_canswitch = tbNpc.tick_breath +
        random(tbNpc.TIME_FIGHTING_minTs or TIME_FIGHTING.minTs,
            tbNpc.TIME_FIGHTING_maxTs or TIME_FIGHTING.maxTs) -- trong trang thai pk 1 toi 2ph

    reason = reason or "no reason"

    local currX, currY, currW = GetNpcPos(tbNpc.finalIndex)
    currX = floor(currX / 32)
    currY = floor(currY / 32)

    -- If already having last fight pos, we may simply chance AI to 1
    if tbNpc.lastFightPos then
        local lastPos = tbNpc.lastFightPos
        if lastPos.W == currW then
            if (GetDistanceRadius(lastPos.X, lastPos.Y, currX, currY) < DISTANCE_VISION) then
                self:SetFightState(nListId, 9)
                return 1
            end
        end
    end

    -- Otherwise save it and respawn
    tbNpc.lastFightPos = {
        X = currX,
        Y = currY,
        W = currW
    }

    self:Respawn(nListId, 3, "JoinFight " .. reason)
    return 1
end

function SimTheoSau:LeaveFight(nListId, isAllDead, reason)
    local tbNpc = self.fighterList[nListId]

    isAllDead = isAllDead or 0

    tbNpc.isFighting = 0
    tbNpc.tick_canswitch = tbNpc.tick_breath +
        random(tbNpc.TIME_RESTING_minTs or TIME_RESTING.minTs,
            tbNpc.TIME_RESTING_maxTs or TIME_RESTING.maxTs) -- trong trang thai di bo 30s-1ph
    reason = reason or "no reason"

    -- Do not need to respawn just disable fighting
    if (isAllDead ~= 1 and (tbNpc.kind ~= 4 or tbNpc.isAttackable == 1)) then        
        self:SetFightState(nListId, 0)
    else
        self:Respawn(nListId, isAllDead, reason)
    end
end

function SimTheoSau:CanLeaveFight(nListId)
    local tbNpc = self.fighterList[nListId]
    if tbNpc.isDead == 1 then
        return 0
    end

    -- No attacker around including NPC and Player ? Stop
    if (self:IsNpcEnemyAround(nListId) == 0 and
            self:IsPlayerEnemyAround(nListId) == 0) then
        if (tbNpc.leaveFightWhenNoEnemy and tbNpc.leaveFightWhenNoEnemy > 0) then
            local realCanSwitchTick = tbNpc.tick_breath + tbNpc.leaveFightWhenNoEnemy - 1

            if tbNpc.tick_canswitch > realCanSwitchTick then
                tbNpc.tick_canswitch = realCanSwitchTick
            end
        end

        return 1
    end
    return 0
end

function SimTheoSau:SetFightState(nListId, mode)
    local tbNpc = self.fighterList[nListId]
    SetNpcAI(tbNpc.finalIndex, mode)
end

function SimTheoSau:TriggerFightWithNPC(nListId)
    if (self:IsNpcEnemyAround(nListId) == 1) then
        return self:JoinFight(nListId, "enemy around")
    end
    return 0
end

function SimTheoSau:TriggerFightWithPlayer(nListId)
    local tbNpc = self.fighterList[nListId]
    -- FIGHT other player
    if GetNpcAroundPlayerList then
        if self:IsPlayerEnemyAround(nListId) == 1 then
            return self:JoinFight(nListId, "player around")
        end
    end

    return 0
end

function SimTheoSau:HardResetPos(nListId)
    local tbNpc = self.fighterList[nListId]
    local nW = tbNpc.nMapId
    local pW, pX, pY = CallPlayerFunction(self:GetPlayer(nListId), GetWorldPos)
        local targetPos = randomRange({pX, pY }, tbNpc.walkVar or 2)
        tbNpc.parentAppointPos[1] = targetPos[1]
        tbNpc.parentAppointPos[2] = targetPos[2]
    return 1
end

function SimTheoSau:Breath(nListId)
    local tbNpc = self.fighterList[nListId]
    local nX32, nY32, nW32 = GetNpcPos(tbNpc.finalIndex)
    local nW = SubWorldIdx2ID(nW32)

    local pW = 0
    local pX = 0
    local pY = 0

    local myPosX = floor(nX32 / 32)
    local myPosY = floor(nY32 / 32)

    local cachNguoiChoi = 0 

    local pID = self:GetPlayer(nListId)
    if pID > 0 then
        pW, pX, pY = CallPlayerFunction(pID, GetWorldPos)
        cachNguoiChoi = GetDistanceRadius(myPosX, myPosY, pX, pY)
    end

    -- Otherwise just Random chat    
    if tbNpc.isFighting == 1 then
        if random(1, 100) <= CHANCE_CHAT then
            NpcChat(tbNpc.finalIndex, allSimcityChat.fighting[random(1, getn(allSimcityChat.fighting))])
        end
    else
        if random(1, 100) <= CHANCE_CHAT then
            NpcChat(tbNpc.finalIndex, allSimcityChat.general[random(1, getn(allSimcityChat.general))])
        end
    end

    -- Is fighting? Do nothing except leave fight if possible
    if tbNpc.isFighting == 1 then
        -- Case 1: toi gio chuyen doi
        if tbNpc.tick_canswitch < tbNpc.tick_breath then
            return self:LeaveFight(nListId, 0, "toi gio thay doi trang thai")
        end

        -- Case 2: tu dong thoat danh khi khong con ai
        if self:CanLeaveFight(nListId) == 1 then
            -- self:LeaveFight(nListId, 0, "khong tim thay quai")
            return 1
        end

        -- Case 3: qua xa nguoi choi phai chay theo ngay
        if (cachNguoiChoi > DISTANCE_FOLLOW_PLAYER) then
            tbNpc.tick_canswitch = tbNpc.tick_breath - 1
            self:LeaveFight(nListId, 0, "chay theo nguoi choi")
        else
            return 1
        end
    end


    -- Binh thuong
    if (cachNguoiChoi <= DISTANCE_SUPPORT_PLAYER) then
        
        -- Case 1: someone around is fighting, we join
        if (tbNpc.CHANCE_ATTACK_NPC and random(0, tbNpc.CHANCE_ATTACK_NPC) <= 2) then
            if self:TriggerFightWithNPC(nListId) == 1 then
                return 1
            end
        end

        -- Case 2: some player around is fighting and different camp, we join
        local myLife = NPCINFO_GetNpcCurrentLife(tbNpc.finalIndex)
        local maxLife = NPCINFO_GetNpcCurrentMaxLife(tbNpc.finalIndex)

        if ((tbNpc.CHANCE_ATTACK_PLAYER and random(0, tbNpc.CHANCE_ATTACK_PLAYER) <= 2) or (myLife < maxLife))
        then
            if self:TriggerFightWithPlayer(nListId) == 1 then
                return 1
            end
        end
    end

    -- Mode 3: follow parent player
    -- Player has gone different map? Do respawn
    local needRespawn = 0
    if tbNpc.nMapId ~= pW then
        needRespawn = 1
    else
        if cachNguoiChoi > DISTANCE_FOLLOW_PLAYER_TOOFAR then
            needRespawn = 1
        end
    end

    if needRespawn == 1 then
        tbNpc.nMapId = pW
        tbNpc.isFighting = 0
        tbNpc.tick_canswitch = tbNpc.tick_breath
        tbNpc.parentAppointPos[1] = pX
        tbNpc.parentAppointPos[2] = pY
        self:Respawn(nListId, 2, "qua xa nguoi choi")
        return 1
    end


    -- Otherwise walk toward parent
    NpcWalk(tbNpc.finalIndex, pX + random(-2, 2), pY + random(-2, 2)) 
    return 1
end

function SimTheoSau:OnTimer(nListId)
    local tbNpc = self.fighterList[nListId]
    if tbNpc == nil then
        return 0
    end
    tbNpc.tick_breath = tbNpc.tick_breath + REFRESH_RATE / 18
    if tbNpc.isFighting == 1 then
        tbNpc.fightingScore = tbNpc.fightingScore + 10
    end

    if tbNpc.isDead == 1 then
        return 0
    end

    self:Breath(nListId)

    return 1
end

function SimTheoSau:OnDeath(nListId, nNpcIndex)
    local tbNpc = self.fighterList[nListId]
    if tbNpc == nil then
        return 0
    end

    if tbNpc.tongkim == 1 then
        self:AddScoreToAroundNPC(nListId, nNpcIndex, tbNpc.rank or 1)
        SimCityTongKim:OnDeath(nNpcIndex, tbNpc.rank or 1)
    end
 
    tbNpc.isDead = 1
    tbNpc.finalIndex = nil
 

    local doRespawn = 0

    if tbNpc.isFighting == 1 and tbNpc.tick_breath > tbNpc.tick_canswitch then
        doRespawn = 1
    end


    -- Is every one dead?
    if (doRespawn == 1 or tbNpc.isDead == 1) then
        tbNpc.fightingScore = ceil(tbNpc.fightingScore * 0.7)
        SimCityTongKim:updateRank(tbNpc)


        -- No revive? Do removal
        if tbNpc.noRevive == 1 then 
            return 1
        end
        -- Do revive? Reset and leave fight
        self:LeaveFight(nListId, 1, "die toan bo")
    end
end

-- For keo xe
function SimTheoSau:GetPlayer(nListId)
    local tbNpc = self.fighterList[nListId]
    if tbNpc.playerID == "" then
        return 0
    end
    return SearchPlayer(tbNpc.playerID)
end

function SimTheoSau:AddScoreToAroundNPC(nListId, nNpcIndex, currRank)
    local fighter = self.fighterList[nListId]
    local allNpcs, nCount = GetNpcAroundNpcList(nNpcIndex, 15)
    local foundfighters = {}
    if nCount > 0 then
        for i = 1, nCount do
            local fighter2Kind = GetNpcKind(allNpcs[i])
            local fighter2Camp = GetNpcCurCamp(allNpcs[i])
            if (fighter2Kind == 0) then
                if (fighter2Camp ~= fighter.camp) then
                    local nListId2 = GetNpcParam(allNpcs[i], PARAM_LIST_ID) or 0
                    if (nListId2 > 0) then
                        tinsert(foundfighters, nListId2)
                    end
                end
            end
        end

        local N = getn(foundfighters)
        if N > 0 then
            local scoreTotal = currRank * 1000
            for key, fighter2 in self.fighterList do
                if fighter2 and fighter2.id ~= fighter.id and fighter2.isFighting == 1 then
                    fighter2.fightingScore = ceil(
                        fighter2.fightingScore + (scoreTotal / N) + (scoreTotal / N) * fighter2.rank / 10)
                    SimCityTongKim:updateRank(fighter2)
                end
            end
        end
    end

    return 0
end

function SimTheoSau:initCharConfig(config)
    config.playerID = config.playerID or "" -- dang theo sau ai do


    -- Init stats
    config.isFighting = 0
    config.tick_breath = 0
    config.tick_canswitch = 0
    config.camp = config.camp or random(1, 3)
    config.noRevive = config.noRevive or 0
    config.fightingScore = 0
    config.rank = 1
    config.ngoaitrang = config.ngoaitrang or 0
    config.capHP = config.capHP or 1
    config.level = config.level or 95
    config.isAttackable = config.isAttackable or 0
    if config.capHP and config.capHP ~= "auto" then
        config.maxHP = SimCityNPCInfo:getHPByCap(config.capHP)
    end
    config.parentAppointPos = {0, 0}
end