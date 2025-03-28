Include("\\script\\global\\vinh\\simcity\\config.lua")
IncludeLib("NPCINFO")
NpcFighter = {

    fighterList = {},
    counter = 1
}

function NpcFighter:getTbNpc(nListId)
    return self.fighterList["n"..nListId]
end

function NpcFighter:New(fighter)
    local nListId = self.counter
    self.counter = self.counter + 1

    local tbNpc = {
        id = nListId,
        children = nil,
        originalConfig = objCopy(fighter)
    }

    for k, v in fighter do
        tbNpc[k] = v
    end

    self.fighterList["n"..nListId] = tbNpc

    -- Setup walk paths
    if self:HardResetPos(nListId) == 0 then
        return nil
    end

    -- Bugfix series
    tbNpc.series = SimCityNPCInfo:GetSeries(tbNpc.originalConfig.nNpcId)

    -- Create the character on screen
    self:Show(nListId, 1, tbNpc.goX, tbNpc.goY)


    -- What about childrenSetup?
    self:SetupChildren(nListId)
    return nListId
end

function NpcFighter:Remove(nListId)
    local tbNpc = self:getTbNpc(nListId)
    if tbNpc then
        DelNpcSafe(tbNpc.finalIndex)
        tbNpc.fighterList["n"..nListId] = nil
    end
end

function NpcFighter:Show(nListId, isNew, goX, goY)
    local tbNpc = self:getTbNpc(nListId)
    local originalWalkPath = tbNpc.originalWalkPath
    local nPosId = tbNpc.hardsetPos

    if (not nPosId) or (not originalWalkPath[nPosId]) then
        nPosId = random(1, getn(originalWalkPath))
    end

    local nMapIndex = SubWorldID2Idx(tbNpc.nMapId)

    if nMapIndex >= 0 then
        local nNpcIndex

        local tX = tbNpc.walkPath[nPosId][1]
        local tY = tbNpc.walkPath[nPosId][2]

        if tbNpc.role == "child" then
            local pW, pX, pY = self:GetParentPos()
            tX = pX
            tY = pY
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
                    nY32 = tY * 32,
                    nPosId = nPosId
                }

                -- Otherwise choose side
                SetNpcCurCamp(nNpcIndex, tbNpc.camp)

                local nPosCount = getn(originalWalkPath)
                if nPosCount >= 1 then
                    SetNpcActiveRegion(nNpcIndex, 1)
                    tbNpc.nPosId = nPosId
                    SetNpcParam(nNpcIndex, PARAM_LIST_ID, tbNpc.id)
                    SetNpcScript(nNpcIndex, "\\script\\global\\vinh\\simcity\\class\\fighter.timer.lua")
                    SetNpcTimer(nNpcIndex, REFRESH_RATE)
                end

                -- Ngoai trang?
                if (tbNpc.ngoaitrang and tbNpc.ngoaitrang == 1) then
                    SimCityNgoaiTrang:makeup(self, nNpcIndex)
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

function NpcFighter:Respawn(nListId, code, reason)
    local tbNpc = self:getTbNpc(nListId)
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
        tbNpc.nPosId = random(1, getn(tbNpc.originalWalkPath))
        self:HardResetPos()

        -- 2 = qua map khac?
    elseif code == 2 then
        nX = 0
        nY = 0
        tbNpc.nPosId = 1
        self:HardResetPos()

        -- otherwise reset
    elseif isAllDead == 1 and (tbNpc.role == "vantieu" or tbNpc.role == "keoxe" or tbNpc.role == "child") then
        nX = tbNpc.walkPath[1][1]
        nY = tbNpc.walkPath[1][2]
        tbNpc.nPosId = 1
    elseif (isAllDead == 1 and tbNpc.resetPosWhenRevive and tbNpc.resetPosWhenRevive >= 1) then
        nX = tbNpc.walkPath[tbNpc.resetPosWhenRevive][1]
        nY = tbNpc.walkPath[tbNpc.resetPosWhenRevive][2]
        tbNpc.nPosId = tbNpc.resetPosWhenRevive
        self:HardResetPos()
    elseif (isAllDead == 1 and tbNpc.lastPos ~= nil) then
        nX = tbNpc.lastPos.nX32 / 32
        nY = tbNpc.lastPos.nY32 / 32
        tbNpc.nPosId = tbNpc.lastPos.nPosId
    else
        tbNpc.lastPos = {
            nX32 = nX,
            nY32 = nY,
            nPosId = tbNpc.nPosId
        }
    end

    tbNpc.hardsetPos = tbNpc.nPosId
    tbNpc.tick_checklag = nil
    tbNpc.lastHP = NPCINFO_GetNpcCurrentLife(tbNpc.finalIndex)
    if (isAllDead == 1) then
        tbNpc.lastHP = nil
    end


    -- Normal respawn ? Can del NPC
    DelNpcSafe(tbNpc.finalIndex)


    self:Show(nListId, 0, nX, nY)
