-- Local/client side of my choice system.
-- The scene table only has to give me the choice text + named results.
-- This file deals with the UI/timer stuff so I don't have to repeat it in scenes.

local choiceService = {}
local tweenService = game:GetService("TweenService")
local modules = script.Parent
local UI = modules.Parent.UI
local audioService = require(modules.AudioService)

local choiceTextOne = UI.ChoiceTextOne
local choiceTextTwo = UI.ChoiceTextTwo
local choiceButtonOne = UI.ChoiceButtonOne
local choiceButtonTwo = UI.ChoiceButtonTwo
local countdownText = UI.Countdown
local waitText = UI.WaitText
local butterflyImage = UI.Butterfly
local butterflyEffect = UI.ButterflyEffect
local butterflyEffectGuide = UI.ButterflyEffectGuide
local popup = UI.Popup

function choiceService.butterflyEffect(effectType, text)
    -- I use this for the Telltale-ish "that mattered" feedback.
    -- The choice itself is already saved elsewhere; this is just presentation.
    task.spawn(function()
        if effectType == "Start" then
            butterflyEffect.Text = "BUTTERFLY EFFECT"
            butterflyEffectGuide.Text = "This choice may have consequences..."
        elseif effectType == "Update" then
            butterflyEffect.Text = "BUTTERFLY EFFECT UPDATED"
            butterflyEffectGuide.Text = "This choice may have consequences..."
        elseif effectType == "Realized" then
            butterflyEffect.Text = "BUTTERFLY EFFECT REALIZED"
            butterflyEffectGuide.Text = text
            audioService.playSound("ButterflyRealized")
        end

        -- Reset everything invisible first, then fade it in together.
        butterflyImage.ImageTransparency = 1
        butterflyEffect.TextTransparency = 1
        butterflyEffectGuide.TextTransparency = 1
        butterflyEffect.Visible = true
        butterflyEffectGuide.Visible = true
        butterflyImage.Visible = true

        tweenService:Create(butterflyEffectGuide, TweenInfo.new(0.5), { TextTransparency = 0 }):Play()
        tweenService:Create(butterflyEffect, TweenInfo.new(0.5), { TextTransparency = 0 }):Play()
        tweenService:Create(butterflyImage, TweenInfo.new(0.5), { ImageTransparency = 0 }):Play()
        audioService.playSound("ButterflyEffect")
        audioService.playSound("ButterflyFlap")

        task.wait(2)

        audioService.playSound("ButterflyFade")
        tweenService:Create(butterflyEffectGuide, TweenInfo.new(2), { TextTransparency = 1 }):Play()
        tweenService:Create(butterflyEffect, TweenInfo.new(2), { TextTransparency = 1 }):Play()
        tweenService:Create(butterflyImage, TweenInfo.new(2), { ImageTransparency = 1 }):Play()
    end)
end

local countdownActive = false
function choiceService.choiceCountdown(duration)
    -- Kept separate from promptChoice because I reuse the timer visuals.
    task.spawn(function()
        local startTime = tick()
        countdownActive = true
        countdownText.Text = duration
        countdownText.TextTransparency = 0
        countdownText.Visible = true

        while countdownActive do
            local remaining = math.ceil(duration - (tick() - startTime))

            if remaining <= 0 then
                countdownText.Text = "0"
                countdownActive = false
                break
            end

            countdownText.Text = tostring(remaining)
            task.wait()
        end

        local textTween = tweenService:Create(countdownText, TweenInfo.new(0.5), {
            TextTransparency = 1,
        })
        textTween:Play()
        textTween.Completed:Wait()
        countdownText.Visible = false
    end)
end

function choiceService.waitForDecision(player)
    -- Multiplayer thing: if Jenna is choosing, everyone else gets this instead
    -- of also getting clickable choice buttons.
    task.spawn(function()
        waitText.TextTransparency = 1
        waitText.Text = "Waiting for " .. player .. " to make a choice..."
        waitText.Visible = true
        tweenService:Create(waitText, TweenInfo.new(0.5), { TextTransparency = 0 }):Play()
        audioService.playSound("ChoicePrompt")
    end)
