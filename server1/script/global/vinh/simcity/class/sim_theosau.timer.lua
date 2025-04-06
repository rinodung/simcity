Include("\\script\\global\\vinh\\simcity\\head.lua")

function OnDeath(nNpcIndex)
	local nListId = GetNpcParam(nNpcIndex, PARAM_LIST_ID)
	SimTheoSau:OnDeath(nListId, nNpcIndex)	
end