end

function NpcFighter:IsNpcEnemyAround(nListId)
    local tbNpc = self:getTbNpc(nListId)
    local allNpcs = {}
    local nCount = 0
    local radius = tbNpc.RADIUS_FIGHT_SCAN or RADIUS_FIGHT_SCAN
    -- Keo xe?
    if tbNpc.role == "keoxe" then
        allNpcs, nCount = CallPlayerFunction(self:GetPlayer(), GetAroundNpcList, radius)
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
    allNpcs, nCount = Simcity_GetNpcAroundNpcList(tbNpc.finalIndex, radius)
    for i = 1, nCount do
        local fighter2Kind = GetNpcKind(allNpcs[i])
        local fighter2Camp = GetNpcCurCamp(allNpcs[i])
        if fighter2Kind == 0 and (IsAttackableCamp(tbNpc.camp, fighter2Camp) == 1) then
            if (tbNpc.role == "vantieu") then
                if (NPCINFO_GetLevel(allNpcs[i]) >= 20) then
                    return 1
                end
            else
                return 1
            end
        end
    end

    return 0
end

function NpcFighter:IsDialogNpcAround(nListId)
    local tbNpc = self:getTbNpc(nListId)
    if tbNpc.mode ~= "thanhthi" then        
        return 0
    end
    local allNpcs = {}
    local nCount = 0
    local radius = 8    
    allNpcs, nCount = Simcity_GetNpcAroundNpcList(tbNpc.finalIndex, radius)
    for i = 1, nCount do
        local fighter2Kind = GetNpcKind(allNpcs[i])
        local fighter2Name = GetNpcName(allNpcs[i])
        local nNpcId = GetNpcSettingIdx(allNpcs[i])
        if fighter2Kind == 3 and (nNpcId == 108 or nNpcId == 198 or nNpcId == 203 or nNpcId == 384) then
            return 1
        end
    end
    return 0
end

function NpcFighter:IsPlayerEnemyAround(nListId)
    local tbNpc = self:getTbNpc(nListId)
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

function NpcFighter:JoinFight(nListId, reason)
    local tbNpc = self:getTbNpc(nListId)
    if (tbNpc.role == "vantieu" and tbNpc.isAttackable == 0) then
        return 1
    end

    self:ChildrenJoinFight(reason)
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

    if (tbNpc.role == "vantieu") then
        self:NotifyOwner(3)
    end

    self:Respawn(nListId, 3, "JoinFight " .. reason)
    return 1
end

function NpcFighter:LeaveFight(nListId, isAllDead, reason)
    local tbNpc = self:getTbNpc(nListId)
    self:ChildrenLeaveFight(isAllDead, reason)

    isAllDead = isAllDead or 0

    tbNpc.isFighting = 0
    tbNpc.tick_canswitch = tbNpc.tick_breath +
        random(tbNpc.TIME_RESTING_minTs or TIME_RESTING.minTs,
            tbNpc.TIME_RESTING_maxTs or TIME_RESTING.maxTs) -- trong trang thai di bo 30s-1ph
    reason = reason or "no reason"

    -- Do not need to respawn just disable fighting
    if (isAllDead ~= 1 and (tbNpc.kind ~= 4 or tbNpc.isAttackable == 1)) then
        self:Walk2ClosestPoint()
        self:SetFightState(nListId, 0)
    else
        self:Respawn(nListId, isAllDead, reason)
    end
end

function NpcFighter:CanLeaveFight(nListId)
    local tbNpc = self:getTbNpc(nListId)
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

function NpcFighter:SetFightState(nListId, mode)
    local tbNpc = self:getTbNpc(nListId)
    SetNpcAI(tbNpc.finalIndex, mode)
