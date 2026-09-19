local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")

local player = Players.LocalPlayer

local BASE_URL = "https://raw.githubusercontent.com/PeppermintGrave/PeppermintMusic/main/audio/"
local CACHE_FOLDER = "PeppermintMusic"
local DEFAULT_VOLUME = 0.4
local FADE_TIME = 0.35
local LOAD_TIMEOUT = 20

local Tracks = {
    {
        Title = "Paper Moons",
        File = "paper-moons.mp3"
    },
    {
        Title = "When the Night Learns Your Name",
        File = "when-the-night-learns-your-name.mp3"
    },
    {
        Title = "Old Notebook",
        File = "old-notebook.mp3"
    },
    {
        Title = "When You Still Knew Me",
        File = "when-you-still-knew-me.mp3"
    },
    {
        Title = "Where the Silence Grows",
        File = "where-the-silence-grows.mp3"
    },
    {
        Title = "Where the Daylight Ends",
        File = "where-the-daylight-ends.mp3"
    },
    {
        Title = "From the Other Side of the Screen",
        File = "from-the-other-side-of-the-screen.mp3"
    },
    {
        Title = "Still Here",
        File = "still-here.mp3"
    },
    {
        Title = "Static Skies",
        File = "static-skies.mp3"
    },
    {
        Title = "Mosslight Drift",
        File = "mosslight-drift.mp3"
    }
}

local function getRequestFunction()
    if typeof(request) == "function" then
        return request
    end

    if typeof(http_request) == "function" then
        return http_request
    end

    if syn and typeof(syn.request) == "function" then
        return syn.request
    end

    return nil
end

local requestFunction = getRequestFunction()

local function ensureCacheFolder()
    if typeof(isfolder) == "function" and typeof(makefolder) == "function" then
        if not isfolder(CACHE_FOLDER) then
            makefolder(CACHE_FOLDER)
        end
    end
end

local function fileExists(path)
    if typeof(isfile) == "function" then
        return isfile(path)
    end

    return false
end

local function downloadFile(url, path)
    if fileExists(path) then
        return true
    end

    if not requestFunction then
        warn("[PeppermintMusic] HTTP request function unavailable.")
        return false
    end

    local success, response = pcall(function()
        return requestFunction({
            Url = url,
            Method = "GET"
        })
    end)

    if not success or not response then
        warn("[PeppermintMusic] Download failed:", url)
        return false
    end

    if response.StatusCode and response.StatusCode ~= 200 then
        warn("[PeppermintMusic] HTTP error:", response.StatusCode)
        return false
    end

    if not response.Body then
        warn("[PeppermintMusic] Empty response:", url)
        return false
    end

    local saved = pcall(function()
        writefile(path, response.Body)
    end)

    if not saved then
        warn("[PeppermintMusic] Could not save:", path)
        return false
    end

    return true
end

local function getAsset(path)
    if typeof(getcustomasset) == "function" then
        return getcustomasset(path)
    end

    if typeof(getsynasset) == "function" then
        return getsynasset(path)
    end

    return nil
end

ensureCacheFolder()

local oldSound = workspace:FindFirstChild("PeppermintMusic")

if oldSound then
    oldSound:Stop()
    oldSound:Destroy()
end

local sound = Instance.new("Sound")
sound.Name = "PeppermintMusic"
sound.Volume = DEFAULT_VOLUME
sound.Looped = false
sound.Parent = workspace

local currentIndex = 1
local currentState = "Stopped"
local loadingTrack = false
local changeToken = 0

local screenGui
local mainFrame
local titleLabel
local playButton
local icon
local openButton

local activeTweens = {}

local function playTween(object, info, properties, key)
    if key and activeTweens[key] then
        pcall(function()
            activeTweens[key]:Cancel()
        end)
    end

    local tween = TweenService:Create(object, info, properties)

    if key then
        activeTweens[key] = tween

        tween.Completed:Connect(function()
            if activeTweens[key] == tween then
                activeTweens[key] = nil
            end
        end)
    end

    tween:Play()

    return tween
end

local function setStatus(title, state)
    if not titleLabel or not titleLabel.Parent then
        return
    end

    titleLabel.Text = title

    if state == "Playing" then
        playButton.Text = "Ⅱ"
        icon.TextColor3 = Color3.fromRGB(120, 245, 195)

    elseif state == "Loading" then
        playButton.Text = "..."
        icon.TextColor3 = Color3.fromRGB(112, 235, 190)

    elseif state == "Paused" then
        playButton.Text = "▶"
        icon.TextColor3 = Color3.fromRGB(90, 180, 155)

    else
        playButton.Text = "▶"
        icon.TextColor3 = Color3.fromRGB(112, 170, 150)
    end

    currentState = state
end

