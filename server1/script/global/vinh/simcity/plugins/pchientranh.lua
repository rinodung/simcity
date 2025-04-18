SimCityChienTranh = {

	nW = 0,

	path1 = {},
	path2 = {},

	tongkim = 0,
	tongkim_camp2TopRight = 0
}

function createTaskSayChienTranh(mapId, extra)
	local tbOpt = {}
	local nSettingIdx = 1617
	local nActionId = 0
	if not extra then
		extra = ""
	end
	local counter = SimCityMainThanhThi:countMap(mapId)
	tinsert(tbOpt, 1, "<dec><link=image[8,15]:#npcspr:?NPCSID="..tostring(nSettingIdx).."?ACTION="..tostring(nActionId)..">Tri�u M�n:<link> Thi�p v�n kh�ng ph�i ng��i t�t, nh�ng thi�p ��i v�i ch�ng... ch�a t�ng gian d�i." .. extra .. "<enter><enter><color=yellow>Nh�n s� hi�n t�i: " .. counter .. "<color>");
	return tbOpt
end

function SimCityChienTranh:modeTongKim(enable, camp2TopRight)
	self.tongkim = enable
	self.tongkim_camp2TopRight = camp2TopRight
end

function SimCityChienTranh:genWalkPath_tongkim(forCamp)
	local path1 = { "huong1phai", "huong1trai", "huong1giua" }
	local path2 = { "huong2phai", "huong2trai", "huong2giua" }

	local campDirection = 0
	if (self.tongkim_camp2TopRight == 1 and forCamp == 1) then
		campDirection = 1
	end

	if (self.tongkim_camp2TopRight == 1 and forCamp == 2) then
		campDirection = 0
	end

	if (self.tongkim_camp2TopRight == 0 and forCamp == 1) then
		campDirection = 0
	end

	if (self.tongkim_camp2TopRight == 0 and forCamp == 2) then
		campDirection = 1 -- 1 = bottom to top
	end

	-- Bottom to top
	local myPath = {}
	if (campDirection == 1) then
		local firstPath = path1[random(1, getn(path1))]
		local secondPath = path2[random(1, getn(path2))]	
		tinsert(myPath, { "camp2spawn", 0 })
		tinsert(myPath, {firstPath, 1})
		tinsert(myPath, {secondPath, 1})
		tinsert(myPath, { "huong2tt", 1 })

		-- Top to bottom
	else
		local firstPath = path2[random(1, getn(path1))]
		local secondPath = path1[random(1, getn(path2))]	
		tinsert(myPath, { "camp1spawn", 0 })
		tinsert(myPath, {firstPath, -1})
		tinsert(myPath, {secondPath, -1})
		tinsert(myPath, { "huong1tt", 1 })
	end 
	return myPath
end

 


function SimCityChienTranh:genWalkPath(forCamp)
	if (self.tongkim == 1) then
		return self:genWalkPath_tongkim(forCamp)
	end
	-- Bottom to top
	if (forCamp == 1) then
		return {{self.path1[random(1, getn(self.path1))],1}}
	end

	if (forCamp == 2) then
		return {{self.path2[random(1, getn(self.path2))],1}}
	end

	return nil
end

