-- These are trimmed examples from my actual scene-data tables.
-- This file is probably the clearest example of how I like to code.
--
-- The basic idea: I don't want every cutscene script to manually say
-- "move this guy, then play this animation, then change his face..."
-- over and over. I put that information in simple tables with names I can
-- recognize, and the bigger CutsceneClientService handles the annoying part.

local sceneDataExamples = {

    -- ================================================================
    -- EXAMPLE 1: CHARACTER LOGIC
    -- ================================================================
    -- CharacterLogic is basically my "what should this character do?" section.
    -- The order of each Movement / Expression / Animation entry lines up with
    -- named markers in the Blender/Roblox animation timeline.
    --
    -- So when the backend sees a marker like FernandoMove, it grabs the next
    -- MovementLogic entry instead of me hard-coding another movement function.

    IceCreamGroupToCar = {
        CharacterLogic = {
            Fernando = {
                -- I keep animation names in one dictionary so the rest of the
                -- scene can refer to recognizable names like "ArmsCrossed".
                Animations = {
                    CutsceneTrack = "FernandoIceCreamGroupToCar",
                    WalkCarefree = "WalkCarefree",
                    RunSlow = "RunSlow",
                    ArmsCrossed = "ArmsCrossed",
                },

                MovementLogic = {
                    -- First movement marker: just snap him to the scene spawn.
                    {
                        Teleport = true,
                    },

                    -- Next marker: walk for six seconds using this animation.
                    {
                        Duration = 6,
                        WalkAnimation = "WalkCarefree",
                    },

                    {
                        Teleport = true,
                    },

                    -- Same movement system can be reused with a different animation.
                    {
                        Duration = 15,
                        WalkAnimation = "RunSlow",
                    },

                    -- This is where the tables start saving me a lot of headache.
                    -- A choice from an EARLIER scene can change where Fernando gets
                    -- teleported without needing a separate cutscene script.
                    {
                        ConditionalMovement = {
                            {
                                Teleport = true,
                                MovePoint = "FernandoMovePoint5",
                                Default = true,
                            },
                            {
                                Teleport = true,
                                MovePoint = "FernandoMovePoint5Alt",
                                Condition = "JennaScold",
                                ConditionType = "Boolean",
                            },
                        },
                    },

                    {
                        Teleport = true,
                    },
                },

                -- Expressions work the exact same way as movement. I describe the
                -- result here and let the backend handle actually changing the face.
                ExpressionLogic = {
                    {
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
                        },
                    },
                },

                -- Same pattern again, this time for a character animation.
                AnimationLogic = {
                    {
                        ConditionalAnimation = {
                            {
                                Track = "ArmsCrossed",
                                CappedDuration = 0.9,
                                Condition = "JennaScold",
                                ConditionType = "Boolean",
                                FadeTime = 0,
                            },
                        },
                    },
                },
            },
        },
    },

    -- ================================================================
    -- EXAMPLE 2: SIMPLE EXPRESSIONS + PROPS
    -- ================================================================
    -- Not everything needs to be conditional. Sometimes I just want a clean list
    -- that the timeline can step through in order.

    CharacterIntroductions = {
        CharacterLogic = {
            Cole = {
                Animations = {
                    CutsceneTrack = "ColeIntro",
                },

                ExpressionLogic = {
                    {
                        Expression = "WideGreenRight",
                        EyeExpression = true,
                    },
                    {
                        Expression = "Default",
                        SubExpressionReset = true,
                    },
                    {
                        Expression = "Terrified",
                    },
                },
            },

            Evan = {
                Animations = {
                    CutsceneTrack = "EvanIntro",
                },

                MovementLogic = {
                    {
                        Teleport = true,
                    },
                    {
                        Duration = 2.15,
                        StartSounds = {
                            "SkateDrop",
                            "Skate",
                        },
                        StopSounds = {
                            "SkateStop",
                        },
                    },
                    {
                        Duration = 2.3,
                        Style = "Quad",
                        StartSounds = {
                            "SkatePush",
                            "SkateWoosh",
                            "Skate",
                        },
                    },
                },

                Props = {
                    {
                        Prop = "Skateboard",
                        Attachment = "Torso",
                    },
                },
            },
        },
    },

    -- ================================================================
    -- EXAMPLE 3: ANIMATION LOGIC / NAMED TRACK LOOKUPS
    -- ================================================================
    -- I like this because the scene says WHICH named animation should happen,
    -- while the service worries about finding the track and playing it correctly.

    GroupTalk = {
        CharacterLogic = {
            Cole = {
                Animations = {
                    CutsceneTrack = "ColeGroupTalk",
                    CrossedArmShortTalk = "CrossedArmShortTalk",
                    CrossedArmDissapointed = "CrossedArmDissapointed",
                },

                MovementLogic = {
                    {
                        Teleport = true,
                    },
                    {
                        Duration = 1,
                    },
                },

                AnimationLogic = {
                    {
                        Track = "CrossedArmShortTalk",
                        Duration = 1.65,
                        FadeTime = 0.25,
                    },
                },
            },

            Haley = {
                Animations = {
                    CutsceneTrack = "HaleyGroupTalk",
                    HaleyTalkDrinkCamera = "HaleyTalkDrinkCamera",
                    HaleyDrinkWalk = "HaleyDrinkWalk",
                },

                MovementLogic = {
                    {
                        Teleport = true,
                    },
                    {
                        Duration = 7,
                        RotateFirst = true,
                        RotateDuration = 0.3,
                        RotateDelay = 0.3,
                        WalkAnimation = "HaleyDrinkWalk",
                        StartSounds = {
                            "ConcreteFootsteps1",
                            Local = true,
                            Duration = 5,
                        },
                    },
                },

                AnimationLogic = {
                    {
                        Track = "HaleyTalkDrinkCamera",
                        CappedDuration = 0.9,
                        FadeTime = 0.25,
                    },
                },

                Props = {
                    {
                        Prop = "Coffee",
                        Attachment = "LeftHand",
                    },
                    {
                        Prop = "Camera",
                        Attachment = "RightHand",
                    },
                },
            },
        },
    },

    -- ================================================================
    -- EXAMPLE 4: CHOICES + CONDITIONAL DIALOGUE
    -- ================================================================
    -- The result names are intentional. Instead of passing random numbers around,
    -- I can search for "JennaScold" later and immediately know what it means.

    LeaveIceCreamGroup = {
        Dialogue = {
            {
                ConditionalDialogue = {
                    {
                        Condition = "JennaScold",
                        ConditionType = "Boolean",
                        Speaker = "Jaime",
                        Text = "Wow... that was pretty intense.",
                        TalkAnimation = "CrossedArmDissapointed",
                        VoicelineSound = "Jaime LICG 1 A",
                    },
                    {
                        Speaker = "Jaime",
                        Text = "I think I'm craving vanilla.",
                        TalkAnimation = "CrossedArmShortTalk",
                        VoicelineSound = "Jaime LICG 1 B",
                        Default = true,
                    },
                },
            },
        },

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
        },

        -- The same named result can change more than dialogue. Here it can also
        -- choose a different camera animation.
        AltCameraAnimations = {
            Animations = {
                LeaveIceCreamGroupAlt = "LeaveIceCreamGroupAlt",
            },
            {
                ConditionalCameraAnimation = {
                    {
                        Track = "LeaveIceCreamGroupAlt",
                        Condition = "JennaScold",
                        ConditionType = "Boolean",
                    },
                },
            },
        },
    },

    -- ================================================================
    -- EXAMPLE 5: A CHOICE AFFECTING A LATER SCENE
    -- ================================================================
    -- This is the part I care about most for branching stories. The later scene
    -- doesn't need to know HOW Evan made the choice. It only looks up the result.

    SchoolBreakIn = {
        Dialogue = {
            {
                ConditionalDialogue = {
                    {
                        Condition = "EvanWary",
                        ConditionType = "Boolean",
                        Speaker = "Evan",
                        Text = "I don't know guys... what if all the doors are locked, or what if we get caught?",
                        SubtitleDuration = 5,
                        VoicelineSound = "Evan SBI 6A",
                    },
                    {
                        Condition = "EvanSupport",
                        ConditionType = "Boolean",
                        Speaker = "Evan",
                        Text = "That sounds like a pretty solid plan. Let's do it!",
                        SubtitleDuration = 5,
                        VoicelineSound = "Evan SBI 6B",
                    },
                    {
                        Default = true,
                        Speaker = "Evan",
                        Text = "Hmm, to be honest, I'm struggling to form an opinion on this...",
                        SubtitleDuration = 5,
                        VoicelineSound = "Evan SBI 6C",
                    },
                },
            },
        },

        Choices = {
            {
                ChoiceMaker = "Evan",
                Choice1Text = "Talk them out of it",
                Choice1Result = "EvanWary",
                Choice2Text = "Support the idea",
                Choice2Result = "EvanSupport",
                Choice3Result = "Quiet",
                ChoiceDuration = 6,
            },
        },
    },

    -- ================================================================
    -- EXAMPLE 6: DETERMINANTS / DYNAMIC CHARACTER ROLES
    -- ================================================================
    -- Determinant1/2/3 are basically placeholder roles. The server can shuffle
    -- actual characters into them, so I can author the scene around a ROLE instead
    -- of needing a separate version for every possible character assignment.

    UnlockedSchoolDoor = {
        CharacterLogic = {
            Evan = {},
            Fernando = {},
            Haley = {},
        },

        DeterminantLogic = {
            Determinant1 = {
                Animations = {
                    CutsceneTrack = "Determinant1UnlockedSchoolDoor",
                },
                MovementLogic = {
                    {
                        Duration = 2,
                        StartSounds = {
                            "ConcreteFootsteps2",
                            Local = true,
                            Duration = 1.7,
                        },
                    },
                },
                Props = {
                    {
                        Prop = "PhoneOn",
                        Attachment = "RightHand",
                    },
                },
            },

            Determinant2 = {
                Animations = {
                    CutsceneTrack = "Determinant2UnlockedSchoolDoor",
                },
            },

            Determinant3 = {
                Animations = {
                    CutsceneTrack = "Determinant3UnlockedSchoolDoor",
                },
            },
        },

        Dialogue = {
            {
                ConditionalDialogue = {
                    {
                        Speaker = "Evan",
                        Text = "I can't let them see this...",
                        SubtitleDuration = 3,

                        -- Multiple conditions here act like an AND check.
                        Conditions = {
                            {
                                Condition = "Evan",
                                StringKey = "UnlockedSchoolDoorOpener",
                                ConditionType = "String",
                            },
                            {
                                Condition = "EvanWary",
                                ConditionType = "Boolean",
                            },
                        },

                        VoicelineSound = "Evan USD 1B",
                    },
                },
            },
            {
                ConditionalDialogue = {
                    {
                        Speaker = "Fernando",
                        Text = "Were you trying to hide that door? C'mon, open it already.",
                        SubtitleDuration = 4,
                        Conditions = {
                            {
                                Condition = "Fernando",
                                StringKey = "UnlockedSchoolDoorDeterminant3",
                                ConditionType = "String",
                            },
                            {
                                Condition = "Evan",
                                StringKey = "UnlockedSchoolDoorOpener",
                                ConditionType = "String",
                            },
                            {
                                Condition = "EvanWary",
                                ConditionType = "Boolean",
                            },
                        },
                        VoicelineSound = "Fernando USD 2B",

                        -- A dialogue result can also feed back into relationships.
                        PopupCharacter1 = "Fernando",
                        PopupCharacter2 = "Evan",
                        PopupType = "Distrust",
                        IncrementRelationship = {
                            { Key = "Evan/Fernando", Amount = -1 },
                        },
                    },
                },
            },
        },
    },
}

return sceneDataExamples