end

function NpcFighter:TriggerFightWithNPC(nListId)
    if (self:IsNpcEnemyAround(nListId) == 1) then
        return self:JoinFight(nListId. "enemy around")
    end
    return 0
end

function NpcFighter:TriggerFightWithPlayer(nListId)
    local tbNpc = self:getTbNpc(nListId)
    -- FIGHT other player
    if GetNpcAroundPlayerList then
        if self:IsPlayerEnemyAround(nListId) == 1 then
            local nW = tbNpc.nMapId
            if tbNpc.role == "citizen" then
                local worldInfo = SimCityWorld:Get(nW)
                if worldInfo.showFightingArea == 1 then
                    local name = GetNpcName(tbNpc.finalIndex)
                    local lastPos = tbNpc.originalWalkPath[tbNpc.nPosId]


                    Msg2Map(tbNpc.nMapId,
                        "<color=white>" .. name .. "<color> Æ∏nh ng≠Íi tπi " .. worldInfo.name .. " " ..
                        floor(lastPos[1] / 8) .. " " .. floor(lastPos[2] / 16) .. "")
                end
            end
            return self:JoinFight(nListId. "player around")
        end
    end

    return 0
end

function NpcFighter:HasArrived()
    local nX32, nY32 = GetNpcPos(tbNpc.finalIndex)
    local oX = nX32 / 32;
    local oY = nY32 / 32;

    local nX
    local nY
    local checkDistance = DISTANCE_CAN_CONTINUE

    if tbNpc.role == "child" or tbNpc.parent == "vantieu" then
        nX = tbNpc.parentAppointPos and tbNpc.parentAppointPos[1] or 0
        nY = tbNpc.parentAppointPos and tbNpc.parentAppointPos[2] or 0

        if not nX or not nY or nX == 0 or nY == 0 then
            return 0
        end
    else
        local posIndex = tbNpc.nPosId
        local parentPos = tbNpc.walkPath[posIndex]

        local isExact = tbNpc.originalWalkPath[posIndex][3]
        nX = parentPos[1]
        nY = parentPos[2]
        if isExact == 1 then
            nX = tbNpc.originalWalkPath[posIndex][1]
            nY = tbNpc.originalWalkPath[posIndex][2]
        end
    end

    local distance = GetDistanceRadius(nX, nY, oX, oY)

    if distance < checkDistance then
        return self:ChildrenArrived()
    end
    return 0
end

function NpcFighter:Walk2ClosestPoint()
    local currPointer = tbNpc.nPosId
    local closestPointer = -1
    local closestDistance = 99999
    local maxPointer = getn(tbNpc.originalWalkPath)
    local pX, pY, _ = GetNpcPos(tbNpc.finalIndex)
    pX = pX / 32
    pY = pY / 32

    local tmp
    for i = currPointer - 5, currPointer + 5 do
        if (i > 0 and i <= maxPointer) then
            tmp = GetDistanceRadius(pX, pY, tbNpc.originalWalkPath[i][1], tbNpc.originalWalkPath[i][2])
            if (tmp < closestDistance) then
                closestDistance = tmp
                closestPointer = i
            end
        end
    end

    if closestPointer ~= -1 then
        tbNpc.nPosId = closestPointer
    end
end

function NpcFighter:GenWalkPath(hasJustBeenFlipped)
    -- Generate walkpath for myself
    local WalkSize = getn(tbNpc.originalWalkPath)
    tbNpc.walkPath = {}
    for i = 1, WalkSize do
        local point = tbNpc.originalWalkPath[i]
        if hasJustBeenFlipped == 0 then
            tinsert(tbNpc.walkPath, randomRange(point, tbNpc.walkVar or 2))
        else
            tinsert(tbNpc.walkPath, randomRange(point, tbNpc.walkVar or 2))
        end
    end
end

