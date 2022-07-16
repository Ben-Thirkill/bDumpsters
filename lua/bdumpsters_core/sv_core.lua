util.AddNetworkString("bdumpster_opened")
util.AddNetworkString("bdumpster_request_info")
util.AddNetworkString("bdumpster_send_info")
util.AddNetworkString("bdumpsters_msg")

net.Receive("bdumpster_request_info", function(len, ply)
	local index = net.ReadUInt(6)
	local ent = Entity(index)

	if not IsValid(ent) or ent:GetClass() != "bdumpster" then return end 

    net.Start("bdumpster_send_info")
        net.WriteUInt(ent.cooldown, 32)
        net.WriteUInt(ent:EntIndex(), 6)
    net.Send(ply)
end)

