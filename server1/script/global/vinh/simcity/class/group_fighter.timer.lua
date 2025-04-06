Include("\\script\\global\\vinh\\simcity\\head.lua")

function OnDeath(nNpcIndex)
	local npcType = GetNpcParam(nNpcIndex, 4)

	if npcType == 1 or npcType == 2 then
		%GroupFighter:OnNpcDeath(nNpcIndex, PlayerIndex or 0)
	end

end