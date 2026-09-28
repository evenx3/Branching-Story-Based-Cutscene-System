-- This is the main "big backend" behind my cutscenes.
-- It is intentionally more complicated than the scene-data files because my whole
-- goal was: deal with the ugly stuff here ONCE, then keep new cutscenes readable.
--
-- This is still an excerpt. The full service also has the movement tween helpers,
-- expression setters, prop attachment, subtitle details, cleanup, fades, etc.

local cutsceneService = {}
local player = game.Players.LocalPlayer
local replicatedStorage = game:GetService("ReplicatedStorage")
local animationsFolder = replicatedStorage:WaitForChild("Animations")
local clientToServerEvents = replicatedStorage.Events.ClientToServer
local serverToClientEvents = replicatedStorage.Events.ServerToClient
local modules = script.Parent
local assetPreloadService = require(modules.AssetPreloadService)
local choiceService = require(modules.ChoiceService)
local minigameService = require(modules.MinigameService)

-- I cache animations by NAME because that matches how I like authoring scene tables.
-- Scene data can say WalkCarefree = "WalkCarefree" and I can find it fast here.
local animationCache = {}
for _, animation in ipairs(animationsFolder:GetDescendants()) do
    if animation:IsA("Animation") then
        animationCache[animation.Name] = animation
    end
end

-- The full service keeps track of whatever scene is currently loaded so different
-- event handlers can get back to the same characters / scene folder.
local currentScene = {}

-- ============================================================================
-- DETERMINANTS
-- ============================================================================

function cutsceneService.applyDeterminants(characterTable, determinantLogic, determinantAssignments)
    if not determinantLogic or not determinantAssignments then
        return
    end

    -- determinantAssignments looks like:
    -- Determinant1 = "Evan"
    -- Determinant2 = "Haley"
    --
    -- The scene was authored around Determinant1/2, but at runtime I copy that
    -- role's data onto whichever real character got assigned to it.
    for determinantKey, assignedCharacterName in pairs(determinantAssignments) do
        local determinantData = determinantLogic[determinantKey]

        if not determinantData then
            warn("No DeterminantLogic entry for: " .. determinantKey)
            continue
        end

        characterTable[assignedCharacterName] = characterTable[assignedCharacterName] or {}

        for key, value in pairs(determinantData) do
            characterTable[assignedCharacterName][key] = value
        end

        -- I keep the determinant name too because my animation markers might be
        -- named Determinant1Move instead of EvanMove.
        characterTable[assignedCharacterName].DeterminantKey = determinantKey
    end
end

-- ============================================================================
-- FINDING / LOADING ANIMATIONS FROM THE TABLES
-- ============================================================================

local function collectAnimationNames(data, names, seen)
    if type(data) ~= "table" then
        return
    end

    -- I recursively scan the scene data instead of manually maintaining another
    -- animation list every time I add a TalkAnimation / WalkAnimation / etc.
    for key, value in pairs(data) do
        if type(key) == "string" and string.find(key, "Animation") then
            if type(value) == "string" then
                if not seen[value] then
                    seen[value] = true
                    table.insert(names, value)
                end
            elseif type(value) == "table" then
                for _, animationName in ipairs(value) do
                    if type(animationName) == "string" and not seen[animationName] then
                        seen[animationName] = true
                        table.insert(names, animationName)
                    end
                end
            end
        end

        if type(value) == "table" then
            collectAnimationNames(value, names, seen)
        end
    end
end

function cutsceneService.populateDiscoveredAnimations(characterData)
    characterData.Animations = characterData.Animations or {}

    local names = {}
    local seen = {}
    collectAnimationNames(characterData, names, seen)

    -- Merge anything I discovered into the same named animation dictionary.
    for _, animationName in ipairs(names) do
        if characterData.Animations[animationName] == nil then
            characterData.Animations[animationName] = animationName
        end
    end
end

