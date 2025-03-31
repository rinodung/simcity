Include("\\script\\global\\vinh\\simcity\\config.lua")
IncludeLib("NPCINFO")
SimCitizen = {

    fighterList = {},
    counter = 1,
    removedIds = {}
}

function SimCitizen:getTbNpc(nListId)
    return self.fighterList[nListId]
end

function SimCitizen:New(fighter)

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
        id = nListId,
        children = nil,
        worldInfo = SimCityWorld:Get(fighter.nMapId),
        last2VisitedEdges = {} -- Track last visited edges for more natural movement
    }

    -- Check if worldInfo is nil
    if (tbNpc.worldInfo == nil) then
        return nil
    end


    for k, v in fighter do
        tbNpc[k] = v
    end

    -- Check if walkGraph is nil
    if (tbNpc.role == "citizen" and tbNpc.worldInfo.walkGraph == nil) then
        return nil
    end



    -- All good generate name for Thanh Thi
    if tbNpc.mode == nil or tbNpc.mode == "thanhthi" or tbNpc.mode == "train" then
        if tbNpc.worldInfo.showName == 1 then
            if (not tbNpc.szName) or tbNpc.szName == "" then
                tbNpc.szName = SimCityNPCInfo:getName(tbNpc.nNpcId)
            end
        else
            tbNpc.szName = " "
        end
    end

    self.fighterList[nListId] = tbNpc
    tbNpc.nPosId = self:GetRandomWalkPoint(nListId)

    -- Setup walk paths
    if self:HardResetPos(nListId) == 0 then
        return nil
    end

    -- Bugfix series
    tbNpc.series = random(0,4)

    -- Create the character on screen
    self:Show(nListId, 1, tbNpc.goX, tbNpc.goY)


    -- What about childrenSetup?
    self:SetupChildren(nListId, fighter)
    return nListId
end

function SimCitizen:Remove(nListId)
    local tbNpc = self.fighterList[nListId]
    if tbNpc then
        DelNpcSafe(tbNpc.finalIndex)

        if tbNpc.children then
            for i = 1, getn(tbNpc.children) do
                self:Remove(tbNpc.children[i])
            end
        end
        self.fighterList[nListId] = nil
        tinsert(self.removedIds, nListId)
    end
end

function SimCitizen:Show(nListId, isNew, goX, goY)
    local tbNpc = self.fighterList[nListId]
    
    local nMapIndex = SubWorldID2Idx(tbNpc.nMapId)

    if nMapIndex >= 0 then
        local nNpcIndex

        local tX, tY
        if tbNpc.role == "child" then
            local pW, pX, pY = self:GetParentPos(nListId)
            tX = pX
            tY = pY
        elseif tbNpc.role == "keoxe" then
            local pW, pX, pY = CallPlayerFunction(self:GetPlayer(nListId), GetWorldPos)
            tX = pX
            tY = pY
        elseif tbNpc.role == "citizen" then
            tX = tbNpc.worldInfo.walkGraph.nodes[tbNpc.nPosId][1]
            tY = tbNpc.worldInfo.walkGraph.nodes[tbNpc.nPosId][2]
        end

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
                    name = "TËng"
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

                local nPosCount = self:GetRandomWalkPoint(nListId)
                if nPosCount ~= nil then
                    SetNpcActiveRegion(nNpcIndex, 1)
                    SetNpcParam(nNpcIndex, PARAM_LIST_ID, tbNpc.id)
                    SetNpcScript(nNpcIndex, "\\script\\global\\vinh\\simcity\\class\\sim_citizen.timer.lua")
                    SetNpcTimer(nNpcIndex, REFRESH_RATE)
                end

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