local function showIntro()
    local oldIntro

    pcall(function()
        oldIntro = CoreGui:FindFirstChild("PeppermintMusicIntro")
    end)

    if oldIntro then
        oldIntro:Destroy()
    end

    local introGui = Instance.new("ScreenGui")

    introGui.Name = "PeppermintMusicIntro"
    introGui.ResetOnSpawn = false
    introGui.IgnoreGuiInset = true
    introGui.DisplayOrder = 999999

    local introParentSuccess = pcall(function()
        introGui.Parent = CoreGui
    end)

    if not introParentSuccess then
        introGui.Parent = player:WaitForChild("PlayerGui")
    end

    local container = Instance.new("Frame")

    container.Name = "IntroContainer"
    container.AnchorPoint = Vector2.new(0.5, 0.5)
    container.Position = UDim2.fromScale(0.5, 0.53)
    container.Size = UDim2.fromOffset(390, 150)
    container.BackgroundTransparency = 1
    container.Parent = introGui

    local aspect = Instance.new("UIAspectRatioConstraint")

    aspect.AspectRatio = 2.6
    aspect.AspectType = Enum.AspectType.ScaleWithParentSize
    aspect.DominantAxis = Enum.DominantAxis.Width
    aspect.Parent = container

    local panel = Instance.new("Frame")

    panel.Name = "IntroPanel"
    panel.Size = UDim2.fromScale(1, 1)
    panel.BackgroundColor3 = Color3.fromRGB(8, 11, 11)
    panel.BackgroundTransparency = 1
    panel.BorderSizePixel = 0
    panel.ClipsDescendants = true
    panel.Parent = container

    local corner = Instance.new("UICorner")

    corner.CornerRadius = UDim.new(0.08, 0)
    corner.Parent = panel

    local stroke = Instance.new("UIStroke")

    stroke.Color = Color3.fromRGB(55, 70, 66)
    stroke.Transparency = 1
    stroke.Thickness = 1
    stroke.Parent = panel

    local label = Instance.new("TextLabel")

    label.Name = "SmallLabel"
    label.BackgroundTransparency = 1
    label.Position = UDim2.new(0.08, 0, 0.16, 0)
    label.Size = UDim2.new(0.84, 0, 0.13, 0)

    label.Text = "Peppermint Music"
    label.TextColor3 = Color3.fromRGB(105, 225, 180)
    label.TextTransparency = 1

    label.Font = Enum.Font.Code
    label.TextScaled = true
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = panel

    local labelSize = Instance.new("UITextSizeConstraint")

    labelSize.MaxTextSize = 9
    labelSize.MinTextSize = 6
    labelSize.Parent = label

    local title = Instance.new("TextLabel")

    title.Name = "Title"
    title.BackgroundTransparency = 1
    title.Position = UDim2.new(0.08, 0, 0.30, 0)
    title.Size = UDim2.new(0.84, 0, 0.27, 0)

    title.Text = "A place for your music."
    title.TextColor3 = Color3.fromRGB(235, 241, 239)
    title.TextTransparency = 1

    title.Font = Enum.Font.GothamMedium
    title.TextScaled = true
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.TextYAlignment = Enum.TextYAlignment.Center
    title.Parent = panel

    local titleSize = Instance.new("UITextSizeConstraint")

    titleSize.MaxTextSize = 22
    titleSize.MinTextSize = 12
    titleSize.Parent = title

    local credit = Instance.new("TextLabel")

    credit.Name = "Credit"
    credit.BackgroundTransparency = 1
    credit.Position = UDim2.new(0.08, 0, 0.64, 0)
    credit.Size = UDim2.new(0.65, 0, 0.15, 0)

    credit.Text = "from PeppermintGrave"
    credit.TextColor3 = Color3.fromRGB(125, 140, 136)
    credit.TextTransparency = 1

    credit.Font = Enum.Font.Gotham
    credit.TextScaled = true
    credit.TextXAlignment = Enum.TextXAlignment.Left
    credit.Parent = panel

    local creditSize = Instance.new("UITextSizeConstraint")

    creditSize.MaxTextSize = 10
    creditSize.MinTextSize = 7
    creditSize.Parent = credit

    local loading = Instance.new("TextLabel")

    loading.Name = "Loading"
    loading.BackgroundTransparency = 1
    loading.Position = UDim2.new(0.73, 0, 0.64, 0)
    loading.Size = UDim2.new(0.19, 0, 0.15, 0)

    loading.Text = "Opening"
    loading.TextColor3 = Color3.fromRGB(90, 105, 101)
    loading.TextTransparency = 1

    loading.Font = Enum.Font.Code
    loading.TextScaled = true
    loading.TextXAlignment = Enum.TextXAlignment.Right
    loading.Parent = panel

    local loadingSize = Instance.new("UITextSizeConstraint")

    loadingSize.MaxTextSize = 8
    loadingSize.MinTextSize = 6
    loadingSize.Parent = loading

    local light = Instance.new("Frame")

    light.Name = "MovingLight"
    light.Size = UDim2.new(0.35, 0, 1.4, 0)
    light.Position = UDim2.new(-0.4, 0, -0.2, 0)
    light.Rotation = 12
    light.BackgroundColor3 = Color3.fromRGB(112, 235, 190)
    light.BackgroundTransparency = 0.94
    light.BorderSizePixel = 0
    light.Parent = panel

    local lightGradient = Instance.new("UIGradient")

    lightGradient.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1),
        NumberSequenceKeypoint.new(0.5, 0),
        NumberSequenceKeypoint.new(1, 1)
    })

    lightGradient.Parent = light

    local function introTween(object, duration, properties, style, direction)
        local animation = TweenService:Create(
            object,
            TweenInfo.new(
                duration,
                style or Enum.EasingStyle.Quart,
                direction or Enum.EasingDirection.Out
            ),
            properties
        )

        animation:Play()

        return animation
    end

    panel.Position = UDim2.new(0, 0, 0, 8)

    introTween(
        panel,
        0.75,
        {
            BackgroundTransparency = 0,
            Position = UDim2.new(0, 0, 0, 0)
        },
        Enum.EasingStyle.Quart,
        Enum.EasingDirection.Out
    )

    introTween(
        stroke,
        0.8,
        {
            Transparency = 0.72
        },
        Enum.EasingStyle.Quad,
        Enum.EasingDirection.Out
    )

    task.delay(0.12, function()
        if label.Parent then
            introTween(
                label,
                0.55,
                {
                    TextTransparency = 0
                }
            )
        end
    end)

    task.delay(0.24, function()
        if title.Parent then
            introTween(
                title,
                0.65,
                {
                    TextTransparency = 0
                }
            )
        end
    end)

    task.delay(0.40, function()
        if credit.Parent then
            introTween(
                credit,
                0.55,
                {
                    TextTransparency = 0
                }
            )
        end
    end)

    task.delay(0.46, function()
        if loading.Parent then
            introTween(
                loading,
                0.45,
                {
                    TextTransparency = 0
                }
            )
        end
    end)

    task.spawn(function()
        task.wait(0.65)

        if not light.Parent then
            return
        end

        local lightTween = introTween(
            light,
            2.4,
            {
                Position = UDim2.new(1.05, 0, -0.2, 0)
            },
            Enum.EasingStyle.Sine,
            Enum.EasingDirection.InOut
        )

        lightTween.Completed:Wait()
    end)

    task.wait(2.55)

    local fadeInfo = TweenInfo.new(
        0.65,
        Enum.EasingStyle.Quart,
        Enum.EasingDirection.In
    )

    local fadeAnimations = {
        TweenService:Create(
            panel,
            fadeInfo,
            {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 0, 0, -7)
            }
        ),

        TweenService:Create(
            stroke,
            fadeInfo,
            {
                Transparency = 1
            }
        ),

        TweenService:Create(
            label,
            fadeInfo,
            {
                TextTransparency = 1
            }
        ),

        TweenService:Create(
            title,
            fadeInfo,
            {
                TextTransparency = 1
            }
        ),

        TweenService:Create(
            credit,
            fadeInfo,
            {
                TextTransparency = 1
            }
        ),

        TweenService:Create(
            loading,
            fadeInfo,
            {
                TextTransparency = 1
            }
        )
    }

    for _, animation in ipairs(fadeAnimations) do
        animation:Play()
    end

    task.wait(0.7)

    if introGui and introGui.Parent then
        introGui:Destroy()
    end
