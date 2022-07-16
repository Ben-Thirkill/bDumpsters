AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")
 
function ENT:Initialize()
    self:SetModel("models/props_junk/TrashDumpster01a.mdl")
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS) 
    self:SetMoveType(MOVETYPE_VPHYSICS)
  	self:SetTrigger(true)

    local phys = self:GetPhysicsObject()

    if phys:IsValid() then
      phys:Wake()
    phys:SetMass(1000)
    end

    -- This is the main cooldown that times how long before you can use the dumpster again.
    self.cooldown = 0

    -- This is a mini cooldown that stops you from spamming when rummaging (you have to click e a few times before the dumpster actually opens)
    self.rummageCooldown = 0 

    -- How many attempts we've had to open it.
    self.openAttempts = 0
end

function ENT:Use(ply)

    self.cooldown = self.cooldown or 0

    -- Check the main cooldown. If it's bigger than the current time, return end.
    if self.cooldown > CurTime() then return end  


    self.rummageCooldown = self.rummageCooldown or 0

    -- Check the rummage cooldown. If it's bigger than the current time, return end.
    if self.rummageCooldown > CurTime() then return end 

    -- If the rummageCooldown has been ages ago, we reset self.openAttempts.
    self.openAttempts = self.openAttempts or 0

    if CurTime() - self.rummageCooldown > 5 then 

        self.openAttempts = 0
    end 

    -- We passed the rummage cooldown, now reset it and play the sound. 
    self.rummageCooldown = CurTime() + 0.3

    if bDumpsters.GetSetting("dumpster_limit_jobs") and not bDumpsters.GetSetting("dumpster_jobs")[ply:getJobTable().command] then 

        bDumpsters.Message(ply, bDumpsters.GetSetting("dumpster_incorrect_job"), "Dumpsters")

        return 
    end 

    local randomSound = math.random(0,100)
    local sound = "physics/cardboard/cardboard_box_impact_soft"..math.random(1,7)..".wav"

    if randomSound < 15 then 
        sound = "physics/cardboard/cardboard_box_impact_hard"..math.random(1,7)..".wav"
    end

    if randomSound < 8 then 
        sound = "phx/epicmetal_soft"..math.random(1,7)..".wav"
    end

    if randomSound < 3 then 
        sound = "player/footsteps/chainlink2.wav"
    end


    self:EmitSound(sound, 90, 100, 1, CHAN_AUTO )
 
    -- Shake their screen a bit.
    ply:ViewPunch( Angle(math.random(-12,8), math.random(-2,2), math.random(-2,2)))

    -- We want a 35% chance to throw some rubbish behind us.
    if bDumpsters.GetSetting("dumpster_props_throw") and math.random(0,100) < 35 then 
        
        -- Create the rubbish entity.
        local rubbish = ents.Create("prop_physics")
        rubbish:SetModel(table.Random(table.GetKeys(bDumpsters.GetSetting("dumpster_props"))))
        rubbish:SetPos(self:GetPos() + Vector(0,0,40))


        -- We don't want it colliding
        rubbish:SetCollisionGroup(COLLISION_GROUP_PASSABLE_DOOR)

        -- We want it to fly behind the player.
        local trajectory = (ply:GetPos() - self:GetPos())
        trajectory:Normalize()

        trajectory = trajectory * 300 + Vector(0,0,250)

        -- Spawn it
        rubbish:Spawn()

        -- Set Velocity
        local phys = rubbish:GetPhysicsObject()
        if phys then 
            phys:SetMass(1)
            phys:Wake()

            -- Set Velocity 
            phys:SetVelocity(trajectory)
        end

        timer.Simple(5, function()
            if IsValid(rubbish) then 
                rubbish:Remove()
            end
        end)
    end

    self.openAttempts = self.openAttempts + 1

    -- We have to click E 'dumpster_time_to_open' times before it opens
    if self.openAttempts < bDumpsters.GetSetting("dumpster_time_to_open") then return end 
    
    -- Reset the attempts.
    self.openAttempts = 0
    
    -- We got past, now we can set the proper cooldown.
    local cooldown = bDumpsters.GetSetting("dumpster_cooldown")

    -- The cooldown passed, set the main cooldown.
    self.cooldown = CurTime() + cooldown

    -- Send the cooldown to the client.
    net.Start("bdumpster_opened")
        net.WriteUInt(self.cooldown, 32)
        net.WriteUInt(self:EntIndex(), 16)
    net.Broadcast(ply)

    -- Give the player their loot! Maybe :)

    -- Well, first we'll spawn the useless props.
    for i=1, bDumpsters.GetSetting("dumpster_props_count") do 
        -- Create the rubbish entity.
        local rubbish = ents.Create("prop_physics")
        rubbish:SetModel(table.Random(table.GetKeys(bDumpsters.GetSetting("dumpster_props"))))
        rubbish:SetPos(self:GetPos() + Vector(math.random(-15,15),math.random(-25,25),math.random(30,50)))

        -- We don't want it colliding
        rubbish:SetCollisionGroup(COLLISION_GROUP_PASSABLE_DOOR)

        -- Spawn it
        rubbish:Spawn()

        -- Set Velocity
        local phys = rubbish:GetPhysicsObject()
        if phys then 
            phys:SetMass(1)
            phys:Wake()

            -- Set Velocity 
            phys:SetVelocity(Vector(0,0,20))
        end

        timer.Simple(6+i, function()
            if IsValid(rubbish) then 
                rubbish:Remove()
            end
        end)
    end

    -- Useless props over, now comes the money :)
    if math.random(0,100) <= bDumpsters.GetLootSetting("dumpster_money_chance") then 
        local notRubbish = ents.Create(GAMEMODE.Config.MoneyClass)
        notRubbish:SetPos(self:GetPos()+Vector(math.random(-5,5),math.random(-10,10),math.random(30,50)))
        notRubbish:Setamount(math.random(bDumpsters.GetLootSetting("dumpster_minimum_money"), bDumpsters.GetLootSetting("dumpster_maximum_money")))
        notRubbish:Spawn()
    end

    -- We will try for items x amount of times. 
    for i=1, bDumpsters.GetLootSetting("chances_per_dumpster") do 
        local luck = math.random(0,100)

        -- Now the Platinum tier items.
        if luck <= bDumpsters.GetLootSetting("chance_to_get_platinum") then 
            -- Give Platinum 

            local notRubbish = ents.Create(table.Random(table.GetKeys(bDumpsters.GetLootSetting("dumpster_luck_platinum"))))
            notRubbish:SetPos(self:GetPos()+Vector(math.random(-5,5),math.random(-10,10),math.random(30,50)))
            notRubbish:Spawn()

            continue 
        end

        -- Now the Gold tier GetLootSetting.
        if luck <= bDumpsters.GetLootSetting("chance_to_get_gold") + bDumpsters.GetLootSetting("chance_to_get_platinum") then 
            -- Give Gold 

            local notRubbish = ents.Create(table.Random(table.GetKeys(bDumpsters.GetLootSetting("dumpster_luck_gold"))))
            notRubbish:SetPos(self:GetPos()+Vector(math.random(-5,5),math.random(-10,10),math.random(30,50)))
            notRubbish:Spawn()

            continue 
        end

        -- Now the Silver tier items.
        if luck <= bDumpsters.GetLootSetting("chance_to_get_silver") + bDumpsters.GetLootSetting("chance_to_get_gold") then 
            -- Give Silver 

            local notRubbish = ents.Create(table.Random(table.GetKeys(bDumpsters.GetLootSetting("dumpster_luck_silver"))))
            notRubbish:SetPos(self:GetPos()+Vector(math.random(-5,5),math.random(-10,10),math.random(30,50)))
            notRubbish:Spawn()

            continue 
        end

        -- Now the Bronze tier items.
        if luck <= bDumpsters.GetLootSetting("chance_to_get_bronze") + bDumpsters.GetLootSetting("chance_to_get_silver") then 
            -- Give Bronze 

            local notRubbish = ents.Create(table.Random(table.GetKeys(bDumpsters.GetLootSetting("dumpster_luck_bronze"))))
            notRubbish:SetPos(self:GetPos()+Vector(math.random(-5,5),math.random(-10,10),math.random(30,50)))
            notRubbish:Spawn()

            continue 
        end

    end
end