function NpcFighter:HardResetPos()
    local nW = tbNpc.nMapId
    local worldInfo = {}
    local walkAreas = {}

    -- Co duong di bao gom map
    if tbNpc.mapData then
        local mapData = tbNpc.mapData
        for i = 1, getn(mapData) do
            local dataPoint = mapData[i]
            if (dataPoint[1] == nW) then
                tinsert(walkAreas, { dataPoint[2], dataPoint[3] })
            end
        end
        tbNpc.originalWalkPath = arrCopy(walkAreas)
    else
        -- Dang di theo sau npc khac
        if tbNpc.role == "child" then
            local pW, pX, pY = self:GetParentPos()
            tbNpc.originalWalkPath = { { pX, pY } }
            tbNpc.nPosId = 1
            walkAreas = { { { pX, pY } } }

            -- Dang theo sau thi lay dia diem cua nguoi choi
        elseif tbNpc.role == "keoxe" or tbNpc.role == "vantieu" then
            local pW, pX, pY = CallPlayerFunction(self:GetPlayer(), GetWorldPos)
            worldInfo.showName = 1
            tbNpc.originalWalkPath = { { pX, pY } }
            tbNpc.nPosId = 1
            walkAreas = { { { pX, pY } } }

            -- hoac la sim thanh thi di tum lum
        else
            if not tbNpc.originalWalkPath then
                worldInfo = SimCityWorld:Get(nW)
                walkAreas = worldInfo.walkAreas
                if not walkAreas then
                    return 0
                end
               
                -- Fall back to old method if graph path generation failed
                if not tbNpc.originalWalkPath then
                    local walkIndex = random(1, getn(walkAreas))
                    tbNpc.originalWalkPath = arrCopy(walkAreas[walkIndex])
                end               

                tbNpc.hardsetPos = random(1, getn(tbNpc.originalWalkPath))
            end
        end
    end

    -- No path to walk?
    if not tbNpc.originalWalkPath or getn(tbNpc.originalWalkPath) < 1 then
        return 0
    end


    -- Startup position
    tbNpc.hardsetPos = tbNpc.hardsetPos or random(1, getn(tbNpc.originalWalkPath))

    -- Calculate walk path for main
    self:GenWalkPath(0)
end

function NpcFighter:NextMap()
    return 1
end