function SimCityChienTranh:taoNV(id, camp, mapID, walkPathNames, nt, theosau, capHP, extraConfig)
	if not walkPathNames then
		return nil
	end

	local name = "Kim"
	local rank = 1
	local realCamp = 5
	if camp == 1 then
		name = "T�ng"
		realCamp = 0
	end

	local hardsetName = (nt == 1 and SimCityNPCInfo:generateName()) or SimCityNPCInfo:getName(id)
	if self.tongkim == 1 then
		realCamp = camp
		hardsetName = (nt == 1 and SimCityNPCInfo:generateName()) or nil
	end



	local tbNpc = {
		mode = "chiendau",
		szName = name or "",

		nNpcId = id,                            -- required, main char ID
		nMapId = mapID,                         -- required, map
		camp = realCamp,                        -- optional, camp

		walkMode = (theosau and "formation") or "preset", -- optional: random, keoxe, or formation for formation
		walkVar = (theosau and 3) or 4,         -- random walk of radius of 4*2
		walkPathNames = walkPathNames,

		noStop = 1,          -- optional: cannot pause any stop (otherwise 90% walk 10% stop)
		leaveFightWhenNoEnemy = 5, -- optional: leave fight instantly after no enemy, otherwise there's waiting period

		noRevive = 0,        -- optional: 0: keep reviving, 1: dead
 

		CHANCE_ATTACK_PLAYER = 1, -- co hoi tan cong nguoi choi neu di ngang qua
		CHANCE_ATTACK_NPC = 1, -- co hoi bat chien dau khi thay NPC khac phe
		CHANCE_JOIN_FIGHT = 1, -- co hoi tang cong NPC neu di ngang qua NPC danh nhau
		RADIUS_FIGHT_PLAYER = 15, -- scan for player around and randomly attack
		RADIUS_FIGHT_NPC = 15, -- scan for NPC around and start randomly attack,
		RADIUS_FIGHT_SCAN = 15, -- scan for fight around and join/leave fight it
 
		kind = 0,           -- quai mode
		TIME_FIGHTING_minTs = 1800,
		TIME_FIGHTING_maxTs = 3000,
		TIME_RESTING_minTs = 1,
		TIME_RESTING_maxTs = 3,

		resetPosWhenRevive = 1,

		tongkim = self.tongkim,
		tongkim_name = name,

		ngoaitrang = nt or 0,
		hardsetName = hardsetName,

		capHP = capHP,

		childrenSetup = theosau or nil,
		childrenCheckDistance = (theosau and 8) or nil -- force distance check for child

	}

	if extraConfig then
		for k,v in extraConfig do
			tbNpc[k] = v
		end
	end

	return SimCitizen:New(tbNpc)
end

function SimCityChienTranh:taodoi(thonglinh, camp, mapID, walkPathNames, children5)
	if not walkPathNames then
		return nil
	end
	local children = nil
	local name = "Kim Binh"

	local realCamp = 5

	if camp == 1 then
		name = "T�ng Binh"
		realCamp = 0
	end
	if children5 then
		children = {}
		for i = 1, getn(children5) do
			children = spawnN(children, children5[i][1], children5[i][2], { szName = name })
		end
	end

	if self.tongkim == 1 then
		realCamp = camp
	end


	return SimCitizen:New({
		mode = "chiendau",
		szName = name or "",
		tongkim = self.tongkim,

		nNpcId = thonglinh, -- required, main char ID
		nMapId = mapID,     -- required, map
		camp = realCamp,    -- optional, camp
		childrenSetup = children, -- optional, children
		walkMode = "formation", -- optional: random or 1 for formation
		walkPathNames = walkPathNames,
 
		noStop = 1,          -- optional: cannot pause any stop (otherwise 90% walk 10% stop)
		leaveFightWhenNoEnemy = 5, -- optional: leave fight instantly after no enemy, otherwise there's waiting period

		noRevive = 0,        -- optional: 0: keep reviving, 1: dead
 
		CHANCE_ATTACK_PLAYER = 1, -- co hoi tan cong nguoi choi neu di ngang qua
		CHANCE_ATTACK_NPC = 1, -- co hoi bat chien dau khi thay NPC khac phe
		CHANCE_JOIN_FIGHT = 1, -- co hoi tang cong NPC neu di ngang qua NPC danh nhau

		RADIUS_FIGHT_PLAYER = 15, -- scan for player around and randomly attack
		RADIUS_FIGHT_NPC = 15, -- scan for NPC around and start randomly attack,
		RADIUS_FIGHT_SCAN = 15, -- scan for fight around and join/leave fight it
 
		kind = 0,           -- quai mode
		TIME_FIGHTING_minTs = 1800,
		TIME_FIGHTING_maxTs = 3000,
		TIME_RESTING_minTs = 1,
		TIME_RESTING_maxTs = 3,

		resetPosWhenRevive = 1,
	})
