--[[
    Kali Hub - Basketball Legends
    UI: Rayfield
    Credits: @wrl11 & @aylonthegiant | discord.gg/epNcR8Ce89
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")

local cloneref = cloneref or function(v) return v end
local player = Players.LocalPlayer
local Char = player.Character or player.CharacterAdded:Wait()
local Hum = cloneref(Char:WaitForChild("Humanoid")) or cloneref(Char:FindFirstChild("Humanoid"))
local Hrp = cloneref(Char:WaitForChild("HumanoidRootPart")) or cloneref(Char:FindFirstChild("HumanoidRootPart"))

-- Load Rayfield
local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

-- State variables
local autoShootEnabled = false
local autoGuardEnabled = false
local autoGuardToggleEnabled = false
local holdingG = false
local speedBoostEnabled = false
local postAimbotEnabled = false

local desiredSpeed = 30
local predictionTime = 0.3
local guardDistance = 10
local shootPower = 0.8
local postActivationDistance = 10

local visibleConn = nil
local autoGuardConnection = nil
local speedBoostConnection = nil
local postAimbotConnection = nil
local lastPositions = {}

local postHoldActive = false
local lastPostUpdate = 0
local POST_UPDATE_INTERVAL = 0.033

local teleportEnabled = false
local offsetDistance = 3

local followEnabled = false
local followConnection = nil
local followOffset = -10

local MagsDist = 30
local magnetEnabled = false
local magnetConnection = nil

local stealReachEnabled = false
local stealReachMultiplier = 1.5
local originalRightArmSize, originalLeftArmSize

local animationSpoofEnabled = false
local dunkSpoofConnection = nil
local emoteSpoofConnection = nil
local charAddedConnDunk = nil
local charAddedConnEmote = nil
local selectedDunkAnim = "Default"
local selectedEmoteAnim = "Dance_Casual"

-- Services
local visualGui = player.PlayerGui:WaitForChild("Visual")
local shootingElement = visualGui:WaitForChild("Shooting")
local Shoot = ReplicatedStorage.Packages.Knit.Services.ControlService.RE.Shoot
local AnimationsFolder = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Animations_R15")

local function IsPark()
    if workspace:WaitForChild("Game"):FindFirstChild("Courts") then
        return true
    else
        return false
    end
end
local isPark = IsPark()

-- =====================
-- Helper Functions
-- =====================

local function getPlayerFromModel(model)
    for _, plr in pairs(Players:GetPlayers()) do
        if plr.Character == model then return plr end
    end
    return nil
end

local function isOnDifferentTeam(otherModel)
    local otherPlayer = getPlayerFromModel(otherModel)
    if not otherPlayer then return false end
    if not player.Team or not otherPlayer.Team then
        return otherPlayer ~= player
    end
    return player.Team ~= otherPlayer.Team
end

local function findPlayerWithBall()
    if isPark then
        local closestPlayer, closestDistance = nil, math.huge
        for _, model in pairs(workspace:GetChildren()) do
            if model:IsA("Model") and model:FindFirstChild("HumanoidRootPart") and model ~= player.Character then
                local tool = model:FindFirstChild("Basketball")
                if tool and tool:IsA("Tool") then
                    local hrp = model.HumanoidRootPart
                    local dist = (hrp.Position - player.Character.HumanoidRootPart.Position).Magnitude
                    if dist < closestDistance then
                        closestDistance = dist
                        closestPlayer = model
                    end
                end
            end
        end
        if closestPlayer then return closestPlayer, closestPlayer:FindFirstChild("HumanoidRootPart") end
        return nil, nil
    end

    local looseBall = workspace:FindFirstChild("Basketball")
    if looseBall and looseBall:IsA("BasePart") then
        local closestPlayer, closestDistance = nil, math.huge
        for _, model in pairs(workspace:GetChildren()) do
            if model:IsA("Model") and model:FindFirstChild("HumanoidRootPart") and model ~= player.Character then
                if isOnDifferentTeam(model) then
                    local rootPart = model:FindFirstChild("HumanoidRootPart")
                    local distance = (looseBall.Position - rootPart.Position).Magnitude
                    if distance < closestDistance and distance < 15 then
                        closestDistance = distance
                        closestPlayer = model
                    end
                end
            end
        end
        if closestPlayer then return closestPlayer, closestPlayer:FindFirstChild("HumanoidRootPart") end
    end

    for _, model in pairs(workspace:GetChildren()) do
        if model:IsA("Model") and model:FindFirstChild("HumanoidRootPart") and model ~= player.Character then
            if isOnDifferentTeam(model) then
                local basketball = model:FindFirstChild("Basketball")
                if basketball and basketball:IsA("Tool") then
                    return model, model:FindFirstChild("HumanoidRootPart")
                end
            end
        end
    end
    return nil, nil
end

local function getClosestOpponent()
    local char = player.Character
    if not char then return nil end
    local myRoot = char:FindFirstChild("HumanoidRootPart")
    if not myRoot then return nil end
    local closest, minDist = nil, postActivationDistance
    for _, plr in pairs(Players:GetPlayers()) do
        if plr ~= player and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
            if isOnDifferentTeam(plr.Character) then
                local enemyRoot = plr.Character.HumanoidRootPart
                local dist = (enemyRoot.Position - myRoot.Position).Magnitude
                if dist < minDist then closest = enemyRoot; minDist = dist end
            end
        end
    end
    return closest
end

local function playerHasBall()
    local char = player.Character
    if not char then return false end
    local t = char:FindFirstChild("Basketball")
    return t and t:IsA("Tool")
end

local function detectBallHand()
    local char = player.Character
    if not char then return "right" end
    local tool = char:FindFirstChild("Basketball")
    if tool and tool:IsA("Tool") then
        local handle = tool:FindFirstChild("Handle")
        if handle then
            local root = char:FindFirstChild("HumanoidRootPart")
            if root then
                local rel = root.CFrame:ToObjectSpace(handle.CFrame)
                return rel.X > 0 and "right" or "left"
            end
        end
    end
    return "right"
end

local function executePostAimbot()
    local currentTime = tick()
    if currentTime - lastPostUpdate < POST_UPDATE_INTERVAL then return end
    lastPostUpdate = currentTime
    if not postHoldActive then return end
    local char = player.Character
    if not char then return end
    local myRoot = char:FindFirstChild("HumanoidRootPart")
    if not myRoot then return end
    local hasBall = playerHasBall()
    local target = getClosestOpponent()
    if target then
        local dir = (target.Position - myRoot.Position).Unit
        local face = CFrame.new(myRoot.Position, myRoot.Position + dir)
        if hasBall then
            local hand = detectBallHand()
            myRoot.CFrame = face * CFrame.Angles(0, math.rad(hand == "left" and 90 or -90), 0)
        else
            myRoot.CFrame = face
        end
    end
end

local function autoGuard()
    if not autoGuardEnabled then return end
    if Players.LocalPlayer:FindFirstChild("Basketball") then return end
    local character = player.Character
    if not character then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoid or not rootPart then return end
    local ballCarrier, ballCarrierRoot = findPlayerWithBall()
    if ballCarrier and ballCarrierRoot then
        local distance = (rootPart.Position - ballCarrierRoot.Position).Magnitude
        local currentPos = ballCarrierRoot.Position
        local velocity = Vector3.new(0, 0, 0)
        if lastPositions[ballCarrier] then
            velocity = (currentPos - lastPositions[ballCarrier]) / task.wait()
        end
        lastPositions[ballCarrier] = currentPos
        local predictedPos = currentPos + (velocity * predictionTime * 60)
        local directionToOpponent = (predictedPos - rootPart.Position).Unit
        local defensivePosition = predictedPos - (directionToOpponent * 5)
        defensivePosition = Vector3.new(defensivePosition.X, rootPart.Position.Y, defensivePosition.Z)
        if distance <= guardDistance then
            humanoid:MoveTo(defensivePosition)
            local VIM = game:GetService("VirtualInputManager")
            if distance <= 10 then
                VIM:SendKeyEvent(true, Enum.KeyCode.F, false, game)
            else
                VIM:SendKeyEvent(false, Enum.KeyCode.F, false, game)
            end
        else
            game:GetService("VirtualInputManager"):SendKeyEvent(false, Enum.KeyCode.F, false, game)
        end
    else
        game:GetService("VirtualInputManager"):SendKeyEvent(false, Enum.KeyCode.F, false, game)
    end
end

local function updateHitboxSizes()
    local char = player.Character
    if not char then return end
    local rightArm = char:FindFirstChild("Right Arm") or char:FindFirstChild("RightHand") or char:FindFirstChild("RightLowerArm")
    local leftArm = char:FindFirstChild("Left Arm") or char:FindFirstChild("LeftHand") or char:FindFirstChild("LeftLowerArm")
    if stealReachEnabled then
        if rightArm then
            if not originalRightArmSize then originalRightArmSize = rightArm.Size end
            rightArm.Size = originalRightArmSize * stealReachMultiplier
            rightArm.Transparency = 1; rightArm.CanCollide = false; rightArm.Massless = true
        end
        if leftArm then
            if not originalLeftArmSize then originalLeftArmSize = leftArm.Size end
            leftArm.Size = originalLeftArmSize * stealReachMultiplier
            leftArm.Transparency = 1; leftArm.CanCollide = false; leftArm.Massless = true
        end
    else
        if rightArm and originalRightArmSize then
            rightArm.Size = originalRightArmSize; rightArm.Transparency = 0
            rightArm.CanCollide = false; rightArm.Massless = false; originalRightArmSize = nil
        end
        if leftArm and originalLeftArmSize then
            leftArm.Size = originalLeftArmSize; leftArm.Transparency = 0
            leftArm.CanCollide = false; leftArm.Massless = false; originalLeftArmSize = nil
        end
    end
end

local function startCFrameSpeed(speed)
    local connection
    connection = RunService.RenderStepped:Connect(function(deltaTime)
        local character = player.Character
        if not character then return end
        local root = character:FindFirstChild("HumanoidRootPart")
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if not root or not humanoid then return end
        local moveVec = humanoid.MoveDirection
        if moveVec.Magnitude > 0 then
            local speedDelta = math.max(speed - humanoid.WalkSpeed, 0)
            root.CFrame = root.CFrame + (moveVec.Unit * speedDelta * deltaTime)
        end
    end)
    return function() if connection then connection:Disconnect() end end
end

local function setBGVisibleToTrue()
    for _, model in pairs(workspace:GetChildren()) do
        if model:IsA("Model") and model:FindFirstChild("HumanoidRootPart") then
            local hrp = model.HumanoidRootPart
            for _, obj in pairs(hrp:GetDescendants()) do
                if obj.Name == "BG" and obj:IsA("BodyGyro") then
                    obj.Parent = hrp
                    obj.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
                    obj.P = 9e4; obj.D = 500
                    obj.CFrame = hrp.CFrame
                end
            end
        end
    end
end

local function hideBG()
    for _, model in pairs(workspace:GetChildren()) do
        if model:IsA("Model") and model:FindFirstChild("HumanoidRootPart") then
            for _, obj in pairs(model.HumanoidRootPart:GetDescendants()) do
                if obj.Name == "BG" and obj:IsA("BodyGyro") then obj.Parent = nil end
            end
        end
    end
end

local function setupDunkSpoof(humanoid)
    local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)
    return animator.AnimationPlayed:Connect(function(track)
        if animationSpoofEnabled and track.Animation.Name == "Dunk_Default" and selectedDunkAnim ~= "Default" then
            track:Stop()
            local customAnim = AnimationsFolder:FindFirstChild("Dunk_" .. selectedDunkAnim)
            if customAnim then humanoid:LoadAnimation(customAnim):Play() end
        end
    end)
end

local function setupEmoteSpoof(humanoid)
    local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)
    return animator.AnimationPlayed:Connect(function(track)
        if animationSpoofEnabled and track.Animation.Name == "Dance_Casual" and selectedEmoteAnim ~= "Dance_Casual" then
            track:Stop()
            local customAnim = AnimationsFolder:FindFirstChild(selectedEmoteAnim)
            if customAnim then humanoid:LoadAnimation(customAnim):Play() end
        end
    end)
