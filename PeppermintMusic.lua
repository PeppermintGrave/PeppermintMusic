local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")

local BASE_URL = "https://raw.githubusercontent.com/PeppermintGrave/PeppermintMusic/main/audio/"
local CACHE_FOLDER = "PeppermintMusic"

local DEFAULT_VOLUME = 0.4
local FADE_TIME = 0.35
local LOAD_TIMEOUT = 15

local Tracks = {
    {
        Name = "Paper Moons",
        File = "paper-moons.mp3"
    },
    {
        Name = "Where the Daylight Ends",
        File = "where-the-daylight-ends.mp3"
    },
    {
        Name = "When You Still Knew Me",
        File = "when-you-still-knew-me.mp3"
    },
    {
        Name = "When the Night Learns Your Name",
        File = "when-the-night-learns-your-name.mp3"
    },
    {
        Name = "Old Notebook",
        File = "old-notebook.mp3"
    },
    {
        Name = "Where the Silence Grows",
        File = "where-the-silence-grows.mp3"
    },
    {
        Name = "From the Other Side of the Screen",
        File = "from-the-other-side-of-the-screen.mp3"
    },
    {
        Name = "Still Here",
        File = "still-here.mp3"
    },
    {
        Name = "Static Skies",
        File = "static-skies.mp3"
    },
    {
        Name = "Mosslight Drift",
        File = "mosslight-drift.mp3"
    }
}

local function getExecutorFunction(name)
    local success, result = pcall(function()
        return getgenv()[name]
    end)

    if success and type(result) == "function" then
        return result
    end

    local globalFunction = _G[name]

    if type(globalFunction) == "function" then
        return globalFunction
    end

    return nil
end

local writefileFn = getExecutorFunction("writefile")
local isfileFn = getExecutorFunction("isfile")
local getcustomassetFn = getExecutorFunction("getcustomasset")
local makefolderFn = getExecutorFunction("makefolder")
local isfolderFn = getExecutorFunction("isfolder")

local requestFn = getExecutorFunction("request")
    or getExecutorFunction("http_request")

if not requestFn and syn and type(syn.request) == "function" then
    requestFn = syn.request
end

if not writefileFn then
    error("PeppermintMusic: writefile() is not available in this Delta environment.")
end

if not isfileFn then
    error("PeppermintMusic: isfile() is not available in this Delta environment.")
end

if not getcustomassetFn then
    error("PeppermintMusic: getcustomasset() is not available in this Delta environment.")
end

if not requestFn then
    error("PeppermintMusic: HTTP request support is not available in this Delta environment.")
end

pcall(function()
    if isfolderFn and not isfolderFn(CACHE_FOLDER) then
        if makefolderFn then
            makefolderFn(CACHE_FOLDER)
        end
    end
end)

local oldSound = workspace:FindFirstChild("PeppermintMusic")

if oldSound then
    oldSound:Stop()
    oldSound:Destroy()
end

local sound = Instance.new("Sound")
sound.Name = "PeppermintMusic"
sound.Volume = 0
sound.Looped = false
sound.Parent = workspace

local currentTrackIndex = 1
local isPaused = false
local isLoading = false

local statusCallbacks = {}

local function updateStatus(status)
    for _, callback in ipairs(statusCallbacks) do
        task.spawn(function()
            pcall(callback, status)
        end)
    end
end

local function onStatus(callback)
    table.insert(statusCallbacks, callback)
end

local function fadeTo(volume)
    local tween = TweenService:Create(
        sound,
        TweenInfo.new(
            FADE_TIME,
            Enum.EasingStyle.Quad,
            Enum.EasingDirection.Out
        ),
        {
            Volume = volume
        }
    )

    tween:Play()
    return tween
end

local function getLocalPath(track)
    return CACHE_FOLDER .. "/" .. track.File
end

local function downloadTrack(track)
    local localPath = getLocalPath(track)

    if isfileFn(localPath) then
        return localPath
    end

    updateStatus("Downloading")

    local url = BASE_URL .. track.File

    local success, response = pcall(function()
        return requestFn({
            Url = url,
            Method = "GET"
        })
    end)

    if not success then
        warn("PeppermintMusic: HTTP request failed for " .. track.Name)
        warn(response)
        return nil
    end

    if not response then
        warn("PeppermintMusic: No response for " .. track.Name)
        return nil
    end

    local statusCode = tonumber(response.StatusCode or response.Status)

    if statusCode and statusCode ~= 200 then
        warn(
            "PeppermintMusic: GitHub returned HTTP "
            .. tostring(statusCode)
            .. " for "
            .. track.File
        )

        return nil
    end

    if type(response.Body) ~= "string" or #response.Body == 0 then
        warn("PeppermintMusic: GitHub returned empty data for " .. track.File)
        return nil
    end

    local successWrite, writeError = pcall(function()
        writefileFn(localPath, response.Body)
    end)

    if not successWrite then
        warn("PeppermintMusic: Could not save " .. track.File)
        warn(writeError)
        return nil
    end

    return localPath
