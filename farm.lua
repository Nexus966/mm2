local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")

local lp = Players.LocalPlayer
local char = lp.Character or lp.CharacterAdded:Wait()
local hrp = char:WaitForChild("HumanoidRootPart")
local hum = char:WaitForChild("Humanoid")

-- Settings
local safePosition = Vector3.new(500, -10, 500)
local safeCFrame = CFrame.new(safePosition) * CFrame.Angles(math.rad(90), 0, 0)

-- Adjustable speed settings
local moveSmoothness = 8000 
local verticalSpeed = 10 
local horizontalSpeed = 5 
local reachThreshold = 2

-- Stats
local coinsCollected = 0
local lastServerHopCheck = 0
local serverHopCooldown = 60 -- seconds

local bodyPos, bodyGyro
local currentTargetPosition = safePosition
local coinContainer = nil

-- Clean UI with coin counter
local function createUI()
    if lp.PlayerGui:FindFirstChild("CoinFarmUI") then
        lp.PlayerGui.CoinFarmUI:Destroy()
    end

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "CoinFarmUI"
    screenGui.Parent = lp.PlayerGui

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 200, 0, 80)
    frame.Position = UDim2.new(0.01, 0, 0.01, 0)
    frame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    frame.BorderSizePixel = 0
    frame.BackgroundTransparency = 0.3
    frame.Parent = screenGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = frame

    local title = Instance.new("TextLabel")
    title.Text = "COIN FARMER"
    title.Size = UDim2.new(1, 0, 0, 20)
    title.Position = UDim2.new(0, 0, 0, 5)
    title.BackgroundTransparency = 1
    title.TextColor3 = Color3.new(1, 1, 1)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 14
    title.Parent = frame

    local coinCounter = Instance.new("TextLabel")
    coinCounter.Name = "Thanks"
    coinCounter.Text = "Thanks For Using Roqate Scripts"
    coinCounter.Size = UDim2.new(1, 0, 0, 20)
    coinCounter.Position = UDim2.new(0, 0, 0, 30)
    coinCounter.BackgroundTransparency = 1
    coinCounter.TextColor3 = Color3.fromRGB(255, 215, 0) -- Gold color
    coinCounter.Font = Enum.Font.GothamMedium
    coinCounter.TextSize = 14
    coinCounter.Parent = frame

    local speedInfo = Instance.new("TextLabel")
    speedInfo.Name = "SpeedInfo"
    speedInfo.Text = string.format("Speed: H %.1f | V %.1f", horizontalSpeed, verticalSpeed)
    speedInfo.Size = UDim2.new(1, 0, 0, 20)
    speedInfo.Position = UDim2.new(0, 0, 0, 55)
    speedInfo.BackgroundTransparency = 1
    speedInfo.TextColor3 = Color3.new(1, 1, 1)
    speedInfo.Font = Enum.Font.GothamMedium
    speedInfo.TextSize = 12
    speedInfo.Parent = frame
end

local function updateUI()
    if not lp.PlayerGui:FindFirstChild("CoinFarmUI") then return end

    local ui = lp.PlayerGui.CoinFarmUI
    if ui:FindFirstChild("CoinCounter") then
        ui.CoinCounter.Text = "Coins: "..coinsCollected
    end
    if ui:FindFirstChild("SpeedInfo") then
        ui.SpeedInfo.Text = string.format("Speed: H %.1f | V %.1f", horizontalSpeed, verticalSpeed)
    end
end

local function setupNoclip()
    RunService.Stepped:Connect(function()
        if char then
            for _, v in ipairs(char:GetDescendants()) do
                if v:IsA("BasePart") then
                    v.CanCollide = false
                end
            end
        end
    end)
end

local function isInventoryFull()
    local gui = lp.PlayerGui
    for _, screenGui in ipairs(gui:GetDescendants()) do
        if (screenGui:IsA("TextLabel") or screenGui:IsA("TextButton")) and screenGui.Visible then
            local text = string.upper(screenGui.Text)
            if string.find(text, "FULL") or string.find(text, "MAX") then
                return true
            end
        end
    end
    return false