function SimCitizen:Respawn(nListId, code, reason)
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
        tbNpc.nPosId = self:GetRandomWalkPoint(nListId)
        self:HardResetPos(nListId)

        -- 2 = qua map khac?
    elseif code == 2 then
        nX = 0
        nY = 0
        self:HardResetPos(nListId)

        -- otherwise reset
    elseif isAllDead == 1 and (tbNpc.role == "keoxe" or tbNpc.role == "child") then
        nX = tbNpc.parentAppointPos[1]
        nY = tbNpc.parentAppointPos[2]
    elseif (isAllDead == 1 and tbNpc.resetPosWhenRevive and tbNpc.resetPosWhenRevive >= 1) then
        local newPosId = self:GetRandomWalkPoint(nListId)
        nX = tbNpc.worldInfo.walkGraph.nodes[newPosId][1]
        nY = tbNpc.worldInfo.walkGraph.nodes[newPosId][2]
        tbNpc.nPosId = newPosId
    elseif (isAllDead == 1 and tbNpc.lastPos ~= nil) then
        nX = tbNpc.lastPos.nX32 / 32
        nY = tbNpc.lastPos.nY32 / 32
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

function SimCitizen:IsNpcEnemyAround(nListId)
    local tbNpc = self.fighterList[nListId]
    local allNpcs = {}
    local nCount = 0
    local radius = tbNpc.RADIUS_FIGHT_SCAN or RADIUS_FIGHT_SCAN
    -- Keo xe?
    if tbNpc.role == "keoxe" then
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

    -- Thanh thi / tong kim / chien loan
    allNpcs, nCount = GetNpcAroundNpcList(tbNpc.finalIndex, radius)
    for i = 1, nCount do
        local fighter2Kind = GetNpcKind(allNpcs[i])
        local fighter2Camp = GetNpcCurCamp(allNpcs[i])
        if fighter2Kind == 0 and (IsAttackableCamp(tbNpc.camp, fighter2Camp) == 1) then
            return 1
        end
    end

    return 0
end