end

function SimCityChienTranh:taophe(nW, camp, linhthuong1, linhthuong2, hieuuy, photuong, daituong, nguyensoai, kybinh)
	self:taodoi(nguyensoai, camp, nW, self:genWalkPath(camp), {
		{ linhthuong1, 20 },
		{ linhthuong2, 20 },
		{ hieuuy,      4 },
		{ photuong,    2 },
		{ daituong,    2 },
	})

	-- Team thuong
	self:taodoi(hieuuy, camp, nW, self:genWalkPath(camp), {
		{ linhthuong1, 20 },
		{ linhthuong2, 20 }
	})

	self:taodoi(kybinh, camp, nW, self:genWalkPath(camp), {
		{ kybinh, 6 },
	})


	self:taodoi(linhthuong2, camp, nW, self:genWalkPath(camp), {
		{ linhthuong1, 16 },
	})

	self:taodoi(photuong, camp, nW, self:genWalkPath(camp), {
		{ linhthuong2, 16 },
		{ hieuuy,      12 }
	})

	self:taodoi(hieuuy, camp, nW, self:genWalkPath(camp), {
		{ linhthuong1, 16 },
	})


	-- Team nguyen soai
	self:taodoi(nguyensoai, camp, nW, self:genWalkPath(camp), {
		{ linhthuong1, 20 },
		{ linhthuong2, 20 },
		{ hieuuy,      4 },
		{ photuong,    2 },
		{ daituong,    2 },
	})

	-- Team thuong
	self:taodoi(hieuuy, camp, nW, self:genWalkPath(camp), {
		{ linhthuong1, 20 },
		{ linhthuong2, 20 }
	})

	self:taodoi(kybinh, camp, nW, self:genWalkPath(camp), {
		{ kybinh, 6 },
	})


	self:taodoi(linhthuong2, camp, nW, self:genWalkPath(camp), {
		{ linhthuong1, 16 },
	})

	self:taodoi(photuong, camp, nW, self:genWalkPath(camp), {
		{ linhthuong2, 16 },
		{ hieuuy,      12 }
	})


	self:taodoi(hieuuy, camp, nW, self:genWalkPath(camp), {
		{ linhthuong1, 16 },
	})


	self:taodoi(hieuuy, camp, nW, self:genWalkPath(camp), {
		{ linhthuong1, 16 },
	})
end

function SimCityChienTranh:phe_tudo(startNPCIndex, perPage, ngoaitrang)
	self:TaoTongKimSpawn(ngoaitrang or 0)
	local forCamp = 1
	for i = 0, perPage do
		local id = startNPCIndex + i
		local myPath = self:genWalkPath(forCamp)

		local fighter = self:taoNV(id, forCamp, self.nW, myPath, ngoaitrang or 0)
		if fighter then
			if forCamp == 1 then
				forCamp = 2
			else
				forCamp = 1
			end
		end
	end
end