end

local function createGameAudioButton()
    local oldButton

    pcall(function()
        oldButton = CoreGui:FindFirstChild("PeppermintGameAudioToggle")
    end)

    if oldButton then
        oldButton:Destroy()
    end

    local button = Instance.new("TextButton")

    button.Name = "PeppermintGameAudioToggle"
    button.Size = UDim2.fromOffset(42, 42)
    button.Position = UDim2.new(1, -20, 0, 82)
    button.AnchorPoint = Vector2.new(1, 0)

    button.BackgroundColor3 = Color3.fromRGB(15, 16, 18)
    button.BorderSizePixel = 0

    button.Text = "🔊"
    button.TextColor3 = Color3.fromRGB(110, 230, 185)

    button.Font = Enum.Font.GothamBold
    button.TextScaled = true
    button.AutoButtonColor = false

    button.Parent = screenGui

    local corner = Instance.new("UICorner")

    corner.CornerRadius = UDim.new(0.25, 0)
    corner.Parent = button

    local stroke = Instance.new("UIStroke")

    stroke.Color = Color3.fromRGB(55, 58, 62)
    stroke.Transparency = 0.3
    stroke.Thickness = 1
    stroke.Parent = button

    local textSize = Instance.new("UITextSizeConstraint")

    textSize.MaxTextSize = 18
    textSize.MinTextSize = 10
    textSize.Parent = button

    local gameAudioEnabled = true
    local savedVolumes = {}
    local volumeConnections = {}

    local dragging = false
    local dragInput
    local dragStart
    local startPosition
    local wasDragged = false

    local NORMAL_BG = Color3.fromRGB(15, 16, 18)
    local HOVER_BG = Color3.fromRGB(35, 40, 39)

    local MUTED_BG = Color3.fromRGB(30, 20, 21)
    local MUTED_HOVER_BG = Color3.fromRGB(48, 29, 31)

    local function isPeppermintSound(obj)
        return obj == sound or obj.Name == "PeppermintMusic"
    end

    local function removeVolumeConnection(obj)
        local connection = volumeConnections[obj]

        if connection then
            connection:Disconnect()
            volumeConnections[obj] = nil
        end
    end

    local function watchMutedSound(obj)
        if not obj:IsA("Sound") then
            return
        end

        if isPeppermintSound(obj) then
            return
        end

        if savedVolumes[obj] == nil then
            savedVolumes[obj] = obj.Volume
        end

        obj.Volume = 0

        if not volumeConnections[obj] then
            volumeConnections[obj] =
                obj:GetPropertyChangedSignal("Volume"):Connect(function()
                    if not gameAudioEnabled
                        and obj.Parent
                        and not isPeppermintSound(obj) then

                        if obj.Volume ~= 0 then
                            obj.Volume = 0
                        end
                    end
                end)
        end
    end

    local function restoreSound(obj)
        if not obj:IsA("Sound") then
            return
        end

        if isPeppermintSound(obj) then
            return
        end

        local originalVolume = savedVolumes[obj]

        removeVolumeConnection(obj)

        if originalVolume ~= nil and obj.Parent then
            obj.Volume = originalVolume
        end
    end

    local function muteAllGameAudio()
        for _, obj in ipairs(game:GetDescendants()) do
            if obj:IsA("Sound") and not isPeppermintSound(obj) then
                watchMutedSound(obj)
            end
        end
    end

    local function restoreAllGameAudio()
        for obj in pairs(savedVolumes) do
            if obj and obj.Parent then
                restoreSound(obj)
            else
                removeVolumeConnection(obj)
            end
        end
    end

    local function updateButton(hovering)
        if gameAudioEnabled then
            button.Text = "🔊"
            button.TextColor3 = Color3.fromRGB(110, 230, 185)

            playTween(
                button,
                TweenInfo.new(
                    0.18,
                    Enum.EasingStyle.Quad,
                    Enum.EasingDirection.Out
                ),
                {
                    BackgroundColor3 = hovering
                        and HOVER_BG
                        or NORMAL_BG
                },
                "gameAudioBackground"
            )
        else
            button.Text = "🔇"
            button.TextColor3 = Color3.fromRGB(230, 110, 110)

            playTween(
                button,
                TweenInfo.new(
                    0.18,
                    Enum.EasingStyle.Quad,
                    Enum.EasingDirection.Out
                ),
                {
                    BackgroundColor3 = hovering
                        and MUTED_HOVER_BG
                        or MUTED_BG
                },
                "gameAudioBackground"
            )
        end
    end

    button.MouseEnter:Connect(function()
        updateButton(true)

        playTween(
            button,
            TweenInfo.new(
                0.16,
                Enum.EasingStyle.Quad,
                Enum.EasingDirection.Out
            ),
            {
                Size = UDim2.fromOffset(44, 44)
            },
            "gameAudioSize"
        )
    end)

    button.MouseLeave:Connect(function()
        updateButton(false)

        playTween(
            button,
            TweenInfo.new(
                0.16,
                Enum.EasingStyle.Quad,
                Enum.EasingDirection.Out
            ),
            {
                Size = UDim2.fromOffset(42, 42)
            },
            "gameAudioSize"
        )
    end)

    button.MouseButton1Click:Connect(function()
        if wasDragged then
            wasDragged = false
            return
        end

        gameAudioEnabled = not gameAudioEnabled

        if gameAudioEnabled then
            restoreAllGameAudio()
        else
            muteAllGameAudio()
        end

        updateButton(false)

        playTween(
            button,
            TweenInfo.new(
                0.08,
                Enum.EasingStyle.Quad,
                Enum.EasingDirection.Out
            ),
            {
                Size = UDim2.fromOffset(39, 39)
            },
            "gameAudioClick"
        )

        task.delay(0.08, function()
            if button.Parent then
                playTween(
                    button,
                    TweenInfo.new(
                        0.16,
                        Enum.EasingStyle.Back,
                        Enum.EasingDirection.Out
                    ),
                    {
                        Size = UDim2.fromOffset(42, 42)
                    },
                    "gameAudioClick"
                )
            end
        end)
    end)

    local function updateDrag(input)
        local delta = input.Position - dragStart

        if math.abs(delta.X) > 3
            or math.abs(delta.Y) > 3 then

            wasDragged = true
        end

        button.Position = UDim2.new(
            startPosition.X.Scale,
            startPosition.X.Offset + delta.X,
            startPosition.Y.Scale,
            startPosition.Y.Offset + delta.Y
        )
    end

    button.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then

            dragging = true
            wasDragged = false
            dragStart = input.Position
            startPosition = button.Position

            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    button.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch then

            dragInput = input
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            updateDrag(input)
        end
    end)

    game.DescendantAdded:Connect(function(obj)
        if not gameAudioEnabled then
            if obj:IsA("Sound") and not isPeppermintSound(obj) then
                task.defer(function()
                    if obj.Parent and not gameAudioEnabled then
                        watchMutedSound(obj)
                    end
                end)
            end
        end
    end)

    button.AncestryChanged:Connect(function(_, parent)
        if parent then
            return
        end

        for obj, connection in pairs(volumeConnections) do
            connection:Disconnect()
            volumeConnections[obj] = nil
        end
    end)

    updateButton(false)