end

local function enableAnimationSpoof()
    local char = player.Character
    if char then
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        if humanoid then
            if dunkSpoofConnection then dunkSpoofConnection:Disconnect() end
            if emoteSpoofConnection then emoteSpoofConnection:Disconnect() end
            dunkSpoofConnection = setupDunkSpoof(humanoid)
            emoteSpoofConnection = setupEmoteSpoof(humanoid)
        end
    end
    if charAddedConnDunk then charAddedConnDunk:Disconnect() end
    if charAddedConnEmote then charAddedConnEmote:Disconnect() end
    charAddedConnDunk = player.CharacterAdded:Connect(function(newChar)
        local hum = newChar:WaitForChild("Humanoid")
        if dunkSpoofConnection then dunkSpoofConnection:Disconnect() end
        dunkSpoofConnection = setupDunkSpoof(hum)
    end)
    charAddedConnEmote = player.CharacterAdded:Connect(function(newChar)
        local hum = newChar:WaitForChild("Humanoid")
        if emoteSpoofConnection then emoteSpoofConnection:Disconnect() end
        emoteSpoofConnection = setupEmoteSpoof(hum)
    end)
end

local function disableAnimationSpoof()
    if dunkSpoofConnection then dunkSpoofConnection:Disconnect(); dunkSpoofConnection = nil end
    if emoteSpoofConnection then emoteSpoofConnection:Disconnect(); emoteSpoofConnection = nil end
    if charAddedConnDunk then charAddedConnDunk:Disconnect(); charAddedConnDunk = nil end
    if charAddedConnEmote then charAddedConnEmote:Disconnect(); charAddedConnEmote = nil end
