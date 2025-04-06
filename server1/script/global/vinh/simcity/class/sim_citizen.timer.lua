Include("\\script\\global\\vinh\\simcity\\head.lua")

function OnDeath(nNpcIndex)
	local nListId = GetNpcParam(nNpcIndex, PARAM_LIST_ID)
	SimCitizen:OnDeath(nListId, nNpcIndex)	
end