function NpcFighter:Breath()
    local nX32, nY32, nW32 = GetNpcPos(tbNpc.finalIndex)
    local nW = SubWorldIdx2ID(nW32)
    local worldInfo = {}

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

    if tbNpc.role == "vantieu" then
        self:OwnerPos()
    end

    -- CHAT FEATRUE - Khong dang theo sau ai het
    worldInfo = SimCityWorld:Get(nW)

    -- Di 1 minh
    if tbNpc.role == "citizen" then
        -- Otherwise just Random chat
        if worldInfo.allowChat == 1 then
            if tbNpc.isFighting == 1 then
                if random(1, CHANCE_CHAT / 2) <= 2 then
                    NpcChat(tbNpc.finalIndex, SimCityChat:getChatFight())
                end
            else
                if random(1, CHANCE_CHAT) <= 2 then
                    NpcChat(tbNpc.finalIndex, SimCityChat:getChat())
                end
            end
        end

        -- Show my ID
        if (worldInfo.showingId == 1) then
            local dbMsg = tbNpc.debugMsg or ""
            NpcChat(tbNpc.finalIndex, tbNpc.id .. " " .. tbNpc.nNpcId)
        end
    elseif tbNpc.role == "child" then
        pW, pX, pY = self:GetParentPos()
        cachNguoiChoi = GetDistanceRadius(myPosX, myPosY, pX, pY)
        if self:IsParentFighting() == 1 and tbNpc.isFighting == 0 then
            return self:JoinFight(nListId. "parent dang danh nhau")
        end
    elseif tbNpc.role == "keoxe" or tbNpc.role == "vantieu" then
        worldInfo.allowFighting = 1
        worldInfo.showFightingArea = 0

        local pID = self:GetPlayer()
        if pID > 0 then
            pW, pX, pY = CallPlayerFunction(pID, GetWorldPos)
            cachNguoiChoi = GetDistanceRadius(myPosX, myPosY, pX, pY)
        end
    end

    -- Is fighting? Do nothing except leave fight if possible
    if tbNpc.isFighting == 1 then
        if tbNpc.role == "vantieu" then
            if (self:CanLeaveFight(nListId) == 1) then
                self:LeaveFight(nListId. 0, "khong tim thay quai")
            end
            return 1
        end

        -- Case 1: toi gio chuyen doi
        if tbNpc.tick_canswitch < tbNpc.tick_breath then
            return self:LeaveFight(nListId. 0, "toi gio thay doi trang thai")
        end

        -- Case 2: tu dong thoat danh khi khong con ai
        if self:CanLeaveFight(nListId) == 1 then
            -- self:LeaveFight(nListId. 0, "khong tim thay quai")
            return 1
        end

        -- Case 3: qua xa nguoi choi phai chay theo ngay
        if (tbNpc.role == "keoxe" and cachNguoiChoi > DISTANCE_FOLLOW_PLAYER) then
            tbNpc.tick_canswitch = tbNpc.tick_breath - 1
            self:LeaveFight(nListId. 0, "chay theo nguoi choi")
        elseif (tbNpc.role == "child" and cachNguoiChoi > DISTANCE_FOLLOW_PLAYER) then
            --tbNpc.tick_canswitch = tbNpc.tick_breath - 1
            --self:LeaveFight(nListId. 0, "chay theo parent")
            return 1
        else
            return 1
        end
    end

    -- Up to here means walking
    local nNextPosId = tbNpc.nPosId
    local originalWalkPath = tbNpc.originalWalkPath
    local WalkSize = getn(originalWalkPath)
    if tbNpc.role == "citizen" and (nNextPosId == 0 or WalkSize < 2) then
        return 0
    end

    

    -- Binh thuong
    if ((tbNpc.role == "keoxe" and cachNguoiChoi <= DISTANCE_SUPPORT_PLAYER) or
            (tbNpc.role == "child" and cachNguoiChoi <= DISTANCE_SUPPORT_PLAYER) or
            tbNpc.role == "citizen") and worldInfo.allowFighting == 1 and
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

            for key, fighter2 in FighterManager.fighterList do
                if fighter2.id ~= tbNpc.id and fighter2.nMapId == tbNpc.nMapId and
                    (fighter2.isFighting == 0 and IsAttackableCamp(fighter2.camp, tbNpc.camp) == 1) then
                    local otherPosX, otherPosY, otherPosW = GetNpcPos(fighter2.finalIndex)
                    otherPosX = floor(otherPosX / 32)
                    otherPosY = floor(otherPosY / 32)

                    local distance = floor(GetDistanceRadius(otherPosX, otherPosY, myPosX, myPosY))
                    local checkDistance = tbNpc.RADIUS_FIGHT_NPC or RADIUS_FIGHT_NPC
                    if distance < checkDistance then
                        countFighting = countFighting + 1
                        FighterManager:Get(fighter2.id):JoinFight(nListId. "caused by others " ..
                            distance .. " (" .. otherPosX ..
                            " " .. otherPosY .. ") (" .. myPosX .. " " .. myPosY .. ")")
                    end
                end
            end

            -- If someone is around or I am not crazy then I fight
            if countFighting > 0 or tbNpc.attackNpcChance > 1 then
                countFighting = countFighting + 1
                self:JoinFight(nListId. "I start a fight")
            end

            if countFighting > 0 and worldInfo.showFightingArea == 1 then
                Msg2Map(nW,
                    "C„ " .. countFighting .. " nh©n s‹ Æang Æ∏nh nhau tπi " .. worldInfo.name ..
                    " <color=yellow>" .. floor(myPosX / 8) .. " " .. floor(myPosY / 16) .. "<color>")
            end

            if (countFighting > 0) then
                return 1
            end
        end
    end

    -- Van tieu
    if (tbNpc.role == "vantieu") then
        -- Co NPC dang tan cong?
        if (tbNpc.CHANCE_ATTACK_NPC and random(0, tbNpc.CHANCE_ATTACK_NPC) <= 2) then
            if self:TriggerFightWithNPC(nListId) == 1 then
                return 1
            end
        end

        -- Co Nguoi choi dang tan cong?
        if (tbNpc.CHANCE_ATTACK_PLAYER and random(0, tbNpc.CHANCE_ATTACK_PLAYER) <= 2) then
            if self:TriggerFightWithPlayer(nListId) == 1 then
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
        if self:HasArrived() == 1 then
            -- Keep walking no stop
            local keepWalkingRate = 90
            if self:IsDialogNpcAround(nListId) == 1 then
                keepWalkingRate = 5
            end

            if (tbNpc.noStop == 1 or random(1, 100) < keepWalkingRate) then
                nNextPosId = nNextPosId + 1

                -- End of the array
                if nNextPosId > WalkSize then
                    if tbNpc.noBackward == 1 then
                        self:NextMap()
                        return 1
                    end

                    -- Fall back to flipping if not using graph paths or if generation failed
                    tbNpc.originalWalkPath = arrFlip(tbNpc.originalWalkPath)
                    nNextPosId = 1
                    tbNpc.nPosId = nNextPosId

                    self:GenWalkPath(1)
                else
                    tbNpc.nPosId = nNextPosId
                end
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

        local targetPos = tbNpc.walkPath[nNextPosId]
        local nX = targetPos[1]
        local nY = targetPos[2]

        NpcWalk(tbNpc.finalIndex, nX, nY)
        self:CalculateChildrenPosition(nX, nY)
    elseif tbNpc.role == "child" then
        -- Mode 2: follow parent NPC
        -- Player has gone different map? Do respawn
        local needRespawn = 0
        pW, pX, pY = self:GetParentPos()

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
                tbNpc.originalWalkPath = { { pX, pY } }
                tbNpc.nPosId = 1
                self:GenWalkPath(0)
                self:Respawn(nListId, 2, "qua xa parent")
                return 1
            end
        else
            return 1
        end


        -- Otherwise walk toward parent
        local targetW, targetX, targetY = self:GetMyPosFromParent()

        -- Parent gave info?
        if targetW > 0 and targetX > 0 and targetY > 0 then
            tbNpc.parentAppointPos = { targetX, targetY }
            NpcWalk(tbNpc.finalIndex, targetX, targetY)

            -- No info we would work by ourself
        else
            local targetPos = tbNpc.walkPath[nNextPosId]
            local nX = targetPos[1]
            local nY = targetPos[2]
            NpcWalk(tbNpc.finalIndex, nX, nY)
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
            tbNpc.originalWalkPath = { { pX, pY } }
            tbNpc.nPosId = 1
            self:GenWalkPath(0)
            self:Respawn(nListId, 2, "qua xa nguoi choi")
            return 1
        end


        -- Otherwise walk toward parent
        if tbNpc.parentAppointPos then
            NpcWalk(tbNpc.finalIndex, tbNpc.parentAppointPos[1], tbNpc.parentAppointPos[2])
        else
            NpcWalk(tbNpc.finalIndex, pX + random(-2, 2), pY + random(-2, 2))
        end
    elseif tbNpc.role == "vantieu" then
        -- Mode 4: follow parent player
        -- Player has gone different map? Do nothing
        if tbNpc.nMapId ~= pW then
            return 1
        end

        -- Otherwise walk toward parent
        if tbNpc.bOwnerHere == 1 then
            if tbNpc.parentAppointPos then
                NpcWalk(tbNpc.finalIndex, tbNpc.parentAppointPos[1], tbNpc.parentAppointPos[2])
            end
        end
    end
    return 1
