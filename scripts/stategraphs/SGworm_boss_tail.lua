require("stategraphs/commonstates")
local WORMBOSS_UTILS = require("prefabs/worm_boss_util")

local events=
{
    --CommonHandlers.OnLocomote(false, true),
    --CommonHandlers.OnAttack(),
    --CommonHandlers.OnAttacked(),
    --CommonHandlers.OnDeath(),
    --CommonHandlers.OnSleepEx(),

    EventHandler("spit", function(inst)
        inst.sg:GoToState("spit")
    end),

    EventHandler("death", function(inst)
        if not inst.sg:HasStateTag("dead") then
            inst.sg:GoToState("death")
        end
    end),

    EventHandler("attacked", function(inst)
        if not inst.sg:HasStateTag("busy") then
            inst.sg:GoToState("hit")
        end
    end),

	EventHandler("sync_electrocute", function(inst, data)
		if not inst.sg:HasStateTag("busy") or (inst.sg:HasStateTag("hit") and not inst.sg:HasStateTag("electrocute")) then
			inst.sg:GoToState("sync_electrocute", data)
		end
	end),
}

local states =
{
    State{

        name = "idle_pre",
        tags = {"idle", "canrotate", "busy"},
        onenter = function(inst, playanim)
            inst.AnimState:PlayAnimation("tail_idle_pre")
        end,

        events=
        {
            EventHandler("animover", function(inst) inst.sg:GoToState("idle") end),
        },
    },

    State{

        name = "idle",
        tags = {"idle", "canrotate"},
        onenter = function(inst, playanim)
            inst.AnimState:PlayAnimation("tail_idle_loop")
        end,

        events=
        {
            EventHandler("animover", function(inst) inst.sg:GoToState("idle") end),
        },
    },

    State{

        name = "spit",
        tags = {"canrotate", "busy"},
        onenter = function(inst, playanim)
            inst.AnimState:PlayAnimation("tail_spit")
            inst.SoundEmitter:PlaySound("rifts4/worm_boss/spit_butt")
        end,

        onexit = function(inst)
            if inst.worm.devoured then
                WORMBOSS_UTILS.SpitAll(inst.worm)
            end
        end,

        timeline =
        {
            TimeEvent(14*FRAMES, function(inst) WORMBOSS_UTILS.SpitAll(inst.worm) end ),
        },

        events=
        {
            EventHandler("animover", function(inst) inst.sg:GoToState("idle") end),
        },
    },

    State{

        name = "hit",
        tags = {"canrotate", "busy"},

        onenter = function(inst, playanim)
            inst.AnimState:PlayAnimation("tail_hit")
        end,

        events=
        {
            EventHandler("animover", function(inst) inst.sg:GoToState("idle") end),
        },
    },

	State{
		name = "sync_electrocute",
		tags = { "electrocute", "hit", "busy", "noelectrocute" },

		onenter = function(inst, data)
			inst.AnimState:PlayAnimation("tail_shock_loop", true)
			inst.sg:SetTimeout(CalcEntityElectrocuteDuration(inst, data and data.duration))
		end,

		ontimeout = function(inst)
			inst.AnimState:PlayAnimation("tail_shock_pst")
		end,

		events =
		{
			EventHandler("animqueueover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg:GoToState("idle")
				end
			end),
		},
	},

    State{

        name = "death",
        tags = {"dead", "canrotate", "busy"},
        onenter = function(inst, playanim)
            inst.AnimState:PlayAnimation("tail_idle_pst")
            inst.dirt:dirt_playanimation("dirt_move")
        end,

        events=
        {
            EventHandler("animover", function(inst)
                inst.dirt:dirt_playanimation("dirt_pst_slow")
                inst.dirt:AddTag("notarget")
                inst.worm.tail = nil
                inst:Remove()
            end),
        },
    },
}

return StateGraph("worm_boss_tail", states, events, "idle")
