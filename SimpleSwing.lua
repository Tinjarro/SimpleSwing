-- SimpleSwing PARRY HASTE TEST BUILD
-- Adds basic parry haste handling (approximate)

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
    if not SimpleSwingDB then SimpleSwingDB = {} end
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

        print("SimpleSwing PARRY TEST LOADED")
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
        local timestamp, subevent,
              sourceGUID, sourceName,
              sourceFlags,
              destGUID, destName,
              destFlags,
              missType = ...

        if sourceGUID == playerGUID then
            if subevent == "SWING_DAMAGE" or subevent == "SWING_MISSED" then
                ResetSwing()
                return
            end
        end

        if destGUID == playerGUID and subevent == "SWING_MISSED" and missType == "PARRY" then
            if SS.swinging and SS.timer > 0 then
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

SLASH_SIMPLESWING1 = "/ss"
SlashCmdList["SIMPLESWING"] = function(msg)
    msg = string.lower(msg or "")

    if msg == "lock" then
        SimpleSwingDB.locked = true
        SS:EnableMouse(false)

    elseif msg == "unlock" then
        SimpleSwingDB.locked = false
        SS:EnableMouse(true)

    elseif string.match(msg,"^size") then
        local w,h = string.match(msg,"size (%d+) (%d+)")
        if w and h then
            w = tonumber(w)
            h = tonumber(h)
            SimpleSwingDB.width = w
            SimpleSwingDB.height = h
            SS:SetSize(w,h)
        end
    end
end
