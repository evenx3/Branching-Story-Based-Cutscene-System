-- This is what an individual cutscene controller looks like AFTER the bigger
-- backend is already built. This is the part I wanted to keep simple.

local cutscenes = {}
local replicatedStorage = game:GetService("ReplicatedStorage")
local runService = game:GetService("RunService")
local cameraAnimations = replicatedStorage.Animations.Camera
local modules = script.Parent.Parent
local cutsceneService = require(modules.CutsceneClientService)
local audioService = require(modules.AudioService)
local camera = workspace.CurrentCamera
local sceneDataModule = script.Act1Chapter1SceneData
local sceneData = require(sceneDataModule)

-- I store scenes under names I can recognize and look up later.
-- I prefer this over having a bunch of anonymous/bare functions floating around.
cutscenes["GroupTalk"] = {
    ["CutsceneData"] = function(sceneFolder)
        local cutsceneName = "CharacterIntroductions"
        local sceneName = "GroupTalk"

        -- Grab the matching dictionary entry from the scene-data module.
        local currentSceneData = sceneData[cutsceneName][sceneName]
        if not currentSceneData then
            warn("Scene not found! Did you forget to update the name?")
            return
        end

        local characterLogic = currentSceneData.CharacterLogic
        local connections = {}

        -- The camera + characters are animated in Blender/Roblox, while the service
        -- listens to named markers inside those tracks for Move/Talk/etc.
        local cameraAnimation = cameraAnimations:FindFirstChild(sceneName)
        local cameraPart = sceneFolder.Camera.Camera
        local cameraAnimator = cameraPart.Parent.AnimationController
        local cameraTrack = cameraAnimator:LoadAnimation(cameraAnimation)

        -- This one call handles the annoying setup: characters, animations,
        -- preload, determinants, props, etc.
        local characterTable = cutsceneService.loadScene(
            sceneFolder,
            characterLogic,
            sceneDataModule,
            currentSceneData,
            true
        )

        -- Then I hook the simple tables to the timeline markers.
        local eventConnections = cutsceneService.generateCutsceneEvents(
            cameraTrack,
            characterTable,
            currentSceneData
        )

        for _, connection in ipairs(eventConnections) do
            table.insert(connections, connection)
        end

        audioService.playMusic("EhhWhatever")
        cutsceneService.fadeScreen(false, 0.25)
        cutsceneService.setCamera(Enum.CameraType.Scriptable, cameraPart)

        -- Keep the actual Roblox camera attached to my animated camera part.
        table.insert(connections, runService.RenderStepped:Connect(function()
            camera.CFrame = cameraPart.CFrame
        end))

        -- Start the camera and every character's main cutscene track together.
        cameraTrack:Play(0)
        for _, characterTableData in pairs(characterTable) do
            characterTableData.Tracks.CutsceneTrack:Play(0)
        end

        -- The timeline decides when the scene is done.
        cameraTrack:GetMarkerReachedSignal("EndScene"):Wait()

        audioService.fadeMusic("EhhWhatever", 0, 1)
        cutsceneService.finishCutscene(
            "Act1Chapter1",
            "CharacterIntroductions",
            "GroupTalk",
            connections,
            characterTable
        )
    end,
}

return cutscenes