local function populateDialogueAnimations(characterTable, dialogueTable, determinantAssignments)
    if not dialogueTable then
        return
    end

    local function addAnimation(characterName, animationName)
        if not animationName or animationName == "" then
            return
        end

        -- Dialogue might refer to a determinant placeholder, so resolve that first.
        local resolvedName = determinantAssignments and determinantAssignments[characterName] or characterName
        local characterData = characterTable[resolvedName]
        if not characterData then
            return
        end

        characterData.Animations = characterData.Animations or {}
        if characterData.Animations[animationName] == nil then
            characterData.Animations[animationName] = animationName
        end
    end

    local function processEntry(entry)
        if not entry then
            return
        end

        if entry.TalkAnimation then
            addAnimation(entry.Speaker, entry.TalkAnimation)
        end

        -- Branches can each reference different animations, so I scan every possible
        -- branch now rather than waiting until the choice has already happened.
        if entry.ConditionalDialogue then
            for _, conditionEntry in ipairs(entry.ConditionalDialogue) do
                processEntry(conditionEntry)
            end
        end
    end

    for _, dialogueEntry in ipairs(dialogueTable) do
        processEntry(dialogueEntry)
    end
end

function cutsceneService.loadScene(sceneFolder, characterTable, cutsceneModule, sceneData, forceLoad, anchored, determinantAssignments)
    local spawnPoints = sceneFolder:FindFirstChild("SpawnPoints")

    -- In the full service I hide the live player characters while the cutscene
    -- versions are on screen. That helper is left out of this excerpt.
    cutsceneService.hideAllCharacters()

    cutsceneService.applyDeterminants(
        characterTable,
        sceneData.DeterminantLogic,
        determinantAssignments
    )

    for _, characterData in pairs(characterTable) do
        cutsceneService.populateDiscoveredAnimations(characterData)
    end

    populateDialogueAnimations(
        characterTable,
        sceneData.Dialogue,
        determinantAssignments
    )

    -- Preload uses the SAME scene table, which is one of the main reasons I wanted
    -- all of this stuff hooked together instead of having separate manual lists.
    assetPreloadService.preloadSceneAssets(
        sceneFolder.Parent.Name,
        sceneFolder.Name,
        cutsceneModule
    )

    -- If the previous scene already loaded the cast, I can reuse/update them instead
    -- of destroying and respawning everybody between every little scene.
    if currentScene.Characters then
        cutsceneService.updateCharacters(characterTable, sceneFolder)
        currentScene.SceneFolder = sceneFolder
        clientToServerEvents.SetPlayerInScene:FireServer(sceneFolder)
        return currentScene.Characters
    end

    local loadedCharacters
    if forceLoad then
        loadedCharacters = cutsceneService.forceLoadCharacters(characterTable, spawnPoints, anchored)
    else
        warn("loadCharacter alive check not implemented")
    end

    currentScene = {
        SceneFolder = sceneFolder,
        Characters = loadedCharacters,
    }

    clientToServerEvents.SetPlayerInScene:FireServer(sceneFolder)
    return loadedCharacters
end

-- ============================================================================
-- CONDITIONAL LOOKUPS
-- ============================================================================

local function evaluateRelationshipValue(currentValue, threshold, comparison)
    if currentValue == nil then
        return false
    end

    comparison = comparison or (threshold >= 0 and ">=" or "<=")

    if comparison == ">=" then return currentValue >= threshold end
    if comparison == "<=" then return currentValue <= threshold end
    if comparison == ">" then return currentValue > threshold end
    if comparison == "<" then return currentValue < threshold end
    if comparison == "==" then return currentValue == threshold end

    warn("Unknown comparison operator: " .. tostring(comparison))
    return false
end

local function evaluateSingleCondition(condition, conditionResults)
    -- I support a few types of story lookup, but the scene authoring stays similar.
    if condition.ConditionType == "Relationship" then
        local currentValue = conditionResults[condition.RelationshipKey]
        return evaluateRelationshipValue(currentValue, condition.Condition, condition.Comparison)
    elseif condition.ConditionType == "String" then
        local currentValue = conditionResults[condition.StringKey]
        return currentValue == condition.Condition
    elseif condition.Condition ~= nil then
        return conditionResults[condition.Condition] == true
    end

    return false
