# The Valley Ripper. Cutscene / Story Systems

This is a small collection of code from *The Valley Ripper*, a branching multiplayer horror game I've been building in Roblox Studio with Lua/Luau. I also make the character/camera animations for the cutscenes in Blender.

I didn't upload the entire game because there are a ton of scripts, UI objects, animations, sounds, maps, RemoteEvents, etc. This repo is basically the parts that best show how I like to structure stuff.

Also: the code files have comments explaining what I was trying to do. They're not meant to read like official documentation.

Here’s a short explanation of my system here: https://m.youtube.com/watch?v=snvaNUCbiRY&ra=m

## AI use disclaimer

AI was **not used to write or generate the game code in this repo**. I only used AI while developing for occasional debugging help.

When I made this GitHub showcase, I did use AI to help **segment larger source files into shorter excerpts and add comments/explanations** so someone looking through the repo could understand the systems without digging through the entire game. That AI use was only for organizing and presenting the showcase. the underlying systems and code were written by me.

## How I like to code

A big thing with my coding style is that I like **named dictionaries / tables and lookups**.

I don't really like having random bare functions and behavior scattered everywhere if I can avoid it. I'd rather give things names like:

```text
SchoolBreakIn
JennaScold
EvanWary
Determinant1
WalkCarefree
FernandoMovePoint5Alt
```

and have different systems hook into those names.

It makes it way easier for me to come back to a project later and understand what I was doing without my brain exploding.

The main idea behind my cutscene system became:

> make the backend complicated once so actually making new cutscenes can stay simple

So instead of writing this type of thing separately in every scene:

```text
move character
wait
play animation
change expression
show dialogue
check story choice
move character again
play sound
show QTE
...
```

I wanted to mostly write **what should happen** in a table and let the backend figure out **how it happens**.

For example:

```lua
AnimationLogic = {
    {
        Track = "CrossedArmShortTalk",
        Duration = 1.65,
        FadeTime = 0.25,
    },
}
```

or:

```lua
Choices = {
    {
        ChoiceMaker = "Jenna",
        Choice1Text = "Tell a joke",
        Choice1Result = "JennaJoke",
        Choice2Text = "Scold the group",
        Choice2Result = "JennaScold",
        Choice3Result = "Quiet",
        ChoiceDuration = 6,
    },
}
```

The big service already knows how to play the animation, pause the multiplayer cutscene, show the choice UI, save the result, resume everybody, etc.

That was the whole point: **new scene creation should get easier as the project gets bigger, not harder.**

## Rough flow

```text
SceneData
   |
   | readable names / tables
   v
CutsceneClientService
   |
   | hooks them to animation timeline markers
   v
Movement / Expressions / Animations / Dialogue / Choices / QTEs
   |
   v
Server story state + relationships
   |
   v
Later scenes look up those named results
```

`AssetPreloadService` also reads the same scene tables so I don't have to keep a completely separate list of every animation/sound the scene needs.

## Where I would start looking

If you're just clicking through this repo, I'd look at these in this order:

1. `scenes/SceneData_Examples.lua`
2. `client/CutsceneClientService_Excerpt.lua`
3. `examples/CutsceneController_Example.lua`
4. `client/ChoiceService_Excerpt.lua`
5. `server/ChoiceServerHandler_Excerpt.lua`
6. `services/AssetPreloadService_Showcase.lua`

The other files just show a little more of how the systems connect.

---

## `scenes/SceneData_Examples.lua`

This is probably the best file for understanding **why I built the whole system**.

It now has examples of basically every main authoring pattern I use:

```text
CharacterLogic
├── Animations
├── MovementLogic
├── ExpressionLogic
├── AnimationLogic
└── Props

Scene-level stuff
├── Dialogue
├── ConditionalDialogue
├── Choices
├── AltCameraAnimations
└── DeterminantLogic
```

### CharacterLogic

Each character gets a named table describing what they might do during that scene.

For example, movement can just be:

```lua
MovementLogic = {
    {
        Teleport = true,
    },
    {
        Duration = 6,
        WalkAnimation = "WalkCarefree",
    },
}
```

Then my camera/scene animation has markers like:

```text
FernandoMove
FernandoAnimation
FernandoExpression
FernandoTalk
```

When one of those markers is reached, the backend grabs the next matching table entry.

This is WAY easier for me than having the cutscene script directly call movement/animation/expression functions every single time.

### Conditional character stuff

A previous choice can even change normal character behavior:

```lua
ConditionalExpression = {
    {
        Expression = "AngryRight",
        Condition = "JennaScold",
        ConditionType = "Boolean",
    },
    {
        Expression = "Default",
        Default = true,
    },
}
```

The same basic pattern also works for movement, animations, dialogue, cameras, etc.

That's another thing I wanted: **learn one structure and reuse it everywhere** instead of every system having completely different logic.

---

## `client/CutsceneClientService_Excerpt.lua`

This is the big backend that makes the scene-data approach work.

