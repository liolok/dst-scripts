require("stategraphs/commonstates")

local WALK_SPEED = 5

local actionhandlers =
{
    ActionHandler(ACTIONS.GOHOME, "land"),
    ActionHandler(ACTIONS.POLLINATE, function(inst)
		if inst.sg:HasStateTag("landed") then
			return "pollinate"
		else
			return "land"
		end
    end),
}

local events=
{
    EventHandler("locomote", function(inst)
        if not inst.sg:HasStateTag("busy") then
			local is_moving = inst.sg:HasStateTag("moving")
			local wants_to_move = inst.components.locomotor:WantsToMoveForward()
			if is_moving ~= wants_to_move then
				if wants_to_move then
					inst.sg.statemem.wantstomove = true
				else
					inst.sg:GoToState("idle")
				end
			end
        end
    end),
    EventHandler("death", function(inst) inst.sg:GoToState("death") end),
    CommonHandlers.OnFreeze(),
	CommonHandlers.OnElectrocute(),
}

local states=
{

    State{
        name = "moving",
        tags = {"moving", "canrotate"},

        onenter = function(inst)
			inst.components.locomotor:WalkForward()
            inst.AnimState:PlayAnimation("flight_cycle", true)
        end,
    },

    State{
        name = "death",
        tags = {"busy"},

        onenter = function(inst)
            inst.AnimState:PlayAnimation("death")
            inst.Physics:Stop()
            RemovePhysicsColliders(inst)
            inst.components.lootdropper:DropLoot(Vector3(inst.Transform:GetWorldPosition()))
        end,

        timeline =
        {
            TimeEvent(10 * FRAMES, LandFlyingCreature),
        },
    },
    State{
        name = "idle",
        tags = {"idle"},

        onenter = function(inst)
            inst.Physics:Stop()
            if not inst.AnimState:IsCurrentAnimation("idle_flight_loop") then
                inst.AnimState:PlayAnimation("idle_flight_loop", true)
            end
            inst.sg:SetTimeout( inst.AnimState:GetCurrentAnimationLength() )
        end,

        ontimeout = function(inst)
            if inst.sg.statemem.wantstomove then
                inst.sg:GoToState("moving")
            else
                inst.sg:GoToState("idle")
            end
        end,
    },

    State{
        name = "land",
        tags = {"busy", "landing"},

        onenter = function(inst)
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("land")
            LandFlyingCreature(inst)
        end,

        events=
        {
            EventHandler("animover", function(inst)
                if inst.bufferedaction and inst.bufferedaction.action == ACTIONS.POLLINATE then
					inst.sg:GoToState("pollinate")
				elseif inst.bufferedaction and inst.bufferedaction.action == ACTIONS.GOHOME then
					inst:Remove()
				else
					inst.sg:GoToState("land_idle")
				end
            end),
        },

        onexit = RaiseFlyingCreature,
    },

    State{
        name = "land_idle",
        tags = {"busy", "landed"},

        onenter = function(inst)
            inst.AnimState:PushAnimation("idle", true)
            LandFlyingCreature(inst)
        end,

        onexit = RaiseFlyingCreature,
    },

    State{
        name = "pollinate",
        tags = {"busy", "landed"},

        onenter = function(inst)
            inst.AnimState:PushAnimation("idle", true)
            inst:PerformBufferedAction()
            inst.sg:SetTimeout(GetRandomWithVariance(3, 1) )
            LandFlyingCreature(inst)
        end,

        ontimeout = function(inst)
            inst.sg:GoToState("takeoff")
        end,

        onexit = RaiseFlyingCreature,
    },

    State{
        name = "takeoff",
        tags = {"busy"},

        onenter = function(inst)
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("take_off")
        end,

        events =
        {
            EventHandler("animover", function(inst) inst.sg:GoToState("idle") end),
        },
    },
}
CommonStates.AddFrozenStates(states, LandFlyingCreature, RaiseFlyingCreature)
CommonStates.AddElectrocuteStates(states)

return StateGraph("butterfly", states, events, "takeoff", actionhandlers)
