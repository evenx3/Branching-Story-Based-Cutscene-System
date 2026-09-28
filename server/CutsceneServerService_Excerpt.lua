-- A couple server-side pieces from the cutscene system.
-- The client handles most of the presentation, but the server decides things that
-- should be shared / authoritative, like who is in a scene and determinant roles.

local cutsceneServerService = {}
local replicatedStorage = game:GetService("ReplicatedStorage")
local players = game:GetService("Players")
local serverToClientEvents = replicatedStorage.Events.ServerToClient
local statusHandler = require(script.Parent.StatusHandler)

function cutsceneServerService.firePlayersWithCharacterNames(characterNames, eventName, ...)
    local args = { ... }

    -- A multiplayer scene does not always involve everybody in the server.
    -- I look at the character name attached to each player and only fire the
    -- cutscene for the characters listed by the scene.
    for _, player in pairs(players:GetPlayers()) do
        local character = player.Character
        if character then
            local characterData = character:FindFirstChild("CharacterData")
            if characterData then
                local characterName = characterData:GetAttribute("CharacterName")

                for _, targetName in ipairs(characterNames) do
                    if characterName == targetName then
                        statusHandler.setCutscene(player, true)
                        serverToClientEvents.Cutscene:FireClient(player, table.unpack(args))
                        break
                    end
                end
            end
        end
    end
end

function cutsceneServerService.shuffleAssignDeterminants(pool, startIndex)
    startIndex = startIndex or 1

    -- Clone the pool because I want to remove picked characters without messing
    -- with the original list that another system might still need.
    local remaining = table.clone(pool)
    local assignments = {}

    -- The final dictionary is intentionally named like:
    -- Determinant1 = "Evan", Determinant2 = "Haley", etc.
    -- Then the client can just use a normal lookup when it loads the scene.
    for i = startIndex, startIndex + #pool - 1 do
        local index = math.random(1, #remaining)
        local name = remaining[index]
        table.remove(remaining, index)
        assignments["Determinant" .. i] = name
    end

    return assignments
end

return cutsceneServerService