end

function NpcFighter:OnTimer()
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

    self:Breath()

    return 1
end

function NpcFighter:OnDeath()
    if tbNpc.role == "citizen" and tbNpc.children then
        local child

        for i = 1, getn(tbNpc.children) do
            local each = FighterManager:Get(tbNpc.children[i])
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
        SimCityTongKim:updateRank(self)


        -- No revive? Do removal
        if tbNpc.noRevive == 1 then
            if tbNpc.role == "citizen" then
                FighterManager:Remove(tbNpc.id)
            end

            if tbNpc.role == "vantieu" then
                self:NotifyOwner(1)
            end
            return 1
        end
        -- Do revive? Reset and leave fight
        self:LeaveFight(nListId. 1, "die toan bo")
    end
end

function NpcFighter:KillTimer()
    tbNpc.killTimer = 1
end

-- For keo xe
function NpcFighter:GetPlayer()
    if tbNpc.playerID == "" then
        return 0
    end
    return SearchPlayer(tbNpc.playerID)
end

-- For parent
function NpcFighter:SetupChildren()
    if tbNpc.childrenSetup and getn(tbNpc.childrenSetup) > 0 then
        local createdChildren = {}

        local nX32, nY32, nW32 = GetNpcPos(tbNpc.finalIndex)
        local nW = SubWorldIdx2ID(nW32)
        local nX = nX32 / 32
        local nY = nY32 / 32

        -- Create children
        for i = 1, getn(tbNpc.childrenSetup) do
            local childConfig = objCopy(tbNpc.originalConfig)
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
            local childId = FighterManager:Add(childConfig)
            tinsert(createdChildren, childId)
        end

        tbNpc.children = createdChildren
    end