end

-- =====================
-- RunService Connections
-- =====================

RunService.RenderStepped:Connect(function()
    -- Auto Rebound teleport
    if teleportEnabled then
        local char = player.Character
        if char then
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if hrp then
                local closestBall, closestDist = nil, math.huge
                local maxDistance = isPark and 100 or math.huge
                for _, child in ipairs(workspace:GetChildren()) do
                    if child.Name == "Basketball" then
                        local part = child:IsA("BasePart") and child or child:FindFirstChildWhichIsA("BasePart")
                        if part then
                            local dist = (part.Position - hrp.Position).Magnitude
                            if dist < closestDist and dist <= maxDistance then
                                closestDist = dist; closestBall = part
                            end
                        end
                    end
                end
                if closestBall then
                    hrp.CFrame = CFrame.new(closestBall.Position + closestBall.CFrame.LookVector * offsetDistance)
                end
            end
        end
    end
    -- Steal Reach
    if stealReachEnabled then updateHitboxSizes() end
end)

magnetConnection = RunService.Heartbeat:Connect(function()
    if not magnetEnabled then return end
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    for _, v in ipairs(workspace:GetDescendants()) do
        if v:IsA("BasePart") and v.Name == "Basketball" then
            local dist = (hrp.Position - v.Position).Magnitude
            if dist <= MagsDist then
                local touch = v:FindFirstChildOfClass("TouchTransmitter")
                if not touch then
                    for _, d in ipairs(v:GetDescendants()) do
                        if d:IsA("TouchTransmitter") then touch = d; break end
                    end
                end
                if touch then
                    firetouchinterest(hrp, v, 0)
                    firetouchinterest(hrp, v, 1)
                end
            end
        end
    end
end)

