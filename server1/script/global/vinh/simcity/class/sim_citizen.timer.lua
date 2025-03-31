Include("\\script\\global\\vinh\\simcity\\head.lua")


function OnTimer(nNpcIndex, nTimeOut)
	local nListId = GetNpcParam(nNpcIndex, PARAM_LIST_ID)	
	local continue = SimCitizen:OnTimer(nListId)
	if continue == 1 then
		SetNpcTimer(nNpcIndex, REFRESH_RATE)
	end
end

function OnDeath(nNpcIndex)
	local nListId = GetNpcParam(nNpcIndex, PARAM_LIST_ID)
	SimCitizen:OnDeath(nListId, nNpcIndex)	
end
