Include("\\script\\global\\vinh\\simcity\\head.lua")
Include("\\script\\global\\vinh\\simcity\\controllers\\thanhthi.lua")

-- Main menu
function main()
	SimCityMainThanhThi:mainMenu()
	return 1
end

-- Main loop
function mainLoop()
    SimCitizen:ATick()
	SimTheoSau:ATick()
	GroupFighter:ATick()
    AddTimer(18, "mainLoop", SimCitizen)
end 

AddTimer(18, "mainLoop", SimCitizen)