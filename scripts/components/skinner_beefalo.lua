local Skinner_Beefalo = Class(function(self, inst)
	self.inst = inst
	self.clothing = { beef_body = "", beef_horn = "", beef_head = "", beef_feet = "", beef_tail = "", }
end,
nil,
{})

local FACE_SWAP_SYMBOLS = -- NOTES(JBK): Keep this in sync with the skinpuppet_beefalo file. [SBMFF]
{
	"beefalo_beard",
	"beefalo_eye",
	"beefalo_jowls",
	--"beefalo_lip_crease", -- Does not have face data use no build_short for this.
	"beefalo_mouthmouth",
	"beefalo_nose",
	"beffalo_lips",
}
function SetBeefaloFaceSkinsOnAnim(anim_state, clothing_names, linked_beef_guid, build_short)
    if BRANCH ~= "dev" then -- FIXME(JBK): Move out of dev when done.
        return
    end
    local name = clothing_names["beef_head"]
    if BEEFALO_CLOTHING[name] ~= nil then
        local skin_build = GetBuildForItem(name)
        if skin_build ~= "beefalo_head_festive" and skin_build ~= "beefalo_head_robot" then -- FIXME(JBK): Move out of dev when done.
            return
        end
        for _, symbol in ipairs(FACE_SWAP_SYMBOLS) do
            if linked_beef_guid == nil then
                -- nil means we're applying directly to the beefalo
                anim_state:OverrideSkinSymbol(symbol, skin_build, symbol .. build_short)
            else
                --linked_beef_guid means we're applying to a player
                anim_state:OverrideItemSkinSymbol(symbol, skin_build, symbol .. build_short, linked_beef_guid, "beefalo_build")
            end
        end
        if linked_beef_guid == nil then
            -- nil means we're applying directly to the beefalo
            anim_state:OverrideSkinSymbol("beefalo_lip_crease", skin_build, "beefalo_lip_crease")
        else
            --linked_beef_guid means we're applying to a player
            anim_state:OverrideItemSkinSymbol("beefalo_lip_crease", skin_build, "beefalo_lip_crease", linked_beef_guid, "beefalo_build")
        end
    end
end

local clothing_order = { "beef_tail", "beef_body", "beef_feet", "beef_head", "beef_horn" }
function SetBeefaloSkinsOnAnim( anim_state, clothing_names, linked_beef_guid, build_short )
	if linked_beef_guid == nil then
		-- nil means we're applying directly to the beefalo

		-- We need to clear these overrides on the beefalo,
		-- but we don't when we're applying to a player because a player will stomp all symbol overrides when they do ApplyBuildOverrides in beefalo.lua
		for sym,_ in pairs(BEEFALO_CLOTHING_SYMBOLS) do
			anim_state:ClearOverrideSymbol(sym)
		end
	end

	for sym,_ in pairs(BEEFALO_HIDE_SYMBOLS) do
		anim_state:ShowSymbol(sym)
	end

	for _,type in pairs( clothing_order ) do
		local name = clothing_names[type]
		if BEEFALO_CLOTHING[name] ~= nil then
            local skin_build = GetBuildForItem(name)
            if BEEFALO_CLOTHING[name].symbol_overrides then
                for _,sym in pairs(BEEFALO_CLOTHING[name].symbol_overrides) do
                    anim_state:ShowSymbol(sym)

                    if linked_beef_guid == nil then
                        -- nil means we're applying directly to the beefalo
                        anim_state:OverrideSkinSymbol(sym, skin_build, sym )
                    else
                        --linked_beef_guid means we're applying to a player
                        anim_state:OverrideItemSkinSymbol(sym, skin_build, sym, linked_beef_guid, "beefalo_build" )
                    end
                end
            end
			if BEEFALO_CLOTHING[name].symbol_hides then
				for _,sym in pairs(BEEFALO_CLOTHING[name].symbol_hides) do
					anim_state:HideSymbol(sym)
				end
			end
		end
	end
end

function Skinner_Beefalo:SetClothing( name )
	if IsValidBeefaloClothing(name) then
		self.clothing[BEEFALO_CLOTHING[name].type] = name
		self.inst:PushEvent("onclothingchanged",{type=BEEFALO_CLOTHING[name].type, name= name})
		
		self.inst:ApplyBuildOverrides(self.inst.AnimState)
	end
end

function Skinner_Beefalo:GetClothing()
	return {
		beef_body = self.clothing.beef_body,
		beef_horn = self.clothing.beef_horn,
		beef_tail = self.clothing.beef_tail,
		beef_head = self.clothing.beef_head,
		beef_feet = self.clothing.beef_feet,
	}
end

function Skinner_Beefalo:IsClothingDifferent(newclothes)
    newclothes = newclothes or {}
    local oldclothes = self:GetClothing()
    for k, v in pairs(oldclothes) do
        if (newclothes[k] or "") ~= v then
            return true
        end
    end
    for k, v in pairs(newclothes) do
        if (oldclothes[k] or "") ~= v then
            return true
        end
    end
    return false
end

function Skinner_Beefalo:HideAllClothing(anim_state)
	for _,name in pairs(self.clothing) do
		if name ~= nil and name ~= "" and BEEFALO_CLOTHING[name] ~= nil then
			for _,sym in pairs(BEEFALO_CLOTHING[name].symbol_overrides) do
				anim_state:ClearOverrideSymbol(sym)
			end
		end
	end
end

function Skinner_Beefalo:ClearAllClothing()
	for type,_ in pairs(self.clothing) do
		self.clothing[type] = ""
		self.inst:PushEvent("onclothingchanged",{type=type, name= ""})
	end

	self.inst:ApplyBuildOverrides(self.inst.AnimState)
end

function Skinner_Beefalo:ClearClothing(type)
	self.clothing[type] = ""
	self.inst:PushEvent("onclothingchanged",{type=type, name= ""})
end

function Skinner_Beefalo:ApplyTargetSkins(skins,player)
	assert(player)

	local doer_userid = player.userid

	self.inst.AnimState:AssignItemSkins(doer_userid, skins.beef_body or "", skins.beef_feet or "", skins.beef_horn or "", skins.beef_tail or "" , skins.beef_head or "" )

    self:ClearAllClothing()
    self:SetClothing(skins.beef_horn)
    self:SetClothing(skins.beef_body)
    self:SetClothing(skins.beef_head)
    self:SetClothing(skins.beef_feet)
    self:SetClothing(skins.beef_tail)
end

function Skinner_Beefalo:OnSave()
	return {clothing = self.clothing}
end

function Skinner_Beefalo:reloadclothing(clothing)
    --V2C: InGamePlay() is used to check whether world has finished
    --     loading and snapshot player sessions have been restored.
    --     Do not validate inventory when restoring snapshot saves,
    --     because the user is not actually logged in at that time.

    if clothing ~= nil then
        self.clothing = clothing
        for type,name in pairs(self.clothing)do
        	self.inst:PushEvent("onclothingchanged",{type=type, name= name})
        end

        self.inst:ApplyBuildOverrides(self.inst.AnimState)
    end
end

return Skinner_Beefalo
