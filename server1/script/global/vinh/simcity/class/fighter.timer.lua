Include("\\script\\global\\vinh\\simcity\\head.lua")


function OnTimer(nNpcIndex, nTimeOut)
	local nListId = GetNpcParam(nNpcIndex, PARAM_LIST_ID)	
	local continue = NpcFighter:OnTimer(nListId)
	if continue == 1 then
		SetNpcTimer(nNpcIndex, REFRESH_RATE)
	end
end

function OnDeath(nNpcIndex)
	local nListId = GetNpcParam(nNpcIndex, PARAM_LIST_ID)
	NpcFighter:OnDeath(nListId, nNpcIndex)	
end