function SimCityChienTranh:phe_tudo_xe(startNPCIndex, perPage, ngoaitrang)
	self:TaoTongKimSpawn(ngoaitrang or 0)

	local forCamp = 1

	local maxIndex = startNPCIndex + perPage

	if maxIndex > SimCityNPCInfo.ALLNPCs_INFO_COUNT then
		maxIndex = SimCityNPCInfo.ALLNPCs_INFO_COUNT
	end

	for i = 1, 10 do
		local pid = random(startNPCIndex, maxIndex)
		local myPath = self:genWalkPath(forCamp)

		while SimCityNPCInfo:notFightingChar(pid) == 1 do
			pid = random(startNPCIndex, maxIndex)
		end

		-- 10 con theo sau
		local runSpeed = SimCityNPCInfo:getSpeed(pid) or 0

		local children = {}
		while getn(children) < 20 do
			local id = random(startNPCIndex, maxIndex)
			local mySpeed = SimCityNPCInfo:getSpeed(id) or 0
			if SimCityNPCInfo:notFightingChar(id) == 0 and (runSpeed == 0 or abs(mySpeed - runSpeed) <= 1) then
				tinsert(children, {
					nNpcId = id,
					szName = (ngoaitrang == 1 and SimCityNPCInfo:generateName()) or SimCityNPCInfo:getName(id)
				})
			end
		end


		self:taoNV(pid, forCamp, self.nW, myPath, ngoaitrang or 0, children, nil, {
			childrenWalkMode = "random"
		})

		if i > 5 then
			forCamp = 2
		end
	end
end

function SimCityChienTranh:nv_tudo(capHP)
	self:TaoTongKimSpawn(1)

	local forCamp = 1

	local pool = SimCityNPCInfo:getPoolByCap(capHP)

	local total = 0
	while total < 100 do
		local id = pool[random(1, getn(pool))]
		local myPath = self:genWalkPath(forCamp)

		local fighter = self:taoNV(id, forCamp, self.nW, myPath, 1, nil, capHP)
		if fighter then
			if forCamp == 1 then
				forCamp = 2
			else
				forCamp = 1
			end
			total = total + 1
		end
	end
end

function SimCityChienTranh:nv_tudo_xe(capHP)
	self:TaoTongKimSpawn(1)

	local forCamp = 1
	local pool = SimCityNPCInfo:getPoolByCap(capHP)

	for i = 1, 10 do
		local pid = pool[random(1, getn(pool))]
		local myPath = self:genWalkPath(forCamp)

		while SimCityNPCInfo:notFightingChar(pid) == 1 do
			pid = pool[random(1, getn(pool))]
		end

		-- 10 con theo sau
		local runSpeed = SimCityNPCInfo:getSpeed(pid) or 0

		local children = {}
		while getn(children) < 20 do
			local id = pool[random(1, getn(pool))]
			local mySpeed = SimCityNPCInfo:getSpeed(id) or 0
			if SimCityNPCInfo:notFightingChar(id) == 0 and (runSpeed == 0 or abs(mySpeed - runSpeed) <= 2) then
				tinsert(children, {
					nNpcId = id,
					szName = SimCityNPCInfo:generateName() or SimCityNPCInfo:getName(id)
				})
			end
		end


		self:taoNV(pid, forCamp, self.nW, myPath, 1, children, capHP, {
			childrenWalkMode = "random"
		})

		if i > 5 then
			forCamp = 2
		end
	end
end

function SimCityChienTranh:phe_quanbinh()
	-- PHE TONG BINH
	local linh = 682
	local kybinh = 1080
	local camp = 1

	self:taophe(self.nW, camp, linh, linh + 1, linh + 2, linh + 3, linh + 4, linh + 5, kybinh)


	-- PHE KIM BINH
	linh = 688
	kybinh = 1090
	camp = 2

	self:taophe(self.nW, camp, linh, linh + 1, linh + 2, linh + 3, linh + 4, linh + 5, kybinh)
end

function SimCityChienTranh:removeAll()
	SimCitizen:ClearMap(self.nW, "chiendau")
end

function SimCityChienTranh:getWorldName()
	local worldInfo = SimCityWorld:Get(self.nW)

	local counter = 0
	for k, v in SimCitizen.fighterList do
		if v.nMapId and v.nMapId == self.nW then
			counter = counter + 1
		end
	end
	return { worldInfo.name .. " Chi�n Lo�n<enter><color=yellow>Nh�n s� hi�n t�i: " .. counter }
end