end

local function createGui()
    local oldGui

    pcall(function()
        oldGui = CoreGui:FindFirstChild("PeppermintMusicGUI")
    end)

    if oldGui then
        oldGui:Destroy()
    end

    screenGui = Instance.new("ScreenGui")

    screenGui.Name = "PeppermintMusicGUI"
    screenGui.ResetOnSpawn = false
    screenGui.IgnoreGuiInset = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    local parentSuccess = pcall(function()
        screenGui.Parent = CoreGui
    end)

    if not parentSuccess then
        screenGui.Parent = player:WaitForChild("PlayerGui")
    end

    mainFrame = Instance.new("Frame")

    mainFrame.Name = "MusicPlayer"
    mainFrame.Size = UDim2.new(0.34, 0, 0.085, 0)
    mainFrame.Position = UDim2.new(1, -20, 0, 20)
    mainFrame.AnchorPoint = Vector2.new(1, 0)

    mainFrame.BackgroundColor3 = Color3.fromRGB(15, 16, 18)
    mainFrame.BackgroundTransparency = 0.04
    mainFrame.BorderSizePixel = 0

    mainFrame.Parent = screenGui

    local aspect = Instance.new("UIAspectRatioConstraint")

    aspect.AspectRatio = 6.2
    aspect.AspectType = Enum.AspectType.ScaleWithParentSize
    aspect.DominantAxis = Enum.DominantAxis.Width
    aspect.Parent = mainFrame

    local corner = Instance.new("UICorner")

    corner.CornerRadius = UDim.new(0.18, 0)
    corner.Parent = mainFrame

    local stroke = Instance.new("UIStroke")

    stroke.Color = Color3.fromRGB(55, 58, 62)
    stroke.Transparency = 0.35
    stroke.Thickness = 1
    stroke.Parent = mainFrame

    local accent = Instance.new("Frame")

    accent.Size = UDim2.new(0, 3, 0.55, 0)
    accent.Position = UDim2.new(0, 7, 0.5, 0)
    accent.AnchorPoint = Vector2.new(0, 0.5)

    accent.BackgroundColor3 = Color3.fromRGB(100, 230, 180)
    accent.BorderSizePixel = 0
    accent.Parent = mainFrame

    local accentCorner = Instance.new("UICorner")

    accentCorner.CornerRadius = UDim.new(1, 0)
    accentCorner.Parent = accent

    icon = Instance.new("TextLabel")

    icon.Size = UDim2.new(0.075, 0, 0.72, 0)
    icon.Position = UDim2.new(0.035, 0, 0.5, 0)
    icon.AnchorPoint = Vector2.new(0, 0.5)

    icon.BackgroundColor3 = Color3.fromRGB(27, 30, 31)
    icon.BorderSizePixel = 0

    icon.Text = "♪"
    icon.TextColor3 = Color3.fromRGB(112, 235, 190)

    icon.Font = Enum.Font.GothamBold
    icon.TextScaled = true
    icon.Parent = mainFrame

    local iconCorner = Instance.new("UICorner")

    iconCorner.CornerRadius = UDim.new(0.25, 0)
    iconCorner.Parent = icon

    local iconSize = Instance.new("UITextSizeConstraint")

    iconSize.MaxTextSize = 17
    iconSize.MinTextSize = 9
    iconSize.Parent = icon

    local songArea = Instance.new("Frame")

    songArea.Size = UDim2.new(0.40, 0, 0.72, 0)
    songArea.Position = UDim2.new(0.125, 0, 0.14, 0)

    songArea.BackgroundTransparency = 1
    songArea.Parent = mainFrame

    local nowPlaying = Instance.new("TextLabel")

    nowPlaying.Size = UDim2.new(1, 0, 0.32, 0)
    nowPlaying.BackgroundTransparency = 1

    nowPlaying.Text = "NOW PLAYING"
    nowPlaying.TextColor3 = Color3.fromRGB(105, 225, 180)

    nowPlaying.TextXAlignment = Enum.TextXAlignment.Left
    nowPlaying.TextYAlignment = Enum.TextYAlignment.Center

    nowPlaying.Font = Enum.Font.GothamBold
    nowPlaying.TextScaled = true
    nowPlaying.Parent = songArea

    local nowPlayingSize = Instance.new("UITextSizeConstraint")

    nowPlayingSize.MaxTextSize = 7
    nowPlayingSize.MinTextSize = 5
    nowPlayingSize.Parent = nowPlaying

    titleLabel = Instance.new("TextLabel")

    titleLabel.Size = UDim2.new(1, 0, 0.6, 0)
    titleLabel.Position = UDim2.new(0, 0, 0.3, 0)

    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = "No song playing"
    titleLabel.TextColor3 = Color3.fromRGB(245, 245, 245)

    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.TextYAlignment = Enum.TextYAlignment.Center

    titleLabel.Font = Enum.Font.GothamMedium
    titleLabel.TextScaled = true
    titleLabel.TextTruncate = Enum.TextTruncate.AtEnd

    titleLabel.Parent = songArea

    local titleSize = Instance.new("UITextSizeConstraint")

    titleSize.MaxTextSize = 13
    titleSize.MinTextSize = 7
    titleSize.Parent = titleLabel

    local function createButton(name, symbol, x)
        local button = Instance.new("TextButton")

        button.Name = name
        button.Size = UDim2.new(0.085, 0, 0.58, 0)
        button.Position = UDim2.new(x, 0, 0.5, 0)
        button.AnchorPoint = Vector2.new(0.5, 0.5)

        button.BackgroundColor3 = Color3.fromRGB(27, 29, 31)
        button.BorderSizePixel = 0

        button.Text = symbol
        button.TextColor3 = Color3.fromRGB(225, 228, 228)

        button.Font = Enum.Font.GothamBold
        button.TextScaled = true
        button.AutoButtonColor = false

        button.Parent = mainFrame

        local buttonCorner = Instance.new("UICorner")

        buttonCorner.CornerRadius = UDim.new(0.28, 0)
        buttonCorner.Parent = button

        local textSize = Instance.new("UITextSizeConstraint")

        textSize.MaxTextSize = 14
        textSize.MinTextSize = 7
        textSize.Parent = button

        local normalSize = button.Size

        local hoverSize = UDim2.new(
            normalSize.X.Scale,
            normalSize.X.Offset + 2,
            normalSize.Y.Scale,
            normalSize.Y.Offset + 2
        )

        button.MouseEnter:Connect(function()
            playTween(
                button,
                TweenInfo.new(
                    0.14,
                    Enum.EasingStyle.Quad,
                    Enum.EasingDirection.Out
                ),
                {
                    BackgroundColor3 = Color3.fromRGB(43, 47, 48),
                    TextColor3 = Color3.fromRGB(120, 240, 195),
                    Size = hoverSize
                },
                "button_" .. name
            )
        end)

        button.MouseLeave:Connect(function()
            playTween(
                button,
                TweenInfo.new(
                    0.14,
                    Enum.EasingStyle.Quad,
                    Enum.EasingDirection.Out
                ),
                {
                    BackgroundColor3 = Color3.fromRGB(27, 29, 31),
                    TextColor3 = Color3.fromRGB(225, 228, 228),
                    Size = normalSize
                },
                "button_" .. name
            )
        end)

        button.MouseButton1Click:Connect(function()
            playTween(
                button,
                TweenInfo.new(
                    0.07,
                    Enum.EasingStyle.Quad,
                    Enum.EasingDirection.Out
                ),
                {
                    Size = UDim2.new(
                        normalSize.X.Scale,
                        normalSize.X.Offset - 1,
                        normalSize.Y.Scale,
                        normalSize.Y.Offset - 1
                    )
                },
                "click_" .. name
            )

            task.delay(0.07, function()
                if button.Parent then
                    playTween(
                        button,
                        TweenInfo.new(
                            0.14,
                            Enum.EasingStyle.Back,
                            Enum.EasingDirection.Out
                        ),
                        {
                            Size = normalSize
                        },
                        "click_" .. name
                    )
                end
            end)
        end)

        return button
    end

    local previousButton = createButton("Previous", "‹", 0.66)
    playButton = createButton("PlayPause", "▶", 0.76)
    local nextButton = createButton("Next", "›", 0.86)
    local closeButton = createButton("Close", "×", 0.95)

    local playStroke = Instance.new("UIStroke")

    playStroke.Color = Color3.fromRGB(90, 210, 170)
    playStroke.Transparency = 0.65
    playStroke.Thickness = 1
    playStroke.Parent = playButton

    local dragHandle = Instance.new("TextButton")

    dragHandle.Name = "DragHandle"
    dragHandle.Size = UDim2.new(0.60, 0, 1, 0)
    dragHandle.Position = UDim2.new(0, 0, 0, 0)

    dragHandle.BackgroundTransparency = 1
    dragHandle.BorderSizePixel = 0

    dragHandle.Text = ""
    dragHandle.AutoButtonColor = false
    dragHandle.ZIndex = 2
    dragHandle.Parent = mainFrame

    local dragging = false
    local dragInput
    local dragStart
    local startPosition
    local dragMoved = false

    local function updateDrag(input)
        local delta = input.Position - dragStart

        if math.abs(delta.X) > 3
            or math.abs(delta.Y) > 3 then

            dragMoved = true
        end

        mainFrame.Position = UDim2.new(
            startPosition.X.Scale,
            startPosition.X.Offset + delta.X,
            startPosition.Y.Scale,
            startPosition.Y.Offset + delta.Y
        )
    end

    dragHandle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then

            dragging = true
            dragMoved = false
            dragStart = input.Position
            startPosition = mainFrame.Position

            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    dragHandle.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch then

            dragInput = input
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            updateDrag(input)
        end
    end)

    openButton = Instance.new("TextButton")

    openButton.Name = "OpenMusicPlayer"
    openButton.Size = UDim2.fromOffset(42, 42)
    openButton.Position = UDim2.new(1, -20, 0, 20)
    openButton.AnchorPoint = Vector2.new(1, 0)

    openButton.BackgroundColor3 = Color3.fromRGB(15, 16, 18)
    openButton.BorderSizePixel = 0

    openButton.Text = "♪"
    openButton.TextColor3 = Color3.fromRGB(110, 230, 185)

    openButton.Font = Enum.Font.GothamBold
    openButton.TextScaled = true
    openButton.Visible = false

    openButton.Parent = screenGui

    local openCorner = Instance.new("UICorner")

    openCorner.CornerRadius = UDim.new(0.25, 0)
    openCorner.Parent = openButton

    local openStroke = Instance.new("UIStroke")

    openStroke.Color = Color3.fromRGB(55, 58, 62)
    openStroke.Transparency = 0.3
    openStroke.Thickness = 1
    openStroke.Parent = openButton

    local openSize = Instance.new("UITextSizeConstraint")

    openSize.MaxTextSize = 18
    openSize.MinTextSize = 10
    openSize.Parent = openButton

    local function closePlayer()
        if not mainFrame.Visible then
            return
        end

        local tween = playTween(
            mainFrame,
            TweenInfo.new(
                0.32,
                Enum.EasingStyle.Quart,
                Enum.EasingDirection.In
            ),
            {
                Position = UDim2.new(1, 20, 0, 20)
            },
            "mainFrame"
        )

        tween.Completed:Connect(function()
            if mainFrame.Parent then
                mainFrame.Visible = false
                openButton.Visible = true

                openButton.Size = UDim2.fromOffset(38, 38)

                playTween(
                    openButton,
                    TweenInfo.new(
                        0.28,
                        Enum.EasingStyle.Back,
                        Enum.EasingDirection.Out
                    ),
                    {
                        Size = UDim2.fromOffset(42, 42)
                    },
                    "openButton"
                )
            end
        end)
    end

    local function openPlayer()
        if mainFrame.Visible then
            return
        end

        openButton.Visible = false

        mainFrame.Position = UDim2.new(1, 20, 0, 20)
        mainFrame.Visible = true

        playTween(
            mainFrame,
            TweenInfo.new(
                0.38,
                Enum.EasingStyle.Quart,
                Enum.EasingDirection.Out
            ),
            {
                Position = UDim2.new(1, -20, 0, 20)
            },
            "mainFrame"
        )
    end

    previousButton.MouseButton1Click:Connect(function()
        if dragMoved then
            dragMoved = false
            return
        end

        if _G.PeppermintMusicPrevious then
            _G.PeppermintMusicPrevious()
        end
    end)

    nextButton.MouseButton1Click:Connect(function()
        if _G.PeppermintMusicNext then
            _G.PeppermintMusicNext()
        end
    end)

    playButton.MouseButton1Click:Connect(function()
        if _G.PeppermintMusicToggle then
            _G.PeppermintMusicToggle()
        end
    end)

    closeButton.MouseButton1Click:Connect(function()
        closePlayer()
    end)

    openButton.MouseButton1Click:Connect(function()
        openPlayer()
    end)

    openButton.MouseEnter:Connect(function()
        playTween(
            openButton,
            TweenInfo.new(
                0.14,
                Enum.EasingStyle.Quad,
                Enum.EasingDirection.Out
            ),
            {
                BackgroundColor3 = Color3.fromRGB(35, 40, 39),
                Size = UDim2.fromOffset(44, 44)
            },
            "openButtonHover"
        )
    end)

    openButton.MouseLeave:Connect(function()
        playTween(
            openButton,
            TweenInfo.new(
                0.14,
                Enum.EasingStyle.Quad,
                Enum.EasingDirection.Out
            ),
            {
                BackgroundColor3 = Color3.fromRGB(15, 16, 18),
                Size = UDim2.fromOffset(42, 42)
            },
            "openButtonHover"
        )
    end)

    titleLabel.Text = "No song playing"
    playButton.Text = "▶"

    createGameAudioButton()
