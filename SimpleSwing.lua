-- SimpleSwing

if not SimpleSwingDB then SimpleSwingDB = {} end

SLASH_SIMPLESWING1 = "/ss"
SLASH_SIMPLESWING2 = "/simpleswing"

SlashCmdList["SIMPLESWING"] = function(msg)
    msg = string.lower(msg or "")

    if msg == "lock" then
        SimpleSwingDB.locked = true
        if SimpleSwingFrame then SimpleSwingFrame:EnableMouse(false) end
        print("SimpleSwing: locked")

    elseif msg == "unlock" then
        SimpleSwingDB.locked = false
        if SimpleSwingFrame then SimpleSwingFrame:EnableMouse(true) end
        print("SimpleSwing: unlocked")

    elseif string.match(msg,"^width") then
        local w = tonumber(string.match(msg, "width (%d+)"))
        if w and SimpleSwingFrame then
            SimpleSwingDB.width = w
            SimpleSwingFrame:SetWidth(w)
            print("SimpleSwing width:", w)
        else
            print("Usage: /ss width <number>")
        end

    elseif string.match(msg,"^height") then
        local h = tonumber(string.match(msg, "height (%d+)"))
        if h and SimpleSwingFrame then
            SimpleSwingDB.height = h
            SimpleSwingFrame:SetHeight(h)
            print("SimpleSwing height:", h)
        else
            print("Usage: /ss height <number>")
        end

    else
        print("/ss lock | unlock | width <n> | height <n>")
    end
end

local SS = CreateFrame("Frame", "SimpleSwingFrame", UIParent)

local defaults = {
    width = 250,
    height = 18,
    locked = false,
    point = "CENTER",
    x = 0,
    y = 0,
}

local function InitDB()
    for k,v in pairs(defaults) do
        if SimpleSwingDB[k] == nil then
            SimpleSwingDB[k] = v
        end
    end
end

SS:SetSize(250,18)

SS.bg = SS:CreateTexture(nil,"BACKGROUND")
SS.bg:SetAllPoints()
SS.bg:SetColorTexture(0,0,0,0.4)

SS.bar = SS:CreateTexture(nil,"ARTWORK")
SS.bar:SetPoint("LEFT",SS,"LEFT")
SS.bar:SetHeight(18)
SS.bar:SetWidth(0)

SS.text = SS:CreateFontString(nil,"OVERLAY","GameFontNormal")
SS.text:SetPoint("CENTER")

SS.timer = 0
SS.timerMax = 2.5
SS.swinging = false

local playerGUID

local function UpdateSpeed()
    local mh = UnitAttackSpeed("player")
    if mh and mh > 0 then SS.timerMax = mh end
end

local function ResetSwing()
    UpdateSpeed()
    SS.timer = SS.timerMax
    SS.swinging = true
end

SS:RegisterEvent("PLAYER_LOGIN")
SS:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
SS:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")

SS:SetScript("OnEvent", function(self,event,...)

    if event == "PLAYER_LOGIN" then
        InitDB()

        SS:ClearAllPoints()
        SS:SetPoint(SimpleSwingDB.point,UIParent,SimpleSwingDB.point,SimpleSwingDB.x,SimpleSwingDB.y)
        SS:SetSize(SimpleSwingDB.width,SimpleSwingDB.height)

        SS:EnableMouse(not SimpleSwingDB.locked)

        playerGUID = UnitGUID("player")
        UpdateSpeed()

        print("SimpleSwing loaded")
        return
    end

    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unit, spellName = ...
        if unit == "player" and spellName == "Slam" then
            ResetSwing()
            return
        end
    end

    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        local _, subevent, sourceGUID,
              _, _, _, destGUID, _, _, missType = ...

        if sourceGUID == playerGUID then
            if subevent == "SWING_DAMAGE" or subevent == "SWING_MISSED" then
                ResetSwing()
                return
            end
        end

        if destGUID == playerGUID and subevent == "SWING_MISSED" and missType == "PARRY" then
            if SS.swinging and SS.timer > 0.3 then
                SS.timer = SS.timer * 0.6
            end
        end
    end
end)

SS:SetScript("OnUpdate", function(self,elapsed)

    if not SS.swinging then
        SS.bar:SetWidth(0)
        SS.bar:SetAlpha(0)
        SS.text:SetText("")
        return
    end

    SS.bar:SetAlpha(1)

    SS.timer = SS.timer - elapsed

    if SS.timer <= 0 then
        SS.timer = 0
        SS.swinging = false
        return
    end

    local remaining = SS.timer / SS.timerMax
    if remaining < 0 then remaining = 0 end
    if remaining > 1 then remaining = 1 end

    if remaining >= 0.85 then
        SS.bar:SetColorTexture(0.0,1.0,0.0,1.0)
    elseif remaining >= 0.50 then
        SS.bar:SetColorTexture(1.0,0.9,0.0,1.0)
    else
        SS.bar:SetColorTexture(1.0,0.0,0.0,1.0)
    end

    local progress = 1 - remaining
    SS.bar:SetWidth(SS:GetWidth() * progress)

    SS.text:SetText(string.format("%.2f",SS.timer))
end)

SS:SetMovable(true)
SS:RegisterForDrag("LeftButton")

SS:SetScript("OnDragStart", function(self)
    if not SimpleSwingDB.locked then self:StartMoving() end
end)

SS:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local p,_,_,x,y = self:GetPoint()
    SimpleSwingDB.point = p
    SimpleSwingDB.x = x
    SimpleSwingDB.y = y
end)