function SimCityChienTranh:goiAnhHungThiepNgoaiTrang()
	local tbSay = createTaskSayChienTranh(self.nW)


	tinsert(tbSay, "�� t� tinh anh (100 thi�p)/#SimCityChienTranh:nv_tudo(1)")
	tinsert(tbSay, "�� t� tinh anh (5 nh�m)/#SimCityChienTranh:nv_tudo_xe(1)")

	tinsert(tbSay, "Cao th� nh�t l�u (100 thi�p)/#SimCityChienTranh:nv_tudo(2)")
	tinsert(tbSay, "Cao th� nh�t l�u (5 nh�m)/#SimCityChienTranh:nv_tudo_xe(2)")


	tinsert(tbSay, "Tuy�n ��nh cao th� (100 thi�p)/#SimCityChienTranh:nv_tudo(3)")
	tinsert(tbSay, "Tuy�n ��nh cao th� (5 nh�m)/#SimCityChienTranh:nv_tudo_xe(3)")

	tinsert(tbSay, "V� l�m ch� t�n (100 thi�p)/#SimCityChienTranh:nv_tudo(4)")
	tinsert(tbSay, "V� l�m ch� t�n (5 nh�m)/#SimCityChienTranh:nv_tudo_xe(4)")


	tinsert(tbSay, "Quay l�i./#SimCityChienTranh:mainMenu()")
	tinsert(tbSay, "K�t th�c ��i tho�i./no")
	CreateTaskSay(tbSay)
	return 1
end

function SimCityChienTranh:goiAnhHungThiep()
	local tbSay = createTaskSayChienTranh(self.nW)



	tinsert(tbSay, "Cao c�p 1 (500 thi�p)/#SimCityChienTranh:phe_tudo(1000,500,0)")
	--tinsert(tbSay, "Cao c�p 1 (5 xe)/#SimCityChienTranh:phe_tudo_xe(1000,500,0)")

	tinsert(tbSay, "Cao c�p 2 (500 thi�p)/#SimCityChienTranh:phe_tudo(1500,500,0)")
	--tinsert(tbSay, "Cao c�p 2 (5 xe)/#SimCityChienTranh:phe_tudo_xe(1500,500,0)")

	tinsert(tbSay, "Cao c�p 3 (500 thi�p)/#SimCityChienTranh:phe_tudo(2000,500,0)")
	--tinsert(tbSay, "Cao c�p 3 (5 xe)/#SimCityChienTranh:phe_tudo_xe(2000,500,0)")



	tinsert(tbSay, "Trung c�p (500 thi�p)/#SimCityChienTranh:phe_tudo(500,500,1)")
	--tinsert(tbSay, "Trung c�p (5 xe)/#SimCityChienTranh:phe_tudo_xe(500,500,0)")

	tinsert(tbSay, "Quay l�i./#SimCityChienTranh:mainMenu()")
	tinsert(tbSay, "K�t th�c ��i tho�i./no")
	CreateTaskSay(tbSay)
	return 1
end

function SimCityChienTranh:showBXH(inp)
	local worldInfo = SimCityWorld:Get(self.nW)

	worldInfo.showBXH = tonumber(inp)
	SimCityWorld:doShowBXH(self.nW)
	return SimCityChienTranh:caidat()
end

function SimCityChienTranh:showThangCap(inp)
	local worldInfo = SimCityWorld:Get(self.nW)

	worldInfo.showThangCap = inp
	return SimCityChienTranh:caidat()
end