end

local function loadTrack(index)
    local track = Tracks[index]

    if not track then
        return false
    end

    local localPath = CACHE_FOLDER .. "/" .. track.File
    local url = BASE_URL .. track.File

    if not fileExists(localPath) then
        setStatus(track.Title, "Loading")

        if not downloadFile(url, localPath) then
            setStatus("Download failed", "Stopped")
            return false
        end
    end

    local asset = getAsset(localPath)

    if not asset then
        setStatus("Asset loading failed", "Stopped")
        return false
    end

    sound:Stop()
    sound.SoundId = asset
    sound.TimePosition = 0
    sound.Volume = 0

    if not sound.IsLoaded then
        local loaded = false

        local connection = sound.Loaded:Connect(function()
            loaded = true
        end)

        local startTime = os.clock()

        while not sound.IsLoaded and not loaded do
            if os.clock() - startTime >= LOAD_TIMEOUT then
                break
            end

            task.wait(0.1)
        end

        connection:Disconnect()
    end

    if not sound.IsLoaded then
        setStatus("Audio failed to load", "Stopped")
        return false
    end

    return true
end

local function playCurrent()
    if loadingTrack then
        return
    end

    local track = Tracks[currentIndex]

    if not track then
        return
    end

    loadingTrack = true
    changeToken += 1

    local myToken = changeToken

    setStatus(track.Title, "Loading")

    if sound.IsPlaying then
        local fadeOut = playTween(
            sound,
            TweenInfo.new(
                FADE_TIME,
                Enum.EasingStyle.Quad,
                Enum.EasingDirection.Out
            ),
            {
                Volume = 0
            },
            "soundFade"
        )

        fadeOut.Completed:Wait()

        sound:Stop()
    end

    if myToken ~= changeToken then
        loadingTrack = false
        return
    end

    local success = loadTrack(currentIndex)

    if not success then
        loadingTrack = false
        return
    end

    if myToken ~= changeToken then
        loadingTrack = false
        return
    end

    sound.Volume = 0
    sound:Play()

    setStatus(track.Title, "Playing")

    playTween(
        sound,
        TweenInfo.new(
            FADE_TIME,
            Enum.EasingStyle.Quad,
            Enum.EasingDirection.Out
        ),
        {
            Volume = DEFAULT_VOLUME
        },
        "soundFade"
    )

    loadingTrack = false
