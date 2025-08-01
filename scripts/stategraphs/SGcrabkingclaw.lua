require("stategraphs/commonstates")

--------------------------------------------------------------------------

local AOE_RANGE_PADDING = 3
local AOE_TARGET_MUSTHAVE_TAGS = { "_combat" }
local AOE_TARGET_CANT_TAGS = { "crabking_ally", "INLIMBO", "flight", "invisible", "notarget", "noattack" }

local function DoArcAttack(inst, radius, arc, arcoffset, targets)
	inst.components.combat.ignorehitrange = true
	local x, y, z = inst.Transform:GetWorldPosition()
	local theta = (inst.Transform:GetRotation() + (arcoffset or 0)) * DEGREES
	local halfarc = arc / 2 * DEGREES
	local sin_halfarc = math.sin(halfarc)
	for i, v in ipairs(TheSim:FindEntities(x, y, z, radius + AOE_RANGE_PADDING, AOE_TARGET_MUSTHAVE_TAGS, AOE_TARGET_CANT_TAGS)) do
		if v ~= inst and
			not targets[v] and
			v:IsValid() and not v:IsInLimbo() and
			not (v.components.health and v.components.health:IsDead())
		then
			local arctest = false
			local x1, y1, z1 = v.Transform:GetWorldPosition()
			if x == x1 and z == z1 then
				arctest = true
			else
				local dx = x1 - x
				local dz = z1 - z
				local distsq = dx * dx + dz * dz
				local physrad = v:GetPhysicsRadius(0)
				local range = radius + physrad
				if distsq < range * range then
					local angle = math.atan2(-dz, dx) 
					local diffangle = DiffAngleRad(angle, theta)
					if diffangle < halfarc then
						arctest = true
					elseif physrad > 0 and diffangle * 2 < PI then
						local dist = math.sqrt(distsq)
						local len = math.sin(diffangle) * dist
						range = sin_halfarc * dist + physrad
						if len < range then
							arctest = true
						end
					end
				end
			end
			if arctest and inst.components.combat:CanTarget(v) then
				inst.components.combat:DoAttack(v)
				targets[v] = true
			end
		end
	end
	inst.components.combat.ignorehitrange = false
end

--------------------------------------------------------------------------

local function play_shadow_animation(inst, anim, loop)
    inst.AnimState:PlayAnimation(anim,loop)
    if inst.shadow then
        inst.shadow.AnimState:PlayAnimation(anim,loop)
    end
end

local function push_shadow_animation(inst, anim, loop)
    inst.AnimState:PushAnimation(anim,loop)
    if inst.shadow then
        inst.shadow.AnimState:PushAnimation(anim,loop)
    end
end

local actionhandlers =
{
    ActionHandler(ACTIONS.HAMMER, "attack"),
    ActionHandler(ACTIONS.ATTACK, "attack"),
}

local events =
{
    CommonHandlers.OnLocomote(true,true),
    CommonHandlers.OnFreeze(),
	CommonHandlers.OnElectrocute(),
    CommonHandlers.OnDeath(),

    EventHandler("attacked", function(inst, data)
		if not inst.components.health:IsDead() then
			if CommonHandlers.TryElectrocuteOnAttacked(inst, data) then
				return
			elseif not inst.sg:HasStateTag("busy") or inst.sg:HasAnyStateTag("caninterrupt", "frozen") then
				inst.sg:GoToState("hit")
            end
        end
    end),
    EventHandler("doattack", function(inst, data)
		if not (inst.sg:HasStateTag("busy") or inst.components.health:IsDead()) then
			inst.sg:GoToState("attack")
		end
    end),
    EventHandler("emerge", function(inst, data)
		if not (inst.sg:HasStateTag("nointerrupt") or inst.components.health:IsDead()) then
			inst.sg:GoToState("emerge")
		end
    end),
    EventHandler("submerge", function(inst, data)
		if not inst.components.health:IsDead() then
			if not inst.sg:HasStateTag("busy") or inst.sg:HasStateTag("frozen") then
				inst.sg:GoToState("submerge")
			else
				inst.sg.mem.wantstosubmerge = true
			end
		end
	end),
}