function SimCityChienTranh:caidat()
	local worldInfo = SimCityWorld:Get(self.nW)

	local tbSay = createTaskSayChienTranh(self.nW)



	if worldInfo.showBXH == 1 then
		tinsert(tbSay, "Th�ng b�o x�p h�ng m�i ph�t [c�]/#SimCityChienTranh:showBXH(0)")
	else
		tinsert(tbSay, "Th�ng b�o x�p h�ng m�i ph�t [kh�ng]/#SimCityChienTranh:showBXH(1)")
	end

	if worldInfo.showThangCap == 1 then
		tinsert(tbSay, "Th�ng b�o th�ng c�p [c�]/#SimCityChienTranh:showThangCap(0)")
	else
		tinsert(tbSay, "Th�ng b�o th�ng c�p [kh�ng]/#SimCityChienTranh:showThangCap(1)")
	end


	tinsert(tbSay, "Quay l�i/#SimCityChienTranh:mainMenu()")
	tinsert(tbSay, "K�t th�c ��i tho�i./no")
	CreateTaskSay(tbSay)
	return 1
end

function SimCityChienTranh:mainMenu()
	local worldInfo = SimCityWorld:Get(self.nW)

	if (not worldInfo.chientranh) or (not worldInfo.chientranh.path1) or (not worldInfo.chientranh.path2) then

		local tbSay = createTaskSayThanhThi("<enter><enter>Chi�n lo�n t�i b�n �� n�y ch�a ���c m�. Ch�ng c� th� g�i <color=yellow>��a �� ch�<color> ��n t�c gi� tr�n fb h�i qu�n.")
		tinsert(tbSay, "K�t th�c ��i tho�i./no")
		CreateTaskSay(tbSay)
		return 1
	end

	worldInfo.allowFighting = 1
	worldInfo.showFightingArea = 0

	self.path1 = worldInfo.chientranh.path1
	self.path2 = worldInfo.chientranh.path2


	local tbSay = createTaskSayChienTranh(self.nW)
	if SimCityMainThanhThi then
		SimCityMainThanhThi:removeAll()
	end

	tinsert(tbSay, "Ph�t anh h�ng thi�p/#SimCityChienTranh:goiAnhHungThiepNgoaiTrang()")
	tinsert(tbSay, "Ph�t qu�i nh�n thi�p/#SimCityChienTranh:goiAnhHungThiep()")
	tinsert(tbSay, "�i�u ��ng qu�n binh/#SimCityChienTranh:phe_quanbinh()")
	tinsert(tbSay, "Xem b�ng x�p h�ng/#SimCitizen:ThongBaoBXH(" .. (self.nW) .. ")")
	tinsert(tbSay, "Ban l�nh/#SimCityChienTranh:caidat()")
	tinsert(tbSay, "Gi�i t�n/#SimCityChienTranh:removeAll()")
	tinsert(tbSay, "K�t th�c ��i tho�i./no")
	CreateTaskSay(tbSay)


	return 1
end

function SimCityChienTranh:TaoTongKimSpawn(ngoaitrang)
	if self.tongkim ~= 1 then
		return 1
	end
	local forCamp = 1
	local capHP = 3
	local pool = SimCityNPCInfo:getPoolByCap(capHP)
	local total = 0
	while total < 20 do
		local id = pool[random(1, getn(pool))]

		local campDirection = 0
		if (self.tongkim_camp2TopRight == 1 and forCamp == 1) then
			campDirection = 1
		end

		if (self.tongkim_camp2TopRight == 1 and forCamp == 2) then
			campDirection = 0
		end

		if (self.tongkim_camp2TopRight == 0 and forCamp == 1) then
			campDirection = 0
		end

		if (self.tongkim_camp2TopRight == 0 and forCamp == 2) then
			campDirection = 1 -- 1 = bottom to top
		end

		local myPath = {}
		if (campDirection == 1) then
			myPath = { {"haudoanh1", 1} }
		else
			myPath = { {"haudoanh2", 1} }
		end

		local fighter = self:taoNV(id, forCamp, self.nW, myPath, ngoaitrang, nil, capHP, {
			baoDanhTongKim = 1
		})
		if fighter then
			if forCamp == 1 then
				forCamp = 2
			else
				forCamp = 1
			end
			total = total + 1
		end
	end
	
end