end

function NpcFighter:GiveChildPos(i)
    if tbNpc.childrenPath and getn(tbNpc.childrenPath) >= i then
        return tbNpc.nMapId, tbNpc.childrenPath[i][1], tbNpc.childrenPath[i][2]
    end
    return 0, 0, 0
end

function NpcFighter:CalculateChildrenPosition(X, Y)
    if not tbNpc.children then
        return 1
    end
    local size = getn(tbNpc.children)
    if size == 0 then
        return 1
    end

    if tbNpc.walkMode and tbNpc.walkMode == "formation" then
        local centerCharId = getCenteredCell(createFormation(size))
        local fighter = FighterManager:Get(tbNpc.children[centerCharId])

        if fighter and fighter.isDead == 1 then
            for i = 1, size do
                fighter = FighterManager:Get(tbNpc.children[i])
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

function NpcFighter:ChildrenArrived()
    if not tbNpc.children then
        return 1
    end
    local size = getn(tbNpc.children)
    if size == 0 then
        return 1
    end

    for i = 1, size do
        local child = FighterManager:Get(tbNpc.children[i])
        if child and child.isDead ~= 1 and child:HasArrived() == 0 then
            return 0
        end
    end
    return 1
end

function NpcFighter:ChildrenJoinFight(code)
    if not tbNpc.children then
        return 1
    end
    local size = getn(tbNpc.children)
    if size == 0 then
        return 1
    end

    for i = 1, size do
        local child = FighterManager:Get(tbNpc.children[i])
        if child then
            child:JoinFight(nListId. code)
        end
    end
    return 1
end

function NpcFighter:ChildrenLeaveFight(code, reason)
    if not tbNpc.children then
        return 1
    end
    local size = getn(tbNpc.children)
    if size == 0 then
        return 1
    end

    for i = 1, size do
        local child = FighterManager:Get(tbNpc.children[i])
        if child then
            child:LeaveFight(nListId. code, reason)
        end
    end
    return 1
end

-- For child
function NpcFighter:GetParentPos()
    local foundParent = FighterManager:Get(tbNpc.parentID)
    if foundParent then
        local nX32, nY32, nW32 = GetNpcPos(foundParent.finalIndex)
        local nW = SubWorldIdx2ID(nW32)
        return nW, nX32 / 32, nY32 / 32
    end

    return 0, 0, 0
end

function NpcFighter:GetMyPosFromParent()
    local foundParent = FighterManager:Get(tbNpc.parentID)
    if foundParent then
        return foundParent:GiveChildPos(tbNpc.childID)
    end

    return 0, 0, 0
end

function NpcFighter:IsParentFighting()
    local foundParent = FighterManager:Get(tbNpc.parentID)
    if foundParent and foundParent.isFighting == 1 then
        return 1
    end
    return 0
end

-- Van tieu
function NpcFighter:OwnerPos()
    local nOwnerIndex = SearchPlayer(tbNpc.playerID)
    if not (nOwnerIndex > 0) then
        return not self:OwnerFarAway()
    end

    local nOwnerX32, nOwnerY32, nOwnerMapIndex = CallPlayerFunction(nOwnerIndex, GetPos)
    if not nOwnerX32 then
        return not self:OwnerFarAway()
    end

    local nSelfX32, nSelfY32, nSelfMapIndex = GetNpcPos(tbNpc.finalIndex)
    local nDis = ((nOwnerX32 - nSelfX32) ^ 2) + ((nOwnerY32 - nSelfY32) ^ 2)
    if nOwnerMapIndex ~= nSelfMapIndex or nDis >= 750 * 750 then
        return not self:OwnerFarAway()
    end

    self:OwnerNear()
end

function NpcFighter:OwnerNear()
    local nOwnerIndex = SearchPlayer(tbNpc.playerID)

    local pFightState = CallPlayerFunction(nOwnerIndex, GetFightState)

    if pFightState == 1 and tbNpc.isAttackable == 0 then
        tbNpc.isAttackable = pFightState
        self:Respawn(nListId, 0, "chuyen sang attackable")
    end

    tbNpc.isAttackable = pFightState

    if not tbNpc.bOwnerHere then
        self:OnOwnerEnter()
        tbNpc.bOwnerHere = 1
    end