end

function choiceService.disableWaitScreen()
    task.spawn(function()
        audioService.playSound("ChoiceSelect")
        audioService.playSound("Reverse")

        local textTween = tweenService:Create(waitText, TweenInfo.new(0.5), {
            TextTransparency = 1,
        })
        textTween:Play()
        textTween.Completed:Wait()
        waitText.Visible = false
    end)
end

function choiceService.promptChoice(character, choice1Text, choice2Text, choice1Id, choice2Id, choice3Id, involvedCharacters, duration)
    local choice1 = nil
    local choice2 = nil
    local choiceMade = nil
    duration = duration or 8

    local startTime = tick()
    local characterData = character:FindFirstChild("CharacterData")

    -- The full version also has hover code here that moves the buttons and makes
    -- the choosing character look toward whichever option you're hovering.
    -- I left that chunk out because it is mostly UI polish, not the main system.

    choiceTextOne.Text = choice1Text
    choiceTextTwo.Text = choice2Text
    choiceButtonOne.Visible = true
    choiceButtonTwo.Visible = true
    choiceTextOne.Visible = true
    choiceTextTwo.Visible = true

    audioService.playSound("ChoicePrompt")
    choiceService.choiceCountdown(duration)

    choice1 = choiceButtonOne.MouseButton1Click:Connect(function()
        countdownActive = false
        choice1:Disconnect()
        choiceMade = choice1Id
        audioService.playSound("ChoiceSelect")
    end)

    choice2 = choiceButtonTwo.MouseButton1Click:Connect(function()
        countdownActive = false
        choice2:Disconnect()
        choiceMade = choice2Id
        audioService.playSound("ChoiceSelect")
    end)

    -- Wait until the player clicks something OR the scene's timer runs out.
    repeat
        task.wait()
    until choiceMade or tick() - startTime >= duration

    if not choiceMade then
        -- choice3Id is my timeout/default result (usually something like "Quiet").
        countdownActive = false
        choiceMade = choice3Id
        audioService.playSound("ChoiceSelect")
    end

    choiceButtonOne.Visible = false
    choiceButtonTwo.Visible = false
    choiceTextOne.Visible = false
    choiceTextTwo.Visible = false
    audioService.playSound("Reverse")

    if characterData then
        characterData:SetAttribute("EyeExpression", "None")
    end

    -- The important thing coming out of this service is just a recognizable name.
    -- Example: "JennaScold". The server decides what that name actually changes.
    return choiceMade
end

function choiceService.popup(popupType, characterName1, characterName2)
    -- Another dictionary-ish pattern: the scene just gives me a PopupType and
    -- character names instead of writing a custom UI message every time.
    task.spawn(function()
        if popupType == "Amused" then
            popup.Text = characterName1 .. " is amused by " .. characterName2 .. "'s remark."
        elseif popupType == "Annoyed" then
            popup.Text = characterName1 .. " is annoyed by " .. characterName2 .. "'s remark."
        elseif popupType == "Ignored" then
            popup.Text = characterName1 .. " ignored " .. characterName2 .. "'s warning."
        elseif popupType == "Distrust" then
            popup.Text = characterName1 .. " is beginning to distrust " .. characterName2 .. "."
        elseif popupType == "Appreciate" then
            popup.Text = characterName1 .. " appreciated " .. characterName2 .. "'s remark."
        end

        popup.TextTransparency = 1
        popup.Visible = true
        tweenService:Create(popup, TweenInfo.new(0.5), { TextTransparency = 0 }):Play()
        audioService.playSound("Remember")

        task.wait(2)

        tweenService:Create(popup, TweenInfo.new(2), { TextTransparency = 1 }):Play()
        task.wait(2)
        popup.Visible = false
    end)
end

return choiceService