end

local function getLocalAsset(track)
    local localPath = downloadTrack(track)

    if not localPath then
        return nil
    end

    local success, asset = pcall(function()
        return getcustomassetFn(localPath)
    end)

    if not success then
        warn("PeppermintMusic: getcustomasset() failed for " .. track.File)
        warn(asset)
        return nil
    end

    if not asset or asset == "" then
        warn("PeppermintMusic: No custom asset returned for " .. track.File)
        return nil
    end

    return asset
end

local function playTrack(index)
    if isLoading then
        return
    end

    local track = Tracks[index]

    if not track then
        return
    end

    isLoading = true
    isPaused = false

    currentTrackIndex = index

    updateStatus("Loading")

    fadeTo(0)
    sound:Stop()
    sound.SoundId = ""

    task.wait(0.1)

    local asset = getLocalAsset(track)

    if not asset then
        isLoading = false
        updateStatus("Error")
        return
    end

    sound.SoundId = asset

    local loaded = false

    local loadedConnection = sound.Loaded:Connect(function()
        loaded = true
    end)

    local startTime = os.clock()

    while not loaded and not sound.IsLoaded do
        if os.clock() - startTime >= LOAD_TIMEOUT then
            break
        end

        task.wait(0.1)
    end

    loadedConnection:Disconnect()

    if not sound.IsLoaded then
        isLoading = false
        updateStatus("Error")

        warn("PeppermintMusic: Roblox failed to load " .. track.Name)
        return
    end

    sound.Volume = 0
    sound:Play()

    isLoading = false

    updateStatus("Playing")
    fadeTo(DEFAULT_VOLUME)

    print("PeppermintMusic: Now playing - " .. track.Name)
end

local function pauseMusic()
    if isLoading then
        return
    end

    if sound.IsPlaying then
        sound:Pause()
        isPaused = true
        updateStatus("Paused")
    end
end

local function resumeMusic()
    if isLoading then
        return
    end

    if isPaused then
        sound:Resume()
        isPaused = false

        updateStatus("Playing")
        fadeTo(DEFAULT_VOLUME)
    end
end

local function playPause()
    if isLoading then
        return
    end

    if isPaused then
        resumeMusic()
    elseif sound.IsPlaying then
        pauseMusic()
    else
        playTrack(currentTrackIndex)
    end
end

local function nextTrack()
    if isLoading then
        return
    end

    local nextIndex = currentTrackIndex + 1

    if nextIndex > #Tracks then
        nextIndex = 1
    end

    playTrack(nextIndex)
end

local function previousTrack()
    if isLoading then
        return
    end

    local previousIndex = currentTrackIndex - 1

    if previousIndex < 1 then
        previousIndex = #Tracks
    end

    playTrack(previousIndex)
end

sound.Ended:Connect(function()
    if not isLoading then
        nextTrack()
    end
end)

local oldGui = CoreGui:FindFirstChild("PeppermintMusicGUI")

if oldGui then
    oldGui:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name = "PeppermintMusicGUI"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = CoreGui

local main = Instance.new("Frame")
main.Name = "MusicPlayer"
main.Size = UDim2.new(0.34, 0, 0.085, 0)
main.Position = UDim2.new(0.64, 0, 0.045, 0)
main.BackgroundColor3 = Color3.fromRGB(8, 12, 11)
main.BackgroundTransparency = 0.04
main.BorderSizePixel = 0
main.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = main

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(70, 255, 190)
stroke.Transparency = 0.45
stroke.Thickness = 1
stroke.Parent = main

local accent = Instance.new("Frame")
accent.Size = UDim2.new(0, 3, 0.65, 0)
accent.Position = UDim2.new(0, 0, 0.175, 0)
accent.BackgroundColor3 = Color3.fromRGB(70, 255, 190)
accent.BorderSizePixel = 0
accent.Parent = main

local accentCorner = Instance.new("UICorner")
accentCorner.CornerRadius = UDim.new(1, 0)
accentCorner.Parent = accent

local icon = Instance.new("TextLabel")
icon.BackgroundTransparency = 1
icon.Size = UDim2.new(0.12, 0, 0.55, 0)
icon.Position = UDim2.new(0.035, 0, 0.08, 0)
icon.Text = "♪"
icon.TextColor3 = Color3.fromRGB(110, 255, 205)
icon.TextScaled = true
icon.Font = Enum.Font.GothamBold
icon.Parent = main

local nowPlaying = Instance.new("TextLabel")
nowPlaying.BackgroundTransparency = 1
nowPlaying.Size = UDim2.new(0.43, 0, 0.22, 0)
nowPlaying.Position = UDim2.new(0.15, 0, 0.13, 0)
nowPlaying.Text = "NOW PLAYING"
nowPlaying.TextColor3 = Color3.fromRGB(110, 255, 205)
nowPlaying.TextScaled = true
nowPlaying.Font = Enum.Font.GothamBold
nowPlaying.TextXAlignment = Enum.TextXAlignment.Left
nowPlaying.Parent = main

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Size = UDim2.new(0.48, 0, 0.32, 0)
title.Position = UDim2.new(0.15, 0, 0.4, 0)
title.Text = "No song playing"
title.TextColor3 = Color3.fromRGB(235, 245, 241)
title.TextScaled = true
title.Font = Enum.Font.Gotham
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextTruncate = Enum.TextTruncate.AtEnd
title.Parent = main