end

local function pauseMusic()
    if sound.IsPlaying then
        playTween(
            sound,
            TweenInfo.new(
                0.16,
                Enum.EasingStyle.Quad,
                Enum.EasingDirection.Out
            ),
            {
                Volume = 0
            },
            "soundFade"
        )

        task.delay(0.16, function()
            if sound.Parent and currentState == "Playing" then
                sound:Pause()

                setStatus(
                    Tracks[currentIndex].Title,
                    "Paused"
                )
            end
        end)
    end
end

local function resumeMusic()
    if sound.SoundId == "" then
        playCurrent()
        return
    end

    if sound.TimePosition > 0 and not sound.IsPlaying then
        sound:Resume()

        setStatus(
            Tracks[currentIndex].Title,
            "Playing"
        )

        playTween(
            sound,
            TweenInfo.new(
                FADE_TIME,
                Enum.EasingStyle.Quad,
                Enum.EasingDirection.Out
            ),
            {
                Volume = DEFAULT_VOLUME
            },
            "soundFade"
        )
    else
        playCurrent()
    end
end

_G.PeppermintMusicToggle = function()
    if currentState == "Playing" then
        pauseMusic()

    elseif currentState == "Paused" then
        resumeMusic()

    else
        playCurrent()
    end
end

_G.PeppermintMusicNext = function()
    changeToken += 1

    currentIndex += 1

    if currentIndex > #Tracks then
        currentIndex = 1
    end

    playCurrent()
end

_G.PeppermintMusicPrevious = function()
    changeToken += 1

    currentIndex -= 1

    if currentIndex < 1 then
        currentIndex = #Tracks
    end

    playCurrent()
end

sound.Ended:Connect(function()
    if loadingTrack then
        return
    end

    currentIndex += 1

    if currentIndex > #Tracks then
        currentIndex = 1
    end

    task.spawn(function()
        playCurrent()
    end)
end)

showIntro()

createGui()

setStatus("No song playing", "Stopped")