-- Guard key binds
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if input.KeyCode == Enum.KeyCode.G and not gameProcessed then
        if autoGuardToggleEnabled then
            holdingG = true
            autoGuardEnabled = true
            lastPositions = {}
            if not autoGuardConnection then
                autoGuardConnection = RunService.Heartbeat:Connect(autoGuard)
            end
        end
    end
    -- Post Aimbot hold key (P)
    if input.KeyCode == Enum.KeyCode.P and not gameProcessed then
        if postAimbotEnabled then
            postHoldActive = true
            if not postAimbotConnection then
                postAimbotConnection = RunService.Heartbeat:Connect(executePostAimbot)
            end
        end
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.G then
        holdingG = false
        autoGuardEnabled = false
        if autoGuardConnection then autoGuardConnection:Disconnect(); autoGuardConnection = nil end
        lastPositions = {}
        game:GetService("VirtualInputManager"):SendKeyEvent(false, Enum.KeyCode.F, false, game)
    end
    if input.KeyCode == Enum.KeyCode.P then
        postHoldActive = false
        if postAimbotConnection then postAimbotConnection:Disconnect(); postAimbotConnection = nil end
    end
    -- Follow ball carrier toggle (H)
    if input.KeyCode == Enum.KeyCode.H then
        followEnabled = not followEnabled
        if followEnabled then
            if not followConnection then
                followConnection = RunService.Heartbeat:Connect(function()
                    if not followEnabled then return end
                    local char = player.Character
                    if not char then return end
                    local hrp = char:FindFirstChild("HumanoidRootPart")
                    if not hrp then return end
                    local ballCarrier, ballCarrierRoot = findPlayerWithBall()
                    if ballCarrier and ballCarrierRoot then
                        local maxDist = isPark and 100 or math.huge
                        local dist = (hrp.Position - ballCarrierRoot.Position).Magnitude
                        if dist <= maxDist then
                            hrp.CFrame = ballCarrierRoot.CFrame * CFrame.new(0, 0, followOffset)
                        end
                    end
                end)
            end
        else
            if followConnection then followConnection:Disconnect(); followConnection = nil end
        end
    end
    -- Ball Magnet toggle (M)
    if input.KeyCode == Enum.KeyCode.M then
        magnetEnabled = not magnetEnabled
    end
    -- Auto Rebound toggle (T)
    if input.KeyCode == Enum.KeyCode.T then
        teleportEnabled = not teleportEnabled
    end