local states =
{
    State{
        name = "idle",
        tags = { "idle", "canrotate" },

		onenter = function(inst)
			if inst.sg.mem.wantstosubmerge then
				inst.sg:GoToState("submerge")
				return
			end
			play_shadow_animation(inst, "idle")
        end,

        events =
        {
            EventHandler("animover", function(inst)
                inst.sg:GoToState("idle")
            end),
        },

		onexit = function(inst)
			--NOTE: we stay in 8-faced when returning to idle from attack
			inst.Transform:SetSixFaced()
		end,
    },

    State{
        name = "emerge",
		tags = { "busy", "canrotate", "nointerrupt", "noattack", "invisible", "temp_invincible" },

        onenter = function(inst, pushanim)
			if inst.components.freezable:IsFrozen() then
				inst.components.freezable:Unfreeze()
			end
            play_shadow_animation(inst, "emerge")
            --inst.AnimState:PlayAnimation("emerge")
            inst.SoundEmitter:PlaySound("turnoftides/common/together/water/emerge/medium")

        end,

		timeline =
		{
			FrameEvent(14, function(inst)
				inst.sg:RemoveStateTag("invisible")
			end),
			FrameEvent(16, function(inst)
				inst.sg:RemoveStateTag("noattack")
				inst.sg:RemoveStateTag("temp_invincible")
			end),
			FrameEvent(32, function(inst)
				inst.sg:RemoveStateTag("nointerrupt")
			end),
		},

        events =
        {
            EventHandler("animover", function(inst)
                inst.sg:GoToState("idle")
            end),
        },
    },

    State{
        name = "submerge",
		tags = { "busy", "canrotate", "nointerrupt" },

        onenter = function(inst, pushanim)
			if inst.components.freezable:IsFrozen() then
				inst.components.freezable:Unfreeze()
			end
            play_shadow_animation(inst, "submerge")
            inst.SoundEmitter:PlaySound("turnoftides/common/together/water/emerge/medium")

            inst.sg:SetTimeout(inst.AnimState:GetCurrentAnimationLength())

            inst.persists = false
        end,

		timeline =
		{
			FrameEvent(31, function(inst)
				inst.sg:AddStateTag("noattack")
				inst.sg:AddStateTag("temp_invincible")
			end),
			FrameEvent(33, function(inst)
				inst.sg:AddStateTag("invisible")
			end),
		},

        ontimeout = function(inst)
            inst:Remove()
        end,
    },

	State{
		name = "attack",
		tags = { "busy", "canrotate" },

		onenter = function(inst, target)
			inst.components.locomotor:Stop()
			inst.Transform:SetEightFaced()
			inst.AnimState:PlayAnimation("atk")
            inst.components.combat:RestartCooldown()
			inst.components.combat:StartAttack()

			if target and target:IsValid() then
				inst:ForceFacePoint(target.Transform:GetWorldPosition())
			end
		end,

		timeline =
		{
			FrameEvent(18, function(inst)
				--spawn 3 frames early (with 3 leading blank frames) since anim is super short, and tends to get lost with network timing
				inst.sg.statemem.fx = SpawnPrefab("crabking_claw_swipe_fx")
				inst.sg.statemem.fx.entity:SetParent(inst.entity)
			end),
			FrameEvent(21, function(inst)
				inst.sg.statemem.targets = {}
				--NOTE: range is about 6 in the art file, but this prefab is scaled by 70%!
				DoArcAttack(inst, 4, 45, 67.5, inst.sg.statemem.targets)

                inst.SoundEmitter:PlaySound("meta4/crabking/claw_swipe_f21")
			end),
			FrameEvent(22, function(inst)
				DoArcAttack(inst, 4, 45 + 10, 22.5 + 5, inst.sg.statemem.targets)
			end),
			FrameEvent(23, function(inst)
				DoArcAttack(inst, 4, 45 + 10, -22.5 + 5, inst.sg.statemem.targets)
			end),
			FrameEvent(24, function(inst)
				DoArcAttack(inst, 4, 45 + 10, -67.5 + 5, inst.sg.statemem.targets)
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg.statemem.keep8faced = true
					inst.sg:GoToState("idle")
				end
			end),
		},

		onexit = function(inst)
            inst:ClearBufferedAction()
			if inst.sg.statemem.swipefx and inst.sg.statemem.swipefx:IsValid() then
				inst.sg.statemem.swipefx:Remove()
			end
			if not inst.sg.statemem.keep8faced then
				inst.Transform:SetSixFaced()
			end
		end,
	},

    State{
        name = "hit",
        tags = { "busy", "hit" },

        onenter = function(inst)
            inst.components.locomotor:StopMoving()
            play_shadow_animation(inst, "hit")
        end,

        events =
        {
            EventHandler("animover", function(inst)
                inst.sg:GoToState("idle")
            end),
        },
    },

    State{
        name = "death",
        tags = { "busy" },

        onenter = function(inst)
            if inst.components.locomotor ~= nil then
                inst.components.locomotor:StopMoving()
            end
            inst.AnimState:PlayAnimation("death")
            RemovePhysicsColliders(inst)
            inst.components.lootdropper:DropLoot(inst:GetPosition())
        end,
    },    

}

CommonStates.AddWalkStates(states,
{},{
    startwalk = "walk_pre",
    walk = "walk_loop",
    stopwalk = "walk_pst",
})
CommonStates.AddRunStates(states,
{},{
    startwalk = "walk_pre",
    walk = "walk_loop",
    stopwalk = "walk_pst",
})
CommonStates.AddFrozenStates(states)
CommonStates.AddElectrocuteStates(states)

return StateGraph("crabkingclaw", states, events, "idle", actionhandlers)
