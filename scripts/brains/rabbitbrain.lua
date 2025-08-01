require "behaviours/wander"
require "behaviours/runaway"
require "behaviours/doaction"
local BrainCommon = require("brains/braincommon")

local STOP_RUN_DIST = 10
local SEE_PLAYER_DIST = 5

local AVOID_PLAYER_DIST = 3
local AVOID_PLAYER_STOP = 6

local SEE_BAIT_DIST = 20
local MAX_WANDER_DIST = 20
local FINDFOOD_CANT_TAGS = { "INLIMBO", "outofreach" }

local RabbitBrain = Class(Brain, function(self, inst)
    Brain._ctor(self, inst)
end)

local function GoHomeAction(inst)
    if inst.components.homeseeker and
       inst.components.homeseeker.home and
       inst.components.homeseeker.home:IsValid() and
	   inst.sg:HasStateTag("trapped") == false then
        return BufferedAction(inst, inst.components.homeseeker.home, ACTIONS.GOHOME)
    end
end

local function EatFoodAction(inst)

    local target = FindEntity(inst, SEE_BAIT_DIST, function(item, i)
            return i.components.eater:CanEat(item) and
                item.components.bait and
                not item:HasTag("planted") and
                item:IsOnPassablePoint() and
                item:GetCurrentPlatform() == i:GetCurrentPlatform()
		end,
		nil,
		FINDFOOD_CANT_TAGS)
    if target then
        local act = BufferedAction(inst, target, ACTIONS.EAT)
        act.validfn = function() return not (target.components.inventoryitem and target.components.inventoryitem:IsHeld()) end
        return act
    end
end

local HunterParams = {
    tags = {"scarytoprey"},
    notags = {"INLIMBO", "NOCLICK", "rabbitdisguise"},
}
function RabbitBrain:OnStart()
    local root = PriorityNode(
    {
		BrainCommon.PanicTrigger(self.inst),
        BrainCommon.ElectricFencePanicTrigger(self.inst),
        RunAway(self.inst, HunterParams, AVOID_PLAYER_DIST, AVOID_PLAYER_STOP),
        RunAway(self.inst, HunterParams, SEE_PLAYER_DIST, STOP_RUN_DIST, nil, true),
        EventNode(self.inst, "gohome",
            DoAction(self.inst, GoHomeAction, "go home", true )),
        WhileNode(function() return not TheWorld.state.isday end, "IsNight",
            DoAction(self.inst, GoHomeAction, "go home", true )),
        WhileNode(function() return TheWorld.state.isspring end, "IsSpring",
            DoAction(self.inst, GoHomeAction, "go home", true )),
        DoAction(self.inst, EatFoodAction),
        Wander(self.inst, function() return self.inst.components.knownlocations:GetLocation("home") end, MAX_WANDER_DIST)
    }, .25)
    self.bt = BT(self.inst, root)
end

return RabbitBrain