end)

-- =====================
-- RAYFIELD UI
-- =====================

local Window = Rayfield:CreateWindow({
    Name = "Kali Hub",
    Icon = 0,
    LoadingTitle = "Kali Hub",
    LoadingSubtitle = "by @wrl11 & @aylonthegiant",
    Theme = "Default",
    DisableRayfieldPrompts = false,
    DisableBuildWarnings = false,
})

-- ======= MAIN TAB =======
local MainTab = Window:CreateTab("Main", 4483362458)

-- Auto Shooting Section
local ShootSection = MainTab:CreateSection("Auto Shooting")

MainTab:CreateToggle({
    Name = "Auto Time",
    CurrentValue = false,
    Flag = "AutoShoot",
    Callback = function(value)
        autoShootEnabled = value
        if autoShootEnabled then
            if not visibleConn then
                visibleConn = shootingElement:GetPropertyChangedSignal("Visible"):Connect(function()
                    if autoShootEnabled and shootingElement.Visible == true then
                        task.wait(0.25)
                        Shoot:FireServer(shootPower)
                    end
                end)
            end
        else
            if visibleConn then visibleConn:Disconnect(); visibleConn = nil end
        end
    end,
})

MainTab:CreateSlider({
    Name = "Shot Timing",
    Range = {50, 100},
    Increment = 1,
    Suffix = "%",
    CurrentValue = 80,
    Flag = "ShootTiming",
    Callback = function(value)
        shootPower = value / 100
    end,
})

MainTab:CreateParagraph({
    Title = "Shot Timing Guide",
    Content = "80 = Mediocre | 90 = Good | 95 = Great | 100 = Perfect"
})

-- Auto Guard Section
local GuardSection = MainTab:CreateSection("Auto Guard")

MainTab:CreateToggle({
    Name = "Auto Guard (Hold G to Activate)",
    CurrentValue = false,
    Flag = "AutoGuard",
    Callback = function(value)
        autoGuardToggleEnabled = value
        if not value then
            autoGuardEnabled = false
            if autoGuardConnection then autoGuardConnection:Disconnect(); autoGuardConnection = nil end
            lastPositions = {}
            game:GetService("VirtualInputManager"):SendKeyEvent(false, Enum.KeyCode.F, false, game)
        end
    end,
})

