-- My cutscenes use a lot of animations / sounds, and I really did not want a
-- dramatic scene to randomly get delayed because Roblox decided to load something late.
--
-- So this service reads the same scene tables I already use for authoring,
-- finds the assets mentioned inside them, and preloads them automatically.
-- It also receives asset references from cutscene service to preload the specific
-- scene assets only. Instead of preloading a large dump, it loads the scenes
-- consecutively to preserve memory. 

local assetPreloadService = {}
local replicatedStorage = game:GetService("ReplicatedStorage")
local contentProvider = game:GetService("ContentProvider")
local animationsFolder = replicatedStorage.Animations
local soundsFolder = replicatedStorage.Sounds
local cameraAnimationFolder = animationsFolder.Camera

-- These let me skip assets that have already been preloaded.
local preloadedAssets = {}
local preloadedScenes = {}

-- I cache by readable names so the scene data can keep using names instead of
-- needing references to actual Instance objects everywhere.
local soundCache = {}
local animationCache = {}

-- If I already know scene B is a likely follow-up to scene A, I can warm B while
-- A is loading. Tiny table, but it saves me from putting special-case code all over.
local preloadGraph = {
    GroupTalk = { "LeaveIceCreamGroup" },
    SchoolBreakIn = { "UnlockedSchoolDoor" },
}

for _, sound in ipairs(soundsFolder:GetDescendants()) do
    if sound:IsA("Sound") then
        soundCache[sound.Name] = sound
    end
end

for _, animation in ipairs(animationsFolder:GetDescendants()) do
    if animation:IsA("Animation") then
        animationCache[animation.Name] = animation
    end
end

local function collectSounds(data, assets, seen)
    if type(data) ~= "table" then
        return
    end

    local function tryAddSound(soundName, keyForWarning)
        local sound = soundCache[soundName]

        if sound then
            -- seen = no duplicates in this pass
            -- preloadedAssets = no duplicates from older scenes either
            if not preloadedAssets[sound] and not seen[sound] then
                seen[sound] = true
                table.insert(assets, sound)
            end
        else
            warn("Could not find sound referenced by key '" .. keyForWarning .. "': " .. tostring(soundName))
        end
    end

    -- My scene-table naming is useful here. Anything with "Sound" in the key is
    -- something this service should inspect, even if it is nested pretty deep.
    -- This saves a lot of time as I don't have to rereference sounds during each scene table pass.
    for key, value in pairs(data) do
        if type(key) == "string" and string.find(key, "Sound") then
            if type(value) == "table" then
                for _, soundName in ipairs(value) do
                    tryAddSound(soundName, key)
                end
            else
                tryAddSound(value, key)
            end
        end

        -- Recursive so ConditionalDialogue / DeterminantLogic / etc. also get scanned.
        if type(value) == "table" then
            collectSounds(value, assets, seen)
        end
    end
end

-- This was made because I noticed writting out each animation reference
-- was a waste of time
local function collectAllAnimationNames(data, names, seen)
    if type(data) ~= "table" then
        return
    end

    for key, value in pairs(data) do
        if key == "Animations" and type(value) == "table" then
            -- The main Animations dictionary is easy: every value is an animation name.
            for _, animationName in pairs(value) do
                if type(animationName) == "string" and not seen[animationName] then
                    seen[animationName] = true
                    table.insert(names, animationName)
                end
            end
        elseif type(key) == "string" and string.find(key, "Animation") then
            -- This also catches stuff like WalkAnimation / TalkAnimation / etc.
            if type(value) == "string" and not seen[value] then
                seen[value] = true
                table.insert(names, value)
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
            collectAllAnimationNames(value, names, seen)
        end
    end
end

function assetPreloadService.assetList(allSceneData)
    local assets = {}
    local seenSounds = {}
    local seenAnimations = {}

    -- This is why I like keeping the scene data structured consistently:
    -- the loader can just inspect the table instead of me making a second asset list.
    collectSounds(allSceneData, assets, seenSounds)

    local animationNames = {}
    collectAllAnimationNames(allSceneData, animationNames, seenAnimations)

    for _, animationName in ipairs(animationNames) do
        local animation = animationCache[animationName]

        if animation and not preloadedAssets[animation] then
            table.insert(assets, animation)
        elseif not animation then
            warn("[AssetPreloadService] Animation not found: " .. tostring(animationName))
        end
    end

    return assets
end

function assetPreloadService.preloadSceneAssets(cutscene, scene, cutsceneModule)
    local sceneKey = cutscene .. "_" .. scene

    -- A scene can get touched by multiple systems, so I keep a simple scene lookup
    -- instead of trusting myself to remember whether I already loaded it.
    if preloadedScenes[sceneKey] then
        return
    end

    local sceneDataModule = require(cutsceneModule)
    local allSceneData = sceneDataModule[cutscene][scene]
    local cameraAnimation = cameraAnimationFolder:FindFirstChild(scene)
        or cameraAnimationFolder:FindFirstChild(cutscene)

    local assets = assetPreloadService.assetList(allSceneData)

    -- Alternate/conditional cameras live in the scene table too, so load those now
    -- even if the player's branch might not end up using them.
    if allSceneData.AltCameraAnimations then
        for _, animationName in pairs(allSceneData.AltCameraAnimations.Animations) do
            local cameraTrackAnimation = animationCache[animationName]
            if cameraTrackAnimation and not preloadedAssets[cameraTrackAnimation] then
                table.insert(assets, cameraTrackAnimation)
            end
        end
    end

    if cameraAnimation then
        table.insert(assets, cameraAnimation)
    end

    contentProvider:PreloadAsync(assets)

    for _, asset in ipairs(assets) do
        preloadedAssets[asset] = true
    end
    preloadedScenes[sceneKey] = true

    -- If this scene has a known follow-up, preload that one too.
    -- This is especially useful before a branch where I don't want a hitch right
    -- when the story jumps into the next scene.
    for _, branchScene in ipairs(preloadGraph[scene] or {}) do
        local branchSceneKey = cutscene .. "_" .. branchScene

        if not preloadedScenes[branchSceneKey] then
            local branchSceneData = sceneDataModule[cutscene][branchScene]

            if branchSceneData then
                local branchAssets = assetPreloadService.assetList(branchSceneData)
                local branchCameraAnimation = cameraAnimationFolder:FindFirstChild(branchScene)

                if branchCameraAnimation then
                    table.insert(branchAssets, branchCameraAnimation)
                end

                contentProvider:PreloadAsync(branchAssets)

                for _, asset in ipairs(branchAssets) do
                    preloadedAssets[asset] = true
                end
                preloadedScenes[branchSceneKey] = true
            end
        end
    end
end

return assetPreloadService