local function createButton(text, position, size)
    local button = Instance.new("TextButton")
    button.BackgroundTransparency = 1
    button.Size = size
    button.Position = position
    button.Text = text
    button.TextColor3 = Color3.fromRGB(220, 235, 230)
    button.TextScaled = true
    button.Font = Enum.Font.GothamBold
    button.AutoButtonColor = false
    button.Parent = main

    button.MouseEnter:Connect(function()
        TweenService:Create(
            button,
            TweenInfo.new(0.12),
            {
                TextColor3 = Color3.fromRGB(100, 255, 200)
            }
        ):Play()
    end)

    button.MouseLeave:Connect(function()
        TweenService:Create(
            button,
            TweenInfo.new(0.12),
            {
                TextColor3 = Color3.fromRGB(220, 235, 230)
            }
        ):Play()
    end)

    return button
end

local previousButton = createButton(
    "‹",
    UDim2.new(0.64, 0, 0.22, 0),
    UDim2.new(0.08, 0, 0.56, 0)
)

local playButton = createButton(
    "▶",
    UDim2.new(0.74, 0, 0.22, 0),
    UDim2.new(0.09, 0, 0.56, 0)
)

local nextButton = createButton(
    "›",
    UDim2.new(0.84, 0, 0.22, 0),
    UDim2.new(0.08, 0, 0.56, 0)
)

local closeButton = createButton(
    "×",
    UDim2.new(0.94, 0, 0.12, 0),
    UDim2.new(0.05, 0, 0.35, 0)
)

local openButton = Instance.new("TextButton")
openButton.Size = UDim2.new(0, 42, 0, 42)
openButton.Position = UDim2.new(1, -55, 0, 20)
openButton.BackgroundColor3 = Color3.fromRGB(8, 12, 11)
openButton.BackgroundTransparency = 0.05
openButton.BorderSizePixel = 0
openButton.Text = "♪"
openButton.TextColor3 = Color3.fromRGB(110, 255, 205)
openButton.TextScaled = true
openButton.Font = Enum.Font.GothamBold
openButton.Visible = false
openButton.Parent = gui

local openCorner = Instance.new("UICorner")
openCorner.CornerRadius = UDim.new(1, 0)
openCorner.Parent = openButton

local openStroke = Instance.new("UIStroke")
openStroke.Color = Color3.fromRGB(70, 255, 190)
openStroke.Transparency = 0.4
openStroke.Parent = openButton

previousButton.MouseButton1Click:Connect(previousTrack)
nextButton.MouseButton1Click:Connect(nextTrack)
playButton.MouseButton1Click:Connect(playPause)

closeButton.MouseButton1Click:Connect(function()
    main.Visible = false
    openButton.Visible = true
end)

openButton.MouseButton1Click:Connect(function()
    openButton.Visible = false
    main.Visible = true
end)

onStatus(function(status)
    if status == "Playing" then
        title.Text = Tracks[currentTrackIndex].Name
        playButton.Text = "Ⅱ"

    elseif status == "Paused" then
        title.Text = Tracks[currentTrackIndex].Name
        playButton.Text = "▶"

    elseif status == "Loading" then
        title.Text = "Loading " .. Tracks[currentTrackIndex].Name
        playButton.Text = "..."

    elseif status == "Downloading" then
        title.Text = "Downloading " .. Tracks[currentTrackIndex].Name
        playButton.Text = "..."

    elseif status == "Error" then
        title.Text = "Audio failed to load"
        playButton.Text = "▶"
    end
end)

local dragging = false
local dragStart
local startPosition

local dragArea = Instance.new("Frame")
dragArea.BackgroundTransparency = 1
dragArea.Size = UDim2.new(0.6, 0, 1, 0)
dragArea.Position = UDim2.new(0, 0, 0, 0)
dragArea.Parent = main

dragArea.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then

        dragging = true
        dragStart = input.Position
        startPosition = main.Position
    end
end)

dragArea.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch then

        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if not dragging then
        return
    end

    if input.UserInputType ~= Enum.UserInputType.MouseMovement
        and input.UserInputType ~= Enum.UserInputType.Touch then
        return
    end

    local delta = input.Position - dragStart

    main.Position = UDim2.new(
        startPosition.X.Scale,
        startPosition.X.Offset + delta.X,
        startPosition.Y.Scale,
        startPosition.Y.Offset + delta.Y
    )
end)

print("PeppermintMusic loaded.")
print("10-track GitHub library ready.")
print("Press ▶ to download and play.")