end

local function evaluateEntry(entry, conditionResults)
    -- A Conditions table means ALL of them have to match.
    if entry.Conditions then
        for _, subCondition in ipairs(entry.Conditions) do
            if not evaluateSingleCondition(subCondition, conditionResults) then
                return false
            end
        end
        return true
    end

    return evaluateSingleCondition(entry, conditionResults)
end

function cutsceneService.resolveConditionalEntry(conditionalEntries)
    if not conditionalEntries then
        return nil
    end

    local requests = {}

    local function addRequest(conditionEntry)
        if conditionEntry.ConditionType == "Relationship" then
            table.insert(requests, {
                Type = "Relationship",
                Key = conditionEntry.RelationshipKey,
            })
        elseif conditionEntry.ConditionType == "String" then
            table.insert(requests, {
                Type = "String",
                Key = conditionEntry.StringKey,
            })
        elseif conditionEntry.Condition ~= nil then
            table.insert(requests, {
                Type = "Boolean",
                Key = conditionEntry.Condition,
            })
        end
    end

    -- Collect every piece of story data this branch needs, then ask the server once.
    for _, entry in ipairs(conditionalEntries) do
        if entry.Conditions then
            for _, subCondition in ipairs(entry.Conditions) do
                addRequest(subCondition)
            end
        else
            addRequest(entry)
        end
    end

    local conditionResults = clientToServerEvents.GetData:InvokeServer(requests)

    local chosen = nil
    local default = nil

    for _, entry in ipairs(conditionalEntries) do
        if entry.Default then
            default = entry
        end

        if not chosen and evaluateEntry(entry, conditionResults) then
            chosen = entry
        end
    end

    -- I like having explicit defaults in the scene data so a branch doesn't just
    -- silently die because no special condition happened.
    return chosen or default
end

-- ============================================================================
-- HOOKING SCENE TABLES TO ANIMATION MARKERS
-- ============================================================================