function SimCitizen:IsDialogNpcAround(nListId)
    local tbNpc = self.fighterList[nListId]
    if tbNpc.mode ~= "thanhthi" then        
        return 0
    end

    local foundDialogNpc = tbNpc.worldInfo.walkGraph.foundDialogNpc
    if foundDialogNpc[tbNpc.nPosId] ~= nil then

        -- chance to drop 5 hoa
        if foundDialogNpc[tbNpc.nPosId] == 203 then
            if random(1, 10000) <= CHANCE_DROP_MONEY then
                for i=1, 10 do 
                    DropItem(SubWorldID2Idx(tbNpc.nMapId), tbNpc.worldInfo.walkGraph.nodes[tbNpc.nPosId][1]*32, tbNpc.worldInfo.walkGraph.nodes[tbNpc.nPosId][2]*32, -1, 1, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
                end
            end
        end

        -- chance to drop tdp
        if foundDialogNpc[tbNpc.nPosId] == 384 then
            if random(1, 10000) <= CHANCE_DROP_MONEY then
                for i=1, 3 do 
                    DropItem(SubWorldID2Idx(tbNpc.nMapId), tbNpc.worldInfo.walkGraph.nodes[tbNpc.nPosId][1]*32, tbNpc.worldInfo.walkGraph.nodes[tbNpc.nPosId][2]*32, -1, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
                end
            end
        end

        return 1
    end

    local allNpcs = {}
    local nCount = 0
    local radius = 8    
    allNpcs, nCount = GetNpcAroundNpcList(tbNpc.finalIndex, radius)
    for i = 1, nCount do
        local fighter2Kind = GetNpcKind(allNpcs[i])
        local fighter2Name = GetNpcName(allNpcs[i])
        local nNpcId = GetNpcSettingIdx(allNpcs[i])
        if fighter2Kind == 3 and (nNpcId == 108 or nNpcId == 198 or nNpcId == 203 or nNpcId == 384) then
            foundDialogNpc[tbNpc.nPosId] = nNpcId
            return 1
        end
    end
    return 0
end

function SimCitizen:IsPlayerEnemyAround(nListId)
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

function SimCitizen:JoinFight(nListId, reason)
    local tbNpc = self.fighterList[nListId]
    self:ChildrenJoinFight(nListId, reason)
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

function SimCitizen:LeaveFight(nListId, isAllDead, reason)
    local tbNpc = self.fighterList[nListId]
    self:ChildrenLeaveFight(nListId,isAllDead, reason)

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

function SimCitizen:CanLeaveFight(nListId)
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

function SimCitizen:SetFightState(nListId, mode)
    local tbNpc = self.fighterList[nListId]
    SetNpcAI(tbNpc.finalIndex, mode)
end

function SimCitizen:TriggerFightWithNPC(nListId)
    if (self:IsNpcEnemyAround(nListId) == 1) then
        return self:JoinFight(nListId, "enemy around")
    end
    return 0
end

function SimCitizen:TriggerFightWithPlayer(nListId)
    local tbNpc = self.fighterList[nListId]
    -- FIGHT other player
    if GetNpcAroundPlayerList then
        if self:IsPlayerEnemyAround(nListId) == 1 then
            if tbNpc.role == "citizen" then                
                if tbNpc.worldInfo.showFightingArea == 1 then
                    local name = GetNpcName(tbNpc.finalIndex)
                    local lastPos = tbNpc.worldInfo.walkGraph.nodes[tbNpc.nPosId]
                    if lastPos ~= nil then
                        Msg2Map(tbNpc.nMapId,
                            "<color=white>" .. name .. "<color> Æ∏nh ng≠Íi tπi " .. tbNpc.worldInfo.name .. " " ..
                            floor(lastPos[1] / 8) .. " " .. floor(lastPos[2] / 16) .. "")
                    end
                end
            end
            return self:JoinFight(nListId, "player around")
        end
    end

    return 0
end

function SimCitizen:HasArrived(nListId)
    local tbNpc = self.fighterList[nListId]
    local nX32, nY32 = GetNpcPos(tbNpc.finalIndex)
    local oX = nX32 / 32;
    local oY = nY32 / 32;

    local nX
    local nY
    local checkDistance = DISTANCE_CAN_CONTINUE

    if tbNpc.role == "child" then
        nX = tbNpc.parentAppointPos and tbNpc.parentAppointPos[1] or 0
        nY = tbNpc.parentAppointPos and tbNpc.parentAppointPos[2] or 0

        if not nX or not nY or nX == 0 or nY == 0 then
            return 0
        end
    else
        local posIndex = tbNpc.nPosId
        if posIndex ~= nil then
            nX = tbNpc.worldInfo.walkGraph.nodes[posIndex][1]
            nY = tbNpc.worldInfo.walkGraph.nodes[posIndex][2]
        else
            return 0
        end
    end

    local distance = GetDistanceRadius(nX, nY, oX, oY)

    if distance < checkDistance then
        return self:ChildrenArrived(nListId)
    end
    return 0
end


function SimCitizen:HardResetPos(nListId)
    local tbNpc = self.fighterList[nListId]
    local nW = tbNpc.nMapId

    -- Dang di theo sau npc khac
    if tbNpc.role == "child" or tbNpc.role == "keoxe" then
        local pW, pX, pY 
        if tbNpc.role == "child" then
            pW, pX, pY = self:GetParentPos(nListId)
        else
            pW, pX, pY = CallPlayerFunction(self:GetPlayer(nListId), GetWorldPos)
        end
        local targetPos = randomRange({pX, pY }, tbNpc.walkVar or 2)
        tbNpc.parentAppointPos[1] = targetPos[1]
        tbNpc.parentAppointPos[2] = targetPos[2]
        return 1
    end

    -- Startup position
    local walkPoint = self:GetRandomWalkPoint(nListId)
    if walkPoint == nil then
        return 0
    end
    
    tbNpc.nPosId = walkPoint
    
    return 1
end

function SimCitizen:Breath(nListId)
    local tbNpc = self.fighterList[nListId]
    local nX32, nY32, nW32 = GetNpcPos(tbNpc.finalIndex)
    local nW = SubWorldIdx2ID(nW32)

    local pW = 0
    local pX = 0
    local pY = 0

    local myPosX = floor(nX32 / 32)
    local myPosY = floor(nY32 / 32)

    local cachNguoiChoi = 0


    -- Initialize once
    if not tbNpc.lastKnownPos then
        tbNpc.lastKnownPos = {nX32 = 0, nY32 = 0, nW = 0}
    end
    -- Just update values
    tbNpc.lastKnownPos.nX32 = nX32
    tbNpc.lastKnownPos.nY32 = nY32
    tbNpc.lastKnownPos.nW = nW

    
    -- Di 1 minh
    if tbNpc.role == "citizen" then

        -- Random rot tien
        if random(1, 10000) <= CHANCE_DROP_MONEY then
            NpcDropMoney(tbNpc.finalIndex, random(1000, 10000), -1)
        end

        -- Otherwise just Random chat
        if tbNpc.worldInfo.allowChat == 1 then
            if tbNpc.isFighting == 1 then
                if random(1, 1000) <= CHANCE_CHAT then
                    NpcChat(tbNpc.finalIndex, allSimcityChat.fighting[random(1, getn(allSimcityChat.fighting))])
                end
            else
                if random(1, 1000) <= CHANCE_CHAT then
                    NpcChat(tbNpc.finalIndex, allSimcityChat.general[random(1, getn(allSimcityChat.general))])
                end
            end
        end

        -- Show my ID
        if (tbNpc.worldInfo.showingId == 1) then
            local dbMsg = tbNpc.debugMsg or ""
            NpcChat(tbNpc.finalIndex, tbNpc.id .. " " .. tbNpc.nNpcId)
        end
    elseif tbNpc.role == "child" then
        pW, pX, pY = self:GetParentPos(nListId)
        cachNguoiChoi = GetDistanceRadius(myPosX, myPosY, pX, pY)
        if self:IsParentFighting(nListId) == 1 and tbNpc.isFighting == 0 then
            return self:JoinFight(nListId, "parent dang danh nhau")
        end
    elseif tbNpc.role == "keoxe" then
        tbNpc.worldInfo.allowFighting = 1
        tbNpc.worldInfo.showFightingArea = 0

        local pID = self:GetPlayer(nListId)
        if pID > 0 then
            pW, pX, pY = CallPlayerFunction(pID, GetWorldPos)
            cachNguoiChoi = GetDistanceRadius(myPosX, myPosY, pX, pY)
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
        if (tbNpc.role == "keoxe" and cachNguoiChoi > DISTANCE_FOLLOW_PLAYER) then
            tbNpc.tick_canswitch = tbNpc.tick_breath - 1
            self:LeaveFight(nListId, 0, "chay theo nguoi choi")
        elseif (tbNpc.role == "child" and cachNguoiChoi > DISTANCE_FOLLOW_PLAYER) then
            --tbNpc.tick_canswitch = tbNpc.tick_breath - 1
            --self:LeaveFight(nListId, 0, "chay theo parent")
            return 1
        else
            return 1
        end
    end


    -- Binh thuong
    if ((tbNpc.role == "keoxe" and cachNguoiChoi <= DISTANCE_SUPPORT_PLAYER) or
            (tbNpc.role == "child" and cachNguoiChoi <= DISTANCE_SUPPORT_PLAYER) or
            tbNpc.role == "citizen") and tbNpc.worldInfo.allowFighting == 1 and
        (tbNpc.isFighting == 0 and tbNpc.tick_canswitch < tbNpc.tick_breath) then
        local isDialogNpcAround = self:IsDialogNpcAround(nListId)
        if (isDialogNpcAround == 0 and tbNpc.role == "citizen") or tbNpc.role == "keoxe" then
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

        -- Case 3: I auto switch to fight  mode
        if (isDialogNpcAround == 0 and tbNpc.role == "citizen" and tbNpc.attackNpcChance and random(1, tbNpc.attackNpcChance) <= 2) then
            -- CHo nhung dua chung quanh

            local countFighting = 0

            for key, fighter2 in self.fighterList do
                if fighter2.id ~= tbNpc.id and fighter2.nMapId == tbNpc.nMapId and
                    (fighter2.isFighting == 0 and IsAttackableCamp(fighter2.camp, tbNpc.camp) == 1) then
                    local otherPosX, otherPosY, otherPosW = GetNpcPos(fighter2.finalIndex)
                    otherPosX = floor(otherPosX / 32)
                    otherPosY = floor(otherPosY / 32)

                    local distance = floor(GetDistanceRadius(otherPosX, otherPosY, myPosX, myPosY))
                    local checkDistance = tbNpc.RADIUS_FIGHT_NPC or RADIUS_FIGHT_NPC
                    if distance < checkDistance then
                        countFighting = countFighting + 1
                        self:JoinFight(fighter2.id, "caused by others " ..
                            distance .. " (" .. otherPosX ..
                            " " .. otherPosY .. ") (" .. myPosX .. " " .. myPosY .. ")")
                    end
                end
            end

            -- If someone is around or I am not crazy then I fight
            if countFighting > 0 or tbNpc.attackNpcChance > 1 then
                countFighting = countFighting + 1
                self:JoinFight(nListId, "I start a fight")
            end

            if countFighting > 0 and tbNpc.worldInfo.showFightingArea == 1 then
                Msg2Map(nW,
                    "C„ " .. countFighting .. " nh©n s‹ Æang Æ∏nh nhau tπi " .. tbNpc.worldInfo.name ..
                    " <color=yellow>" .. floor(myPosX / 8) .. " " .. floor(myPosY / 16) .. "<color>")
            end

            if (countFighting > 0) then
                return 1
            end
        end
    end

    -- Khong phai dang keo xe
    if tbNpc.role == "citizen" then
        if tbNpc.tick_checklag and tbNpc.tick_breath > tbNpc.tick_checklag and self:IsDialogNpcAround(nListId) == 0 then
            self:Respawn(nListId, 4, "dang bi lag roi")
            return 1
        end

        -- Mode 1: randomwork
        if self:HasArrived(nListId) == 1 then
            -- Keep walking no stop
            local keepWalkingRate = 90
            if self:IsDialogNpcAround(nListId) == 1 then
                keepWalkingRate = 5
            end

            if (tbNpc.noStop == 1 or random(1, 100) < keepWalkingRate) then
                local nNextPosId = self:GetRandomWalkPoint(nListId, tbNpc.nPosId)
                tbNpc.nPosId = nNextPosId 
            else
                return 1
            end


            tbNpc.tick_checklag = nil
        else
            if not tbNpc.tick_checklag then
                tbNpc.tick_checklag = tbNpc.tick_breath +
                    20 -- check again in 20s, if still at same position, respawn because this is stuck
            end
        end

        local targetPos = tbNpc.worldInfo.walkGraph.nodes[tbNpc.nPosId]

        if targetPos == nil then
            return 0
        end

        local nX = targetPos[1]
        local nY = targetPos[2]

        if targetPos[3] == 1 then
            NpcWalk(tbNpc.finalIndex, nX, nY)
        else
            NpcWalk(tbNpc.finalIndex, nX+ random(-2, 2), nY+ random(-2, 2))            
        end
        self:CalculateChildrenPosition(nListId, nX, nY)
    elseif tbNpc.role == "child" then
        -- Mode 2: follow parent NPC
        -- Player has gone different map? Do respawn
        local needRespawn = 0
        pW, pX, pY = self:GetParentPos(nListId)

        -- Parent pos available?
        if pW > 0 and pX > 0 and pY > 0 then
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
        else
            return 1
        end


        -- Otherwise walk toward parent
        local targetW, targetX, targetY = self:GetMyPosFromParent(nListId)

        -- Parent gave info?
        if targetW > 0 and targetX > 0 and targetY > 0 then
            tbNpc.parentAppointPos[1] = targetX
            tbNpc.parentAppointPos[2] = targetY
            NpcWalk(tbNpc.finalIndex, targetX, targetY)
        end
    elseif tbNpc.role == "keoxe" then
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
    end
    return 1
end

function SimCitizen:OnTimer(nListId)
    local tbNpc = self.fighterList[nListId]
    if tbNpc == nil then
        return 0
    end
    if tbNpc.killTimer == 1 then
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

function SimCitizen:OnDeath(nListId, nNpcIndex)
    local tbNpc = self.fighterList[nListId]
    if tbNpc == nil then
        return 0
    end

    if tbNpc.tongkim == 1 then
        self:AddScoreToAroundNPC(nListId, nNpcIndex, tbNpc.rank or 1)
        SimCityTongKim:OnDeath(nNpcIndex, tbNpc.rank or 1)
    end

    if tbNpc.role == "citizen" then
        -- Random rot tien
        if random(1, 1000) <= CHANCE_DROP_MONEY then
            NpcDropMoney(tbNpc.finalIndex, random(1000, 100000), -1)
        end
    end

    if tbNpc.role == "citizen" and tbNpc.children then
        local child

        for i = 1, getn(tbNpc.children) do
            local each = self:getTbNpc(tbNpc.children[i])
            if each and each.isDead ~= 1 then
                child = each

                local tmp = {
                    finalIndex = tbNpc.finalIndex,
                    szName = tbNpc.szName,
                    nNpcId = tbNpc.nNpcId,
                    series = tbNpc.series,
                    lastHP = tbNpc.lastHP,
                    isFighting = tbNpc.isFighting,
                }

                tbNpc.finalIndex = child.finalIndex
                tbNpc.szName = child.szName
                tbNpc.nNpcId = child.nNpcId
                tbNpc.series = child.series
                tbNpc.lastHP = child.lastHP
                tbNpc.isFighting = child.isFighting


                child.finalIndex = tmp.finalIndex
                child.szName = tmp.szName
                child.series = tmp.series
                child.lastHP = tmp.lastHP
                child.isFighting = tmp.isFighting

                SetNpcParam(tbNpc.finalIndex, PARAM_LIST_ID, tbNpc.id)
                SetNpcParam(child.finalIndex, PARAM_LIST_ID, child.id)

                child.isDead = 1

                --print("Doi chu PT sang nv " .. tbNpc.szName)
                return 1
            end
        end
    end

    tbNpc.isDead = 1
    tbNpc.finalIndex = nil

    -- If child dead do nothing, let parent do it
    if tbNpc.role == "child" then
        return 1
    end

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
            if tbNpc.role == "citizen" then
                self:Remove(nListId)
            end
            return 1
        end
        -- Do revive? Reset and leave fight
        self:LeaveFight(nListId, 1, "die toan bo")
    end
end

function SimCitizen:KillTimer(nListId)
    local tbNpc = self.fighterList[nListId]
    tbNpc.killTimer = 1
end

-- For keo xe
function SimCitizen:GetPlayer(nListId)
    local tbNpc = self.fighterList[nListId]
    if tbNpc.playerID == "" then
        return 0
    end
    return SearchPlayer(tbNpc.playerID)
end

-- For parent
function SimCitizen:SetupChildren(nListId, parentConfig)
    local tbNpc = self.fighterList[nListId]
    if tbNpc.childrenSetup and getn(tbNpc.childrenSetup) > 0 then
        local createdChildren = {}

        local nX32, nY32, nW32 = GetNpcPos(tbNpc.finalIndex)
        local nW = SubWorldIdx2ID(nW32)
        local nX = nX32 / 32
        local nY = nY32 / 32

        -- Create children
        for i = 1, getn(tbNpc.childrenSetup) do
            local childConfig = objCopy(parentConfig)
            childConfig.parentID = tbNpc.id
            childConfig.childID = i
            childConfig.role = "child"
            childConfig.hardsetName = nil
            childConfig.childrenSetup = nil
            for k, v in tbNpc.childrenSetup[i] do
                childConfig[k] = v
            end
            childConfig.goX = nX
            childConfig.goY = nY
            local childId = self:New(childConfig)
            tinsert(createdChildren, childId)
        end

        tbNpc.children = createdChildren
    end
end

function SimCitizen:GiveChildPos(nListId, i)
    local tbNpc = self.fighterList[nListId]
    if tbNpc == nil then
        return 0, 0, 0
    end
    if tbNpc.childrenPath and getn(tbNpc.childrenPath) >= i then
        return tbNpc.nMapId, tbNpc.childrenPath[i][1], tbNpc.childrenPath[i][2]
    end
    return 0, 0, 0
end

function SimCitizen:CalculateChildrenPosition(nListId, X, Y)
    local tbNpc = self.fighterList[nListId]
    if not tbNpc.children then
        return 1
    end
    local size = getn(tbNpc.children)
    if size == 0 then
        return 1
    end

    if tbNpc.walkMode and tbNpc.walkMode == "formation" then
        local centerCharId = getCenteredCell(createFormation(size))
        local fighter = self:getTbNpc(tbNpc.children[centerCharId])

        if fighter and fighter.isDead == 1 then
            for i = 1, size do
                fighter = self:getTbNpc(tbNpc.children[i])
                if fighter and fighter.isDead ~= 1 then
                    break
                end
            end
        end

        if fighter and fighter.isDead ~= 1 then
            local nX, nY, nMapIndex = GetNpcPos(fighter.finalIndex)
            tbNpc.childrenPath = genCoords_squareshape({ nX / 32, nY / 32 }, { X, Y }, size)
        end
    else
        local childrenPath = {}
        for i = 1, size do
            tinsert(childrenPath, { X + random(-2, 2), Y + random(-2, 2) })
        end
        tbNpc.childrenPath = childrenPath
    end
end

function SimCitizen:ChildrenArrived(nListId)
    local tbNpc = self.fighterList[nListId]
    if not tbNpc.children then
        return 1
    end
    local size = getn(tbNpc.children)
    if size == 0 then
        return 1
    end

    for i = 1, size do
        local child = self:getTbNpc(tbNpc.children[i])
        if child and child.isDead ~= 1 and self:HasArrived(child.id) == 0 then
            return 0
        end
    end
    return 1
end

function SimCitizen:ChildrenJoinFight(nListId, code)
    local tbNpc = self.fighterList[nListId]
    if not tbNpc.children then
        return 1
    end
    local size = getn(tbNpc.children)
    if size == 0 then
        return 1
    end

    for i = 1, size do
        local child = self:getTbNpc(tbNpc.children[i])
        if child then
            self:JoinFight(child.id, code)
        end
    end
    return 1
end

function SimCitizen:ChildrenLeaveFight(nListId, code, reason)
    local tbNpc = self.fighterList[nListId]
    if not tbNpc.children then
        return 1
    end
    local size = getn(tbNpc.children)
    if size == 0 then
        return 1
    end

    for i = 1, size do
        local child = self:getTbNpc(tbNpc.children[i])
        if child then
            self:LeaveFight(child.id, code, reason)
        end
    end
    return 1
end

-- For child
function SimCitizen:GetParentPos(nListId)
    local tbNpc = self.fighterList[nListId]
    local foundParent = self:getTbNpc(tbNpc.parentID)
    if foundParent then
        local nX32, nY32, nW32 = GetNpcPos(foundParent.finalIndex)
        local nW = SubWorldIdx2ID(nW32)
        return nW, nX32 / 32, nY32 / 32
    end

    return 0, 0, 0
end

function SimCitizen:GetMyPosFromParent(nListId)
    local tbNpc = self.fighterList[nListId]
    local foundParent = self:getTbNpc(tbNpc.parentID)
    if foundParent then
        return self:GiveChildPos(tbNpc.parentID, tbNpc.childID)
    end

    return 0, 0, 0
end

function SimCitizen:IsParentFighting(nListId)
    local tbNpc = self.fighterList[nListId]
    local foundParent = self:getTbNpc(tbNpc.parentID)
    if foundParent and foundParent.isFighting == 1 then
        return 1
    end
    return 0
end
 
   
 

function SimCitizen:AddScoreToAroundNPC(nListId, nNpcIndex, currRank)
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

function SimCitizen:initCharConfig(config)
    config.playerID = config.playerID or "" -- dang theo sau ai do


    -- Init stats
    config.isFighting = 0
    config.tick_breath = 0
    config.tick_canswitch = 0
    config.camp = config.camp or random(1, 3)
    config.walkMode = config.walkMode or "random"
    config.noRevive = config.noRevive or 0
    config.fightingScore = 0
    config.rank = 1
    config.ngoaitrang = config.ngoaitrang or 0
    config.capHP = config.capHP or 1
    config.role = config.role or "citizen"
    config.level = config.level or 95
    config.isAttackable = config.isAttackable or 0
    if config.capHP and config.capHP ~= "auto" then
        config.maxHP = SimCityNPCInfo:getHPByCap(config.capHP)
    end
    config.parentAppointPos = {0, 0}
end




function SimCitizen:GetRandomWalkPoint(nListId, currentPosId)
    local tbNpc = self.fighterList[nListId]

    if tbNpc.role == "keoxe" or tbNpc.role == "child" then
        return "none"
    end

    if not tbNpc.worldInfo or not tbNpc.worldInfo.walkGraph then
        return "none"
    end

    -- If current position ID is provided, get next node from edges
    if currentPosId ~= nil then
        local edges = tbNpc.worldInfo.walkGraph.edges[currentPosId]
        if edges and getn(edges) > 0 then
            -- Count unvisited edges first
            local unvisitedCount = 0
            for i = 1, getn(edges) do
                local edgeId = edges[i]
                local isVisited = false
                
                -- Check if this edge was recently visited
                for j = 1, getn(tbNpc.last2VisitedEdges) do
                    if tbNpc.last2VisitedEdges[j] == edgeId then
                        isVisited = true
                        break
                    end
                end
                
                if not isVisited then
                    unvisitedCount = unvisitedCount + 1
                end
            end
            
            -- Choose which selection method to use
            local selectedEdge
            if unvisitedCount > 0 then
                -- Select from unvisited edges
                local targetUnvisited = random(1, unvisitedCount)
                local currentUnvisited = 0
                
                for i = 1, getn(edges) do
                    local edgeId = edges[i]
                    local isVisited = false
                    
                    -- Check if this edge was recently visited
                    for j = 1, getn(tbNpc.last2VisitedEdges) do
                        if tbNpc.last2VisitedEdges[j] == edgeId then
                            isVisited = true
                            break
                        end
                    end
                    
                    if not isVisited then
                        currentUnvisited = currentUnvisited + 1
                        if currentUnvisited == targetUnvisited then
                            selectedEdge = edgeId
                            break
                        end
                    end
                end
            else
                -- All edges were visited, just pick any edge
                selectedEdge = edges[random(1, getn(edges))]
            end
            
            -- Update the last visited edges (keep only the last 2)
            tinsert(tbNpc.last2VisitedEdges, 1, selectedEdge)
            if getn(tbNpc.last2VisitedEdges) > 2 then
                tremove(tbNpc.last2VisitedEdges, 3)
            end
            
            return selectedEdge
        end
    end
    
    -- Otherwise pick a random node
    local nodeCount = 0
    for id, _ in tbNpc.worldInfo.walkGraph.nodes do
        nodeCount = nodeCount + 1
    end
    if nodeCount == 0 then return nil end

    local targetIndex = random(1, nodeCount)
    local currentIndex = 0
    for id, _ in tbNpc.worldInfo.walkGraph.nodes do
        currentIndex = currentIndex + 1
        if currentIndex == targetIndex then
            return id
        end
    end
end