MainTab:CreateSlider({
    Name = "Guard Distance",
    Range = {5, 20},
    Increment = 1,
    Suffix = " studs",
    CurrentValue = 10,
    Flag = "GuardDistance",
    Callback = function(value)
        guardDistance = value
    end,
})

MainTab:CreateSlider({
    Name = "Prediction Time",
    Range = {1, 8},
    Increment = 1,
    Suffix = "x0.1s",
    CurrentValue = 3,
    Flag = "PredictionTime",
    Callback = function(value)
        predictionTime = value / 10
    end,
})

MainTab:CreateParagraph({
    Title = "Auto Guard Info",
    Content = "Hold G to activate. Predicts opponent movement and positions defensively while holding F."
})

-- Auto Rebound & Steal Section
local ReboundSection = MainTab:CreateSection("Auto Rebound & Steal")

MainTab:CreateToggle({
    Name = "Auto Rebound & Steal (Key: T)",
    CurrentValue = false,
    Flag = "AutoRebound",
    Callback = function(value)
        teleportEnabled = value
    end,
})

MainTab:CreateSlider({
    Name = "Rebound Offset Distance",
    Range = {0, 6},
    Increment = 1,
    Suffix = " studs",
    CurrentValue = 0,
    Flag = "ReboundOffset",
    Callback = function(value)
        offsetDistance = value
    end,
})

-- Follow Ball Carrier Section
local FollowSection = MainTab:CreateSection("Follow Ball Carrier")

MainTab:CreateToggle({
    Name = "Follow Ball Carrier (Key: H)",
    CurrentValue = false,
    Flag = "FollowBallCarrier",
    Callback = function(value)
        followEnabled = value
        if value then
            if not followConnection then
                followConnection = RunService.Heartbeat:Connect(function()
                    if not followEnabled then return end
                    local char = player.Character
                    if not char then return end
                    local hrp = char:FindFirstChild("HumanoidRootPart")
                    if not hrp then return end
                    local ballCarrier, ballCarrierRoot = findPlayerWithBall()
                    if ballCarrier and ballCarrierRoot then
                        local maxDist = isPark and 100 or math.huge
                        if (hrp.Position - ballCarrierRoot.Position).Magnitude <= maxDist then
                            hrp.CFrame = ballCarrierRoot.CFrame * CFrame.new(0, 0, followOffset)
                        end
                    end
                end)
            end
        else
            if followConnection then followConnection:Disconnect(); followConnection = nil end
        end
    end,
})

MainTab:CreateSlider({
    Name = "Follow Offset",
    Range = {-10, 10},
    Increment = 1,
    Suffix = " studs",
    CurrentValue = -10,
    Flag = "FollowOffset",
    Callback = function(value)
        followOffset = value
    end,
})

-- Reach Section
local ReachSection = MainTab:CreateSection("Steal Reach")

MainTab:CreateToggle({
    Name = "Steal Reach",
    CurrentValue = false,
    Flag = "StealReach",
    Callback = function(value)
        stealReachEnabled = value
        updateHitboxSizes()
    end,
})

MainTab:CreateSlider({
    Name = "Steal Reach Multiplier",
    Range = {1, 20},
    Increment = 1,
    Suffix = "x",
    CurrentValue = 2,
    Flag = "StealReachMultiplier",
    Callback = function(value)
        stealReachMultiplier = value
        if stealReachEnabled then updateHitboxSizes() end
    end,
})

-- Ball Magnet Section
local MagnetSection = MainTab:CreateSection("Ball Magnet")

MainTab:CreateToggle({
    Name = "Ball Magnet (Key: M)",
    CurrentValue = false,
    Flag = "BallMagnet",
    Callback = function(value)
        magnetEnabled = value
    end,
})

MainTab:CreateSlider({
    Name = "Magnet Distance",
    Range = {10, 85},
    Increment = 1,
    Suffix = " studs",
    CurrentValue = 30,
    Flag = "BallMagnetDistance",
    Callback = function(value)
        MagsDist = value
    end,
})

-- Post Aimbot Section
local PostSection = MainTab:CreateSection("Post Aimbot")