function cutsceneService.generateCutsceneEvents(cameraTrack, characterTable, sceneData, determinantAssignments)
    local dialogueCount = 0
    local choiceCount = 0
    local qteCount = 0
    local moveCount = {}
    local expressionCount = {}
    local animationCount = {}
    local connections = {}

    local dialogueTable = sceneData.Dialogue or {}
    local choiceTable = sceneData.Choices or {}

    for characterName, characterData in pairs(characterTable) do
        -- Normal scenes use EvanMove / EvanTalk / etc.
        -- Determinant scenes can use Determinant1Move instead.
        local markerPrefix = characterData.DeterminantKey or characterName

        if characterData.MovementLogic and #characterData.MovementLogic > 0 then
            table.insert(connections,
                cameraTrack:GetMarkerReachedSignal(markerPrefix .. "Move"):Connect(function()
                    moveCharacterEvent(characterData, characterName, moveCount, cameraTrack)
                end)
            )
        end

        if characterData.AnimationLogic and #characterData.AnimationLogic > 0 then
            table.insert(connections,
                cameraTrack:GetMarkerReachedSignal(markerPrefix .. "Animation"):Connect(function()
                    animationCharacterEvent(characterData, characterName, animationCount)
                end)
            )
        end

        if characterData.ExpressionLogic and #characterData.ExpressionLogic > 0 then
            table.insert(connections,
                cameraTrack:GetMarkerReachedSignal(markerPrefix .. "Expression"):Connect(function()
                    expressionCharacterEvent(characterData, characterName, expressionCount)
                end)
            )
        end

        -- QTEs are authored in the scene table too. Only the player controlling
        -- the matching character actually gets the input prompt.
        if sceneData.QTEs then
            table.insert(connections,
                cameraTrack:GetMarkerReachedSignal(markerPrefix .. "QTE"):Connect(function()
                    qteCount += 1
                    local qteData = sceneData.QTEs[qteCount]
                    if not qteData then
                        return
                    end

                    local localCharacterName = player.Character
                        and player.Character:FindFirstChild("CharacterData")
                        and player.Character.CharacterData:GetAttribute("CharacterName")

                    if qteData.Character ~= localCharacterName then
                        return
                    end

                    local success = minigameService.startQTE(
                        qteData.Key,
                        qteData.Duration,
                        qteData.Position
                    )

                    local resultValue = success and qteData.SucceedValue or qteData.FailValue
                    if resultValue then
                        clientToServerEvents.QTEResult:FireServer(resultValue)
                    end
                end)
            )
        end

        if #dialogueTable > 0 then
            table.insert(connections,
                cameraTrack:GetMarkerReachedSignal(markerPrefix .. "Talk"):Connect(function()
                    dialogueCount += 1
                    local dialogueData = dialogueTable[dialogueCount]
                    if not dialogueData then
                        return
                    end

                    -- This is the important branching part: the timeline just says
                    -- "Talk now" and the story state decides WHICH line actually plays.
                    if dialogueData.ConditionalDialogue then
                        dialogueData = cutsceneService.resolveConditionalEntry(
                            dialogueData.ConditionalDialogue
                        )

                        if not dialogueData then
                            return
                        end
                    end

                    -- Full service continues here with voice lines, subtitles,
                    -- talk animations, facial expressions, popup effects, etc.
                    -- I cut that chunk because it is a lot of presentation code and
                    -- the table -> lookup -> event idea is the part I want to show.
                end)
            )
        end

        if #choiceTable > 0 then
            table.insert(connections,
                cameraTrack:GetMarkerReachedSignal(markerPrefix .. "Choice"):Connect(function()
                    choiceCount += 1
                    local choiceData = choiceTable[choiceCount]
                    if not choiceData then
                        return
                    end

                    -- Freeze the shared timeline while one player is deciding.
                    cameraTrack:AdjustSpeed(0)
                    local cameraPausePosition = cameraTrack.TimePosition
                    local trackPausePositions = {}

                    for _, characterTableData in pairs(characterTable) do
                        local track = characterTableData.Tracks.CutsceneTrack
                        if track then
                            track:AdjustSpeed(0)
                            trackPausePositions[track] = track.TimePosition
                        end
                    end

                    local currentSceneName = currentScene.SceneFolder.Name
                    local choosingCharacterName = choiceData.ChoiceMaker
                    local isChooser = player:GetAttribute("CharacterName") == choosingCharacterName
                    local choiceKey = currentSceneName .. "_" .. tostring(choiceCount)

                    if not isChooser then
                        choiceService.waitForDecision(choosingCharacterName)
                    end

                    -- The server handles who is actually allowed to choose and saves
                    -- the named result. Everyone else is basically waiting here.
                    task.spawn(function()
                        clientToServerEvents.PromptChoiceServer:InvokeServer(
                            choosingCharacterName,
                            "CutsceneCharacter",
                            currentSceneName,
                            choiceData,
                            choiceKey
                        )
                    end)

                    local resumeCutscene
                    resumeCutscene = serverToClientEvents.ResumeCutscene.OnClientEvent:Connect(function(resumeTime)
                        resumeCutscene:Disconnect()

                        -- Resume everybody against the same server time so clients
                        -- don't slowly drift apart after choices.
                        local waitTime = resumeTime - workspace:GetServerTimeNow()
                        if waitTime > 0 then
                            task.wait(waitTime)
                        end

                        if not isChooser then
                            choiceService.disableWaitScreen()
                        end

                        cameraTrack.TimePosition = cameraPausePosition
                        cameraTrack:AdjustSpeed(1)

                        for _, characterTableData in pairs(characterTable) do
                            local track = characterTableData.Tracks.CutsceneTrack
                            if track then
                                track.TimePosition = trackPausePositions[track]
                                track:AdjustSpeed(1)
                            end
                        end
                    end)
                end)
            )
        end
    end

    return connections
end

return cutsceneService