end

local function resetCharacter()
    lp.Character:BreakJoints()
    char = lp.CharacterAdded:Wait()
    hrp = char:WaitForChild("HumanoidRootPart")
    hum = char:WaitForChild("Humanoid")
    task.wait(1)
    setupCharacter()
end

local function setupCharacter()
    if bodyPos then bodyPos:Destroy() end
    if bodyGyro then bodyGyro:Destroy() end

    bodyPos = Instance.new("BodyPosition")
    bodyPos.MaxForce = Vector3.new(moveSmoothness, moveSmoothness, moveSmoothness)
    bodyPos.P = 10000
    bodyPos.D = 2000 
    bodyPos.Parent = hrp

    bodyGyro = Instance.new("BodyGyro")
    bodyGyro.MaxTorque = Vector3.new(1e6, 1e6, 1e6)
    bodyGyro.P = 8000
    bodyGyro.D = 500
    bodyGyro.Parent = hrp
    bodyGyro.CFrame = safeCFrame

    hum.PlatformStand = true
    setupNoclip()

    hrp.CFrame = safeCFrame
    bodyPos.Position = safePosition
end

local function isValidCoin(c)
    if not c:IsA("BasePart") then return false end
    if c.Transparency >= 0.9 then return false end
    if c:GetAttribute("Collected") == true then return false end
    return true
end

local function getValidCoins()
    local coins = {}
    
    -- First check inside CoinContainer if it exists
    if coinContainer then
        for _, obj in ipairs(coinContainer:GetDescendants()) do
            if obj.Name == "Coin_Server" and isValidCoin(obj) then
                table.insert(coins, obj)
            end
        end
    end
    
    -- Then check the rest of the workspace
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj.Name == "Coin_Server" and isValidCoin(obj) and not obj:IsDescendantOf(coinContainer) then
            table.insert(coins, obj)
        end
    end
    
    return coins
end

local function getClosestCoin()
    local coins = getValidCoins()
    local closest, dist = nil, math.huge
    for _, c in ipairs(coins) do
        local d = (hrp.Position - c.Position).Magnitude
        if d < dist then
            closest = c
            dist = d
        end
    end
    return closest
end

local function moveAndWait(targetPos)
    if isInventoryFull() then
        resetCharacter()
        return true
    end

    -- Apply speed multipliers based on movement direction
    local currentPos = hrp.Position
    local moveVector = (targetPos - currentPos)

    -- Calculate vertical and horizontal components
    local verticalMove = Vector3.new(0, moveVector.Y, 0)
    local horizontalMove = Vector3.new(moveVector.X, 0, moveVector.Z)

    -- Apply speed multipliers
    local adjustedMove = (horizontalMove * horizontalSpeed) + (verticalMove * verticalSpeed)
    local adjustedTarget = currentPos + adjustedMove

    bodyPos.Position = adjustedTarget

    local startTime = tick()
    while (hrp.Position - targetPos).Magnitude > reachThreshold and (tick() - startTime) < 5 do
        if isInventoryFull() then
            resetCharacter()
            return true
        end

        -- Recalculate adjusted position in case speeds changed during movement
        local currentPos = hrp.Position
        local moveVector = (targetPos - currentPos)
        local verticalMove = Vector3.new(0, moveVector.Y, 0)
        local horizontalMove = Vector3.new(moveVector.X, 0, moveVector.Z)
        local adjustedMove = (horizontalMove * horizontalSpeed) + (verticalMove * verticalSpeed)
        local adjustedTarget = currentPos + adjustedMove

        bodyPos.Position = adjustedTarget
        task.wait(0.05)
    end

    bodyPos.Position = hrp.Position
    return false
end

