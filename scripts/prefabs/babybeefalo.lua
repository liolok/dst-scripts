local assets =
{
    Asset("ANIM", "anim/beefalo_basic.zip"),
    Asset("ANIM", "anim/beefalo_actions.zip"),
    Asset("ANIM", "anim/beefalo_baby_build.zip"),
    Asset("SOUND", "sound/beefalo.fsb"),
}

local prefabs =
{
    "smallmeat",
    "meat",
    "poop",
    "beefalowool",
    "beefalo",
}

local babyloot = {"smallmeat","smallmeat","smallmeat","beefalowool"}
local toddlerloot = {"smallmeat","smallmeat","smallmeat","smallmeat","beefalowool","beefalowool"}
local teenloot = {"meat","meat","meat","beefalowool","beefalowool"}

local sounds =
{
    walk = "dontstarve/creatures/beefalo_baby/walk",
    grunt = "dontstarve/creatures/beefalo_baby/grunt",
    yell = "dontstarve/creatures/beefalo_baby/yell",
    swish = "dontstarve/creatures/beefalo_baby/tail_swish",
    curious = "dontstarve/creatures/beefalo_baby/curious",
    angry = "dontstarve/creatures/beefalo_baby/angry",
    sleep = "dontstarve/creatures/beefalo_baby/sleep",
}

local brain = require "brains/babybeefalobrain"

local function OnAttacked(inst, data)
    inst.components.combat:SetTarget(data.attacker)
    inst.components.combat:ShareTarget(data.attacker, 30, function(dude)
        return dude:HasTag("beefalo") and not dude:HasTag("player") and not dude.components.health:IsDead()
    end, 5)
end

local FOLLOW_MUST_TAGS = {"beefalo", "herdmember"}
local FOLLOW_CANT_TAGS = {"baby"}
local function FollowGrownBeefalo(inst)
    local nearest = FindEntity(inst, 30, function(guy)
        return guy.components.leader
            and guy.components.leader:CountFollowers() < 1
    end,
    FOLLOW_MUST_TAGS, -- only follow herd beefalo (i.e. nondomesticated)
    FOLLOW_CANT_TAGS
    )
    if nearest and nearest.components.leader then
        nearest.components.leader:AddFollower(inst)
    end
end

local function Grow(inst)
    if inst.components.sleeper:IsAsleep() then
        inst.growUpPending = true
        inst.sg:GoToState("wake")
    else
        inst.sg:GoToState("grow_up")
    end
end

local function GetGrowTime()
    return GetRandomWithVariance(TUNING.BABYBEEFALO_GROW_TIME.base, TUNING.BABYBEEFALO_GROW_TIME.random)
end

local function SetBaby(inst)
    local scale = 0.5
    inst.Transform:SetScale(scale, scale, scale)
    inst.components.lootdropper:SetLoot(babyloot)
    inst.components.sleeper:SetResistance(1)
end

local function SetToddler(inst)
    local scale = 0.7
    inst.Transform:SetScale(scale, scale, scale)
    inst.components.lootdropper:SetLoot(toddlerloot)
    inst.components.sleeper:SetResistance(2)
end

local function SetTeen(inst)
    local scale = 0.9
    inst.Transform:SetScale(scale, scale, scale)
    inst.components.lootdropper:SetLoot(teenloot)
    inst.components.sleeper:SetResistance(2)
end

local function SetFullyGrown(inst)
    local herd = inst.components.herdmember ~= nil and inst.components.herdmember:GetHerd() or nil
    local grown = SpawnPrefab("beefalo")
    grown.Transform:SetPosition(inst.Transform:GetWorldPosition())
    grown.Transform:SetRotation(inst.Transform:GetRotation())
    grown.sg:GoToState("grow_up_pop")
    inst:Remove()
    if herd ~= nil and herd.components.herd ~= nil and herd:IsValid() then
        herd.components.herd:AddMember(grown)
    end
end

local growth_stages =
{
    {name="baby", time = GetGrowTime, fn = SetBaby},
    {name="toddler", time = GetGrowTime, fn = SetToddler, growfn = Grow},
    {name="teen", time = GetGrowTime, fn = SetTeen, growfn = Grow},
    {name="grown", time = GetGrowTime, fn = SetFullyGrown, growfn = Grow},
}

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddDynamicShadow()
    inst.entity:AddNetwork()

    inst.Transform:SetSixFaced()
    inst.Transform:SetScale(0.5, 0.5, 0.5)

    inst.DynamicShadow:SetSize(2.5, 1.25)

    inst.AnimState:SetBank("beefalo")
    inst.AnimState:SetBuild("beefalo_baby_build")
    inst.AnimState:PlayAnimation("idle_loop", true)

    inst:AddTag("beefalo")
    inst:AddTag("baby")
    inst:AddTag("animal")

    --herdmember (from herdmember component) added to pristine state for optimization
    inst:AddTag("herdmember")

    MakeCharacterPhysics(inst, 100, .75)

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst.sounds = sounds

    inst:AddComponent("eater")
    inst.components.eater:SetDiet({ FOODTYPE.VEGGIE }, { FOODTYPE.VEGGIE })

    inst:AddComponent("combat")
    inst.components.combat.hiteffectsymbol = "beefalo_body"

    inst:AddComponent("health")
    inst.components.health:SetMaxHealth(TUNING.BABYBEEFALO_HEALTH)

    inst:AddComponent("lootdropper")

    inst:AddComponent("inspectable")
    inst:AddComponent("sleeper")

    inst:AddComponent("knownlocations")
    inst:AddComponent("herdmember")
    inst:AddComponent("follower")
    inst.components.follower.canaccepttarget = true

    inst:AddComponent("periodicspawner")
    inst.components.periodicspawner:SetPrefab("poop")
    inst.components.periodicspawner:SetRandomTimes(80, 110)
    inst.components.periodicspawner:SetDensityInRange(20, 2)
    inst.components.periodicspawner:SetMinimumSpacing(8)
    inst.components.periodicspawner:Start()

    inst:AddComponent("growable")
    inst.components.growable.stages = growth_stages
    inst.components.growable.growonly = true
    inst.components.growable:SetStage(1)
    inst.components.growable:StartGrowing()

    inst:AddComponent("drownable")

    MakeMediumBurnableCharacter(inst, "beefalo_body")
    MakeMediumFreezableCharacter(inst, "beefalo_body")

    inst:AddComponent("locomotor") -- locomotor must be constructed before the stategraph
    inst.components.locomotor.walkspeed = 2
    inst.components.locomotor.runspeed = 9

    MakeHauntablePanic(inst)

    inst:DoTaskInTime(1, FollowGrownBeefalo)

    inst:SetBrain(brain)

    inst:SetStateGraph("SGBeefalo")

    inst:ListenForEvent("attacked", OnAttacked)

    return inst
end

return Prefab("babybeefalo", fn, assets, prefabs)
