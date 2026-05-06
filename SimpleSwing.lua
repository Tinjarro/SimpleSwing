-- SimpleSwing (Stable MH/OH classification, no debug)

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
            print("Width:", w)
        end

    elseif string.match(msg,"^height") then
        local h = tonumber(string.match(msg, "height (%d+)"))
        if h and SimpleSwingFrame then
            SimpleSwingDB.height = h
            SimpleSwingFrame:SetHeight(h)
            print("Height:", h)
        end

    elseif string.match(msg,"^ms") then
        local ms = tonumber(string.match(msg, "ms (%d+)"))
        if ms then
            SimpleSwingDB.ms = ms
            print("Latency:", ms, "ms")
        end

    elseif string.match(msg,"^react") then
        local r = tonumber(string.match(msg, "react (%d+)"))
        if r then
            SimpleSwingDB.react = r
            print("Reaction:", r, "ms")
        end

    elseif msg == "color on" then
        SimpleSwingDB.colors = true
        print("Colors: ON")

    elseif msg == "color off" then
        SimpleSwingDB.colors = false
        print("Colors: OFF")

    else
        print("/ss lock | unlock | width <n> | height <n> | ms <latency> | react <ms> | color on/off")
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
    ms = 0,
    react = 0,
    colors = true,
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

-- classification state
local lastMH = 0
local lastOH = 0
local lastWasMH = true
local seenFirst = false

local prevMHSpeed = 0
local prevOHSpeed = 0

local function UpdateSpeed()
    local mh, oh = UnitAttackSpeed("player")
    if mh and mh > 0 then SS.timerMax = mh end
    return mh or 0, oh or 0
end

local function ResetModel()
    lastMH = 0
    lastOH = 0
    lastWasMH = true
    seenFirst = false
end

local function ResetMH()
    UpdateSpeed()
    SS.timer = SS.timerMax
    SS.swinging = true
    lastMH = GetTime()
    lastWasMH = true
end

local function MarkOH()
    lastOH = GetTime()
    lastWasMH = false
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
        local mh, oh = UpdateSpeed()
        prevMHSpeed, prevOHSpeed = mh, oh

        print("SimpleSwing loaded")
        return
    end

    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unit, spellName = ...
        if unit == "player" and spellName == "Slam" then
            seenFirst = true
            ResetMH()
            return
        end
    end

    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        local _, subevent, sourceGUID,
              _, _, _, destGUID, _, _, missType = ...

        if sourceGUID == playerGUID and (subevent == "SWING_DAMAGE" or subevent == "SWING_MISSED") then

            local now = GetTime()
            local mh, oh = UpdateSpeed()

            -- detect weapon swap (speed change)
            if mh ~= prevMHSpeed or oh ~= prevOHSpeed then
                ResetModel()
                prevMHSpeed, prevOHSpeed = mh, oh
            end

            -- no offhand
            if not oh or oh <= 0 then
                ResetMH()
                return
            end

            -- first swing
            if not seenFirst or lastMH == 0 then
                seenFirst = true
                ResetMH()
                return
            end

            local dMH = now - lastMH
            local dOH = lastOH > 0 and (now - lastOH) or 999

            -- EARLY window: force OH
            if dMH < (mh * 0.45) then
                MarkOH()
                return
            end

            local mhDiff = math.abs(dMH - mh)
            local ohDiff = math.abs(dOH - oh)

            -- BIAS: alternate hands unless clearly wrong
            if lastWasMH then
                if ohDiff < (mhDiff * 1.25) then
                    MarkOH()
                else
                    ResetMH()
                end
            else
                if mhDiff < (ohDiff * 1.25) then
                    ResetMH()
                else
                    MarkOH()
                end
            end

            return
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

    local latency = (SimpleSwingDB.ms or 0) / 1000
    local reaction = (SimpleSwingDB.react or 0) / 1000
    local totalOffset = latency + reaction
    local offsetPercent = totalOffset / SS.timerMax

    if not SimpleSwingDB.colors then
        SS.bar:SetColorTexture(0.2,0.6,1.0,0.8)
    else
        if remaining > 0.85 then
            SS.bar:SetColorTexture(0.0,1.0,0.0,1.0)
        elseif remaining > 0.50 then
            SS.bar:SetColorTexture(1.0,0.9,0.0,1.0)
        elseif remaining > offsetPercent then
            SS.bar:SetColorTexture(1.0,0.0,0.0,1.0)
        else
            SS.bar:SetColorTexture(0.0,1.0,0.0,1.0)
        end
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
