-- This is the server-side lookup for important choice results.
-- I like doing it this way because "JennaScold" is way easier for me to follow
-- later than a giant if/elseif chain spread across different scripts.

local serverStorage = game:GetService("ServerStorage")
local storyData = serverStorage.StoryData
local relationships = storyData.Relationships

local choiceHandler = {
    ["JennaJoke"] = function(characterName, player)
        -- The choice can change both a relationship number AND a named story flag.
        -- Future scenes only need to look up JennaJoke; they don't care how we got here.
        local relationship = relationships:GetAttribute("Jenna/Fernando") or 0
        relationships:SetAttribute("Jenna/Fernando", relationship + 1)
        storyData:SetAttribute("JennaJoke", true)
    end,

    ["JennaScold"] = function(characterName, player)
        local relationship = relationships:GetAttribute("Jenna/Fernando") or 0
        relationships:SetAttribute("Jenna/Fernando", relationship - 1)
        storyData:SetAttribute("JennaScold", true)
    end,

    ["Quiet"] = function(characterName, player)
        -- "Quiet" is still a real named result, it just intentionally does nothing.
        -- I prefer that over using nil because it's obvious this outcome was planned.
    end,
}

return choiceHandler