It's more complicated on purpose because I would rather deal with complexity here than make every individual scene messy.

A few things it does:

- reads `CharacterLogic`;
- handles determinant characters;
- finds animation names used throughout scene data;
- asks the preloader to load scene assets;
- checks saved story conditions;
- connects named animation markers to movement / animation / expression events;
- starts QTEs;
- pauses multiplayer cutscenes for choices;
- syncs everybody back up when the choice is finished.

The file is still an excerpt because the actual service is huge. I left out some of the more boring implementation parts like prop welds, fade helpers, and a lot of subtitle / voice-line presentation code.

The important part is the connection between **simple scene tables** and the larger reusable backend.

---

## `examples/CutsceneController_Example.lua`

This is what I actually wanted individual cutscene code to look like after building the backend.

It mostly does this:

```text
look up scene by name
        ↓
load CharacterLogic
        ↓
generate marker events
        ↓
start camera + character tracks
        ↓
wait for EndScene
        ↓
cleanup
```

So even though `CutsceneClientService` is big, a new scene does not need to be.

I also use another dictionary here:

```lua
cutscenes["GroupTalk"] = {
    ["CutsceneData"] = function(sceneFolder)
        ...
    end,
}
```

I like being able to look up a scene/function by a recognizable name instead of trying to remember where a random function lives.

---

## `client/ChoiceService_Excerpt.lua`

This handles the client/UI side of decisions.

The scene gives it simple stuff like:

```text
choice text
result names
time limit
choosing character
```

and the service handles:

- showing the buttons;
- countdown timing;
- timeout/default choices;
- waiting UI for other multiplayer clients;
- butterfly-effect feedback;
- relationship/story popups.

The most important thing coming out of it is just a named result like:

```text
JennaScold
```

Then the server can decide what `JennaScold` actually changes.

---

## `server/ChoiceServerHandler_Excerpt.lua`

This is another place I use a dictionary lookup because it makes more sense in my head.

```lua
local choiceHandler = {
    ["JennaJoke"] = function(...)
        -- change story state
    end,

    ["JennaScold"] = function(...)
        -- change story state
    end,
}
```

So if the client sends `JennaScold`, I can directly look up the behavior under `JennaScold`.

I prefer that to a massive chain like:

```text
if choice == this...
elseif choice == that...
elseif choice == something else...
```

especially once a game has a lot more choices.

---

## `server/CutsceneServerService_Excerpt.lua`

This shows two multiplayer things:

### Only starting scenes for involved characters

Not every player has to be part of every scene, so the server checks their character name and only starts the cutscene for the characters involved.

### Determinants

A determinant is basically a placeholder role:

```text
Determinant1
Determinant2
Determinant3
```

The server can randomly assign real characters to those roles:

```text
Determinant1 -> Evan
Determinant2 -> Haley
Determinant3 -> Fernando
```

Then the scene can be written around the role instead of hard-coding a specific character into every possible version.

---

## `services/AssetPreloadService_Showcase.lua`

This came from me not wanting animations/audio to load in the middle of a cinematic.

The part I like is that it uses the **same naming/table setup** as everything else.

It recursively scans scene data for keys containing stuff like:

```text
Animation
Sound
```

so `TalkAnimation`, `WalkAnimation`, `VoicelineSound`, determinant animations, conditional branches, etc. can all be discovered without me making another giant asset list manually.

It also has a tiny preload graph:

```lua
local preloadGraph = {
    GroupTalk = { "LeaveIceCreamGroup" },
    SchoolBreakIn = { "UnlockedSchoolDoor" },
}
```

so I can load likely next scenes early.

Again, I like this because the different systems are **hooked together through the data** instead of me directly managing every connection by hand.

---

## `client/MinigameService_Excerpt.lua`

This is the reusable QTE part.

Instead of a cutscene containing input code, the scene can basically say:

```text
Key = "W"
Duration = 1.5
Position = "Right"
```

and this service handles the input, timing, UI feedback, sounds, and success/failure result.

The full minigame service also has a heartbeat timing minigame, but I left that out because this repo is supposed to show the system without becoming another 2,000-line dump.

---

## Example of everything connecting

One branch can basically go:

```text
SceneData says Jenna gets a choice
            ↓
Cutscene timeline reaches JennaChoice
            ↓
ChoiceService shows her options
            ↓
player picks "Scold the group"
            ↓
result name = JennaScold
            ↓
server looks up choiceHandler["JennaScold"]
            ↓
story flag / relationship changes
            ↓
later SceneData checks JennaScold
            ↓
Fernando can move differently,
look angry, play a different animation,
and dialogue/camera can change too
```

That's basically what I was trying to build: a bunch of systems that can talk to each other through readable names, while the actual scene files stay understandable.

## Small note

This is **not** a standalone version of the game. A lot of Roblox objects/modules/assets that these scripts reference are not included here.

I also trimmed the files down on purpose. The real scene-data modules are way longer, but I think dumping thousands of lines here would make it harder to see the actual structure I wanted to show.