end

function NpcFighter:OnOwnerEnter()
    local nOwnerIndex = SearchPlayer(tbNpc.playerID)
    KhoaTHP(nOwnerIndex, 1)
end

function NpcFighter:OwnerFarAway()
    if tbNpc.bOwnerHere then
        tbNpc.bOwnerHere = nil
        self:OnOwnerLeave()
        --else
        --if GetCurServerTime() - tbNpc.nPlayerLeaveTime >= 5 * 60 then
        --	local _, _, nMapIndex = GetNpcPos(tbNpc.nNpcIndex)
        --	-- do someting when owner leave for 5 minutes here
        --	return 1
        --end
    end
end

function NpcFighter:OnOwnerLeave()
    local nOwnerIndex = SearchPlayer(tbNpc.playerID)
    local nCurTime = GetCurServerTime()
    tbNpc.isAttackable = 1
    tbNpc.nPlayerLeaveTime = nCurTime
    if nOwnerIndex > 0 then
        self:NotifyOwner(0)
        KhoaTHP(nOwnerIndex, 0)
    end
end

function NpcFighter:NotifyOwner(code)
    local nOwnerIndex = SearchPlayer(tbNpc.playerID)
    if (not tbNpc.playerLeftMap or tbNpc.playerLeftMap == 0) and nOwnerIndex > 0 then
        local name = "<color=cyan>" .. tbNpc.szName .. "<color=white>"
        local msg = ""
        local location = ""

        -- Find out the location
        local worldInfo = SimCityWorld:Get(tbNpc.nMapId)
        local lastPos = tbNpc.lastKnownPos
        if worldInfo and worldInfo.name then
            if lastPos then
                location = "tπi <color=yellow>" .. worldInfo.name .. " <color=red>" ..
                    floor(lastPos.nX32 / (32 * 8)) .. " " .. floor(lastPos.nY32 / (32 * 16)) .. ""
            else
                location = "tπi <color=yellow>" .. worldInfo.name
            end
        end

        -- Output the msg
        if code == 0 then
            msg = name .. " Æang bﬁ b· lπi ph›a sau " .. location
        end
        if code == 1 then
            msg = name .. " m t t›ch " .. location
        end
        if code == 2 then
            msg = name .. " kh´ng may ch’t trong khi di chuy”n"
        end
        if code == 3 then
            msg = name .. " Æang bﬁ t n c´ng " .. location
        end

        -- Send to the user
        CallPlayerFunction(nOwnerIndex, Msg2Player, msg)
    end
end

function NpcFighter:OwnerLostOnTransport()
    self:NotifyOwner(2)
    FighterManager:Remove(tbNpc.id)
end

function NpcFighter:OnPlayerLeaveMap(nX2, nY2, nMapIndex2)
    if tbNpc.isFighting == 1 then
        return
    end
    local nX1, nY1, nMapIndex1 = GetNpcPos(tbNpc.finalIndex)
    if nMapIndex1 ~= nMapIndex2 then
        return
    end

    local nDis = ((nX1 - nX2) ^ 2) + ((nY1 - nY2) ^ 2)
    if nDis <= 750 * 750 then
        tbNpc.playerLeftMap = 1
    end
end

function NpcFighter:OnPlayerEnterMap(nX2, nY2, nMapIndex2)
    if tbNpc.playerLeftMap == 1 then
        local playerIndex = self:GetPlayer()

        if playerIndex > 0 and IsNearStation(playerIndex) == 1 then
            if (random(1, 99) <= 95) then
                tbNpc.playerLeftMap = 0
                self:OwnerLostOnTransport()
                return 0
            end
        end

        local pW, pX, pY = CallPlayerFunction(playerIndex, GetWorldPos)
        tbNpc.nMapId = pW
        tbNpc.goX = pX
        tbNpc.goY = pY

        tbNpc.isFighting = 0
        tbNpc.tick_canswitch = tbNpc.tick_breath
        tbNpc.originalWalkPath = { { pX, pY } }
        tbNpc.walkPath = { { pX, pY } }
        tbNpc.nPosId = 1
        self:GenWalkPath(0)
        self:Respawn(nListId, 2, "chu xe tieu qua map")
        tbNpc.playerLeftMap = 0
    end
end
