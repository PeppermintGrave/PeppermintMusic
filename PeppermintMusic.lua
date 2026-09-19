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
        Title = "Where the Daylight Ends",
        File = "where-the-daylight-ends.mp3"
    },
    {
        Title = "When You Still Knew Me",
        File = "when-you-still-knew-me.mp3"
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
        Title = "Where the Silence Grows",
        File = "where-the-silence-grows.mp3"
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
        warn("[PeppermintMusic] Your executor does not provide an HTTP request function.")
        return false
    end

    local success, response = pcall(function()
        return requestFunction({
            Url = url,
            Method = "GET"
        })
    end)

    if not success or not response then
        warn("[PeppermintMusic] Download request failed:", url)
        return false
    end

    if response.StatusCode and response.StatusCode ~= 200 then
        warn("[PeppermintMusic] HTTP error:", response.StatusCode, url)
        return false
    end

    local body = response.Body

    if not body then
        warn("[PeppermintMusic] Empty response:", url)
        return false
    end

    local writeSuccess = pcall(function()
        writefile(path, body)
    end)

    if not writeSuccess then
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

local function createGui()
    local oldGui = nil

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

        button.MouseEnter:Connect(function()
            TweenService:Create(
                button,
                TweenInfo.new(0.12),
                {
                    BackgroundColor3 = Color3.fromRGB(43, 47, 48),
                    TextColor3 = Color3.fromRGB(120, 240, 195)
                }
            ):Play()
        end)

        button.MouseLeave:Connect(function()
            TweenService:Create(
                button,
                TweenInfo.new(0.12),
                {
                    BackgroundColor3 = Color3.fromRGB(27, 29, 31),
                    TextColor3 = Color3.fromRGB(225, 228, 228)
                }
            ):Play()
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
    local dragInput = nil
    local dragStart = nil
    local startPosition = nil

    local function updateDrag(input)
        local delta = input.Position - dragStart

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
        local tween = TweenService:Create(
            mainFrame,
            TweenInfo.new(
                0.25,
                Enum.EasingStyle.Quad,
                Enum.EasingDirection.In
            ),
            {
                Position = UDim2.new(1, 20, 0, 20)
            }
        )

        tween:Play()

        tween.Completed:Connect(function()
            mainFrame.Visible = false
            openButton.Visible = true
        end)
    end

    local function openPlayer()
        openButton.Visible = false

        mainFrame.Position =
            UDim2.new(1, 20, 0, 20)

        mainFrame.Visible = true

        TweenService:Create(
            mainFrame,
            TweenInfo.new(
                0.3,
                Enum.EasingStyle.Quad,
                Enum.EasingDirection.Out
            ),
            {
                Position =
                    UDim2.new(1, -20, 0, 20)
            }
        ):Play()
    end

    previousButton.MouseButton1Click:Connect(function()
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
        TweenService:Create(
            openButton,
            TweenInfo.new(0.12),
            {
                BackgroundColor3 =
                    Color3.fromRGB(35, 40, 39)
            }
        ):Play()
    end)

    openButton.MouseLeave:Connect(function()
        TweenService:Create(
            openButton,
            TweenInfo.new(0.12),
            {
                BackgroundColor3 =
                    Color3.fromRGB(15, 16, 18)
            }
        ):Play()
    end)

    titleLabel.Text = "No song playing"
    playButton.Text = "▶"
end

createGui()

local function fadeVolume(target, duration)
    local tween = TweenService:Create(
        sound,
        TweenInfo.new(
            duration,
            Enum.EasingStyle.Linear,
            Enum.EasingDirection.Out
        ),
        {
            Volume = target
        }
    )

    tween:Play()
    tween.Completed:Wait()
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

        local downloaded = downloadFile(url, localPath)

        if not downloaded then
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

    local loaded = sound.IsLoaded

    if not loaded then
        local loadedConnection
        local loadedEvent = false

        loadedConnection = sound.Loaded:Connect(function()
            loadedEvent = true
        end)

        local startTime = os.clock()

        while not sound.IsLoaded and not loadedEvent do
            if os.clock() - startTime >= LOAD_TIMEOUT then
                break
            end

            task.wait(0.1)
        end

        if loadedConnection then
            loadedConnection:Disconnect()
        end
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
        local fadeOut = TweenService:Create(
            sound,
            TweenInfo.new(FADE_TIME),
            {
                Volume = 0
            }
        )

        fadeOut:Play()
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

    TweenService:Create(
        sound,
        TweenInfo.new(FADE_TIME),
        {
            Volume = DEFAULT_VOLUME
        }
    ):Play()

    loadingTrack = false
end

local function pauseMusic()
    if sound.IsPlaying then
        sound:Pause()

        setStatus(
            Tracks[currentIndex].Title,
            "Paused"
        )
    end
end

local function resumeMusic()
    if sound.SoundId == "" then
        playCurrent()
        return
    end

    if sound.TimePosition > 0 and not sound.IsPlaying then
        sound:Resume()

        TweenService:Create(
            sound,
            TweenInfo.new(FADE_TIME),
            {
                Volume = DEFAULT_VOLUME
            }
        ):Play()

        setStatus(
            Tracks[currentIndex].Title,
            "Playing"
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

setStatus("No song playing", "Stopped")