MainTab:CreateToggle({
    Name = "Post Aimbot (Hold P to Activate)",
    CurrentValue = false,
    Flag = "PostAimbot",
    Callback = function(value)
        postAimbotEnabled = value
        if not value then
            postHoldActive = false
            if postAimbotConnection then postAimbotConnection:Disconnect(); postAimbotConnection = nil end
        end
    end,
})

MainTab:CreateSlider({
    Name = "Post Activation Distance",
    Range = {5, 20},
    Increment = 1,
    Suffix = " studs",
    CurrentValue = 10,
    Flag = "PostActivationDistance",
    Callback = function(value)
        postActivationDistance = value
    end,
})

MainTab:CreateParagraph({
    Title = "Post Aimbot Info",
    Content = "Automatically detects which hand has the ball and posts accordingly. Hold P to activate."
})

-- ======= PLAYER TAB =======
local PlayerTab = Window:CreateTab("Player", 4483362458)

local SpeedSection = PlayerTab:CreateSection("Speed Boost")

PlayerTab:CreateToggle({
    Name = "Speed Boost",
    CurrentValue = false,
    Flag = "SpeedBoost",
    Callback = function(value)
        speedBoostEnabled = value
        if value then
            if speedBoostConnection then speedBoostConnection() end
            speedBoostConnection = startCFrameSpeed(desiredSpeed)
        else
            if speedBoostConnection then speedBoostConnection() end
            speedBoostConnection = nil
        end
    end,
})

PlayerTab:CreateSlider({
    Name = "Speed Amount",
    Range = {16, 23},
    Increment = 1,
    Suffix = " speed",
    CurrentValue = 16,
    Flag = "SpeedAmount",
    Callback = function(value)
        desiredSpeed = value
        if speedBoostEnabled then
            if speedBoostConnection then speedBoostConnection() end
            speedBoostConnection = startCFrameSpeed(desiredSpeed)
        end
    end,
})

-- ======= MISC TAB =======
local MiscTab = Window:CreateTab("Misc", 4483362458)

-- Visuals Section
local VisualsSection = MiscTab:CreateSection("Visuals")

MiscTab:CreateToggle({
    Name = "Show BodyGyro",
    CurrentValue = false,
    Flag = "ShowBG",
    Callback = function(value)
        if value then setBGVisibleToTrue() else hideBG() end
    end,
})

-- Animation Changer Section
local AnimSection = MiscTab:CreateSection("Animation Changer")

MiscTab:CreateToggle({
    Name = "Animation Changer",
    CurrentValue = false,
    Flag = "AnimSpoof",
    Callback = function(value)
        animationSpoofEnabled = value
        if value then enableAnimationSpoof() else disableAnimationSpoof() end
    end,
})

MiscTab:CreateDropdown({
    Name = "Dunk Animation",
    Options = {"Default", "Testing", "Testing2", "Reverse", "360", "Testing3", "Tomahawk", "Windmill"},
    CurrentOption = {"Default"},
    Flag = "DunkSpoof",
    Callback = function(option)
        selectedDunkAnim = option[1] or option
    end,
})

local EmoteAnimations = {
    "Dance_Casual", "Dance_Sturdy", "Dance_Taunt", "Dance_TakeFlight",
    "Dance_Flex", "Dance_Bat", "Dance_Twist", "Dance_Griddy",
    "Dance_Dab", "Dance_Drake", "Dance_Fresh", "Dance_Hype",
    "Dance_Spongebob", "Dance_Backflip", "Dance_L", "Dance_Facepalm",
    "Dance_Bow"
}

MiscTab:CreateDropdown({
    Name = "Emote Animation",
    Options = EmoteAnimations,
    CurrentOption = {"Dance_Casual"},
    Flag = "EmoteSpoof",
    Callback = function(option)
        selectedEmoteAnim = option[1] or option
    end,
})

-- Teleporter Section
local TeleportSection = MiscTab:CreateSection("Teleporter")

local Http = (syn and syn.request) or (http and http.request) or (fluxus and fluxus.request) or (request) or (http_request)
local placesList = {}
local loadingPlaces = false
local placeNames = {"Loading..."}