local function collectCoin(coin)
    local belowCoin = Vector3.new(coin.Position.X, coin.Position.Y - 10, coin.Position.Z)
    if moveAndWait(belowCoin) then return true end

    local atCoin = Vector3.new(coin.Position.X, coin.Position.Y, coin.Position.Z)
    if moveAndWait(atCoin) then return true end

    task.wait(0.15)
    coinsCollected = coinsCollected + 1
    updateUI()

    if moveAndWait(belowCoin) then return true end

    return false
end

local function shouldServerHop()
    -- Check if there are 4 or fewer players (excluding ourselves)
    if #Players:GetPlayers() <= 4 then
        -- Don't check more often than once per cooldown period
        if tick() - lastServerHopCheck > serverHopCooldown then
            lastServerHopCheck = tick()
            return true
        end
    end
    return false
end

local function serverHop()
    local PlaceId = game.PlaceId
    local JobId = game.JobId

    local servers = {}
    local success, result = pcall(function()
        local req = game:HttpGet("https://games.roblox.com/v1/games/" .. PlaceId .. "/servers/Public?sortOrder=Desc&limit=100&excludeFullGames=true")
        return HttpService:JSONDecode(req)
    end)

    if success and result and result.data then
        for i, v in next, result.data do
            if type(v) == "table" and tonumber(v.playing) and tonumber(v.maxPlayers) and v.playing < v.maxPlayers and v.id ~= JobId then
                table.insert(servers, 1, v.id)
            end
        end
    end

    if #servers > 0 then
        TeleportService:TeleportToPlaceInstance(PlaceId, servers[math.random(1, #servers)], Players.LocalPlayer)
    else
        warn("Serverhop: Couldn't find a server.")
    end
end

local function findCoinContainer()
    while true do
        -- Look for CoinContainer in workspace
        local container = Workspace:FindFirstChild("CoinContainer")
        if container then
            coinContainer = container
            -- Teleport to the container's position (adjust Y to be above it)
            local containerPos = container:GetPivot().Position
            currentTargetPosition = Vector3.new(containerPos.X, containerPos.Y + 20, containerPos.Z)
            bodyPos.Position = currentTargetPosition
            hrp.CFrame = CFrame.new(currentTargetPosition)
            break
        end
        task.wait(5) -- Check every 5 seconds
    end
end

local function startFarming()
    -- Start looking for CoinContainer in parallel
    task.spawn(findCoinContainer)
    
    while true do
        -- Check for server hop condition
        if shouldServerHop() then
            serverHop()
            task.wait(5) -- Wait a bit before continuing in case hop fails
        end

        if isInventoryFull() then
            resetCharacter()
            task.wait(2) 
        else
            local coin = getClosestCoin()
            if coin then
                if collectCoin(coin) then
                    task.wait(1)
                end
            else
                -- If no coins found, go to current target position (either safe spot or CoinContainer)
                if moveAndWait(currentTargetPosition) then
                    task.wait(1)
                else
                    task.wait(0.5)
                end
            end
        end
        task.wait(0.1)
    end
end

-- Keyboard controls for adjusting speed
local UserInputService = game:GetService("UserInputService")
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end

    if input.KeyCode == Enum.KeyCode.PageUp then
        verticalSpeed = math.min(verticalSpeed + 0.5, 10)
        horizontalSpeed = math.min(horizontalSpeed + 0.5, 10)
        updateUI()
    elseif input.KeyCode == Enum.KeyCode.PageDown then
        verticalSpeed = math.max(verticalSpeed - 0.5, 0.5)
        horizontalSpeed = math.max(horizontalSpeed - 0.5, 0.5)
        updateUI()
    end
end)

lp.CharacterAdded:Connect(function(newChar)
    char = newChar
    hrp = char:WaitForChild("HumanoidRootPart")
    hum = char:WaitForChild("Humanoid")
    setupCharacter()
    task.wait(1)
end)

-- Initialize
createUI()
setupCharacter()
task.wait(2)
startFarming()
