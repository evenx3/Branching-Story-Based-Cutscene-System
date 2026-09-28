-- This is the reusable QTE part of my minigame service.
-- I wanted scene data to be able to say "W, 1.5 seconds, right side" and not
-- have a whole new input script copied into every cutscene.

local minigameService = {}
local tweenService = game:GetService("TweenService")
local userInputService = game:GetService("UserInputService")
local modules = script.Parent
local audioService = require(modules.AudioService)
local UI = modules.Parent.UI
local QTE = UI.QTE
local defaultQTEPosition = QTE.Position

function minigameService.getKey(key)
    -- The scene tables use readable strings. This is the boring conversion layer
    -- I only want to write once.
    if key == "W" then
        return Enum.KeyCode.W
    elseif key == "A" then
        return Enum.KeyCode.A
    elseif key == "S" then
        return Enum.KeyCode.S
    elseif key == "D" then
        return Enum.KeyCode.D
    end

    return key
end

-- Same idea here: the scene can say "Right" instead of storing a random UDim2
-- everywhere. I can still pass a real UDim2 when I need something custom.
local qtePositionPresets = {
    Right = UDim2.new(0.75, 0, 0.5, 0),
    Left = UDim2.new(0.25, 0, 0.5, 0),
    Top = UDim2.new(0.5, 0, 0.25, 0),
    Bottom = UDim2.new(0.5, 0, 0.75, 0),
    Middle = UDim2.new(0.5, 0, 0.5, 0),
}

function minigameService.resolveQTEPosition(position)
    if typeof(position) == "UDim2" then
        return position
    end

    if type(position) == "string" then
        local preset = qtePositionPresets[position]
        if preset then
            return preset
        end
        warn("Unknown QTE position preset: " .. position)
    end

    return nil
end

function minigameService.startQTE(text, duration, position)
    position = minigameService.resolveQTEPosition(position) or defaultQTEPosition

    local result = nil
    local finished = false
    local key = minigameService.getKey(text)

    -- Shorter QTEs get a slightly faster/higher-pitched sound so they feel more urgent.
    local pitch = math.clamp(1.7 / duration - 0.1, 0.9, 1.25)

    QTE.TextColor3 = Color3.fromRGB(0, 0, 0)
    QTE.Position = position
    QTE.Text = text
    QTE.Visible = true
    audioService.playSound("QTE", nil, pitch)
    audioService.playSound("Tick", nil, pitch)

    local connection
    connection = userInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed or finished then
            return
        end

        finished = true

        if input.KeyCode == key then
            -- Green = yay
            tweenService:Create(QTE, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                TextColor3 = Color3.fromRGB(23, 226, 0),
            }):Play()
            audioService.playSound("QTEHit")
            result = true
        else
            -- Wrong key counts as a fail instead of waiting for the timer.
            tweenService:Create(QTE, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                TextColor3 = Color3.fromRGB(197, 0, 0),
            }):Play()
            audioService.playSound("QTEFail")
            audioService.playSound("QTEFail2")
            result = false
        end

        connection:Disconnect()
    end)

    task.wait(duration)

    -- No input before the timer ends = fail.
    if not finished then
        tweenService:Create(QTE, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            TextColor3 = Color3.fromRGB(197, 0, 0),
        }):Play()
        audioService.playSound("QTEFail")
        audioService.playSound("QTEFail2")
        finished = true
        result = false
        connection:Disconnect()
    end

    QTE.Visible = false
    return result
end

return minigameService