local PlaceDropdown = MiscTab:CreateDropdown({
    Name = "Select Place",
    Options = {"Loading..."},
    CurrentOption = {"Loading..."},
    Flag = "TeleportPlace",
    Callback = function() end,
})

local function loadPlaces()
    if loadingPlaces then return end
    loadingPlaces = true
    if not Http then
        placesList["Current Place"] = game.PlaceId
        PlaceDropdown:Set({"Current Place"})
        loadingPlaces = false
        return
    end
    local universeId = game.GameId
    local url = "https://develop.roblox.com/v1/universes/" .. universeId .. "/places?limit=100"
    local success, response = pcall(function()
        return Http({ Url = url, Method = "GET", Headers = { ["User-Agent"] = "Roblox/WinInet", ["Content-Type"] = "application/json" } })
    end)
    if success and response and response.Body then
        local ok, data = pcall(function() return HttpService:JSONDecode(response.Body) end)
        if ok and data and data.data then
            for _, place in ipairs(data.data) do
                if place.name and place.id then
                    local displayName = place.name .. (place.isRootPlace and " (Root)" or "")
                    placesList[displayName] = place.id
                end
            end
        end
    end
    placeNames = {}
    for name in pairs(placesList) do table.insert(placeNames, name) end
    table.sort(placeNames)
    if #placeNames == 0 then
        placesList["Current Place"] = game.PlaceId
        placeNames = {"Current Place"}
    end
    PlaceDropdown:Set({placeNames[1]})
    loadingPlaces = false
end

task.spawn(loadPlaces)

MiscTab:CreateButton({
    Name = "Teleport to Selected Place",
    Callback = function()
        local selected = Rayfield:GetFlag("TeleportPlace")
        if type(selected) == "table" then selected = selected[1] end
        local placeId = placesList[selected]
        if placeId then
            Rayfield:Notify({ Title = "Teleporting", Content = "Teleporting to " .. tostring(selected) .. "...", Duration = 3, Image = 4483362458 })
            TeleportService:Teleport(placeId)
        end
    end,
})

MiscTab:CreateButton({
    Name = "Rejoin Current Server",
    Callback = function()
        Rayfield:Notify({ Title = "Rejoining", Content = "Rejoining current server...", Duration = 3, Image = 4483362458 })
        TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, player)
    end,
})

MiscTab:CreateButton({
    Name = "Server Hop (Least Players)",
    Callback = function()
        Rayfield:Notify({ Title = "Server Hopping", Content = "Finding best server...", Duration = 3, Image = 4483362458 })
        local servers = {}
        local cursor = ""
        repeat
            local url = "https://games.roblox.com/v1/games/" .. tostring(game.PlaceId) .. "/servers/Public?sortOrder=Asc&limit=100&cursor=" .. cursor
            local ok, result = pcall(function() return game:HttpGet(url) end)
            if ok then
                local decoded = HttpService:JSONDecode(result)
                cursor = decoded.nextPageCursor or ""
                for _, server in pairs(decoded.data) do
                    if server.playing < server.maxPlayers and server.id ~= game.JobId then
                        table.insert(servers, server)
                    end
                end
            else break end
        until cursor == ""
        if #servers > 0 then
            table.sort(servers, function(a, b) return a.playing < b.playing end)
            TeleportService:TeleportToPlaceInstance(game.PlaceId, servers[1].id, player)
        else
            Rayfield:Notify({ Title = "Server Hop Failed", Content = "No available servers found.", Duration = 3, Image = 4483362458 })
        end
    end,
})

-- =====================
-- Unload cleanup
-- =====================

Rayfield:Destroy = function()
    if visibleConn then visibleConn:Disconnect() end
    if autoGuardConnection then autoGuardConnection:Disconnect() end
    if speedBoostConnection then speedBoostConnection() end
    if magnetConnection then magnetConnection:Disconnect() end
    if postAimbotConnection then postAimbotConnection:Disconnect() end
    if followConnection then followConnection:Disconnect() end
    disableAnimationSpoof()
end
