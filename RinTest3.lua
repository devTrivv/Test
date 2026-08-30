-- Serviços
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

-- Remote Function
local Event = ReplicatedStorage:FindFirstChild("Framework"):FindFirstChild("Features"):FindFirstChild("BrainrotSystem"):FindFirstChild("BrainrotUtil"):FindFirstChild("RemoteFunction")

-- Flags de controle
local isHoldingUnit = false
local isProcessing = false
local autoMergeEnabled = true
local lastProcessTime = 0
local processInterval = 0.05 -- Otimizado: processa a cada 50ms em vez de 1ms

-- Função para obter o tipo da unidade
local function getUnitType(unitName)
    return string.match(unitName, "^([A-Za-z]+)")
end

-- Função para verificar se uma unidade existe
local function findUnit(unitName, unitsFolder)
    for _, unit in ipairs(unitsFolder:GetChildren()) do
        if unit.Name == unitName then
            return unit
        end
    end
    return nil
end

-- Função para soltar unidade
local function dropUnit()
    pcall(function()
        Event:InvokeServer("PickUpPlot", "DropUnit")
    end)
    isHoldingUnit = false
end

-- Processa uma plot específica
local function processPlot(plotNumber)
    if isProcessing or not autoMergeEnabled then return end
    
    local plots = Workspace:FindFirstChild("Plots")
    if not plots then return end
    
    local plot = plots:FindFirstChild(tostring(plotNumber))
    if not plot then return end
    
    local owner = plot:FindFirstChild("Owner")
    if not owner or not owner:IsA("ObjectValue") or owner.Value ~= player then return end
    
    local unitsFolder = plot:FindFirstChild("Units")
    if not unitsFolder then return end
    
    if isHoldingUnit then
        dropUnit()
    end
    
    local unitsByType = {}
    
    for _, unit in ipairs(unitsFolder:GetChildren()) do
        local unitType = getUnitType(unit.Name)
        if unitType then
            if not unitsByType[unitType] then
                unitsByType[unitType] = {}
            end
            table.insert(unitsByType[unitType], unit.Name)
        end
    end
    
    for unitType, unitCodes in pairs(unitsByType) do
        if #unitCodes >= 2 then
            isProcessing = true
            local baseUnit = unitCodes[1]
            
            pcall(function()
                Event:InvokeServer("PickUpPlot", baseUnit)
            end)
            isHoldingUnit = true
            
            for i = 2, #unitCodes do
                local targetUnit = unitCodes[i]
                if findUnit(targetUnit, unitsFolder) then
                    pcall(function()
                        Event:InvokeServer("MergePlot", baseUnit, targetUnit)
                    end)
                end
            end
            
            dropUnit()
            isProcessing = false
        end
    end
end

-- Processa todas as plots
local function processAllPlots()
    if isProcessing or not autoMergeEnabled then return end
    
    local plots = Workspace:FindFirstChild("Plots")
    if not plots then return end
    
    if isHoldingUnit then
        dropUnit()
    end
    
    for _, plot in ipairs(plots:GetChildren()) do
        local owner = plot:FindFirstChild("Owner")
        if owner and owner:IsA("ObjectValue") and owner.Value == player then
            processPlot(plot.Name)
        end
    end
end

-- Loop otimizado
task.spawn(function()
    while true do
        if autoMergeEnabled then
            local currentTime = tick()
            if currentTime - lastProcessTime >= processInterval then
                processAllPlots()
                lastProcessTime = currentTime
            end
        end
        task.wait(0.01)
    end
end)

-- Auto-detecção de novas unidades (apenas reage quando adicionadas)
local function setupUnitDetection()
    local plots = Workspace:FindFirstChild("Plots")
    if not plots then return end
    
    for _, plot in ipairs(plots:GetChildren()) do
        local unitsFolder = plot:FindFirstChild("Units")
        if unitsFolder then
            unitsFolder.ChildAdded:Connect(function()
                if autoMergeEnabled and not isProcessing then
                    processPlot(plot.Name)
                end
            end)
        end
    end
end

setupUnitDetection()

-- Comando no chat
player.Chatted:Connect(function(message)
    if message:lower() == "mergetudo" or message:lower() == "m" then
        processAllPlots()
    end
end)

-- Processamento inicial
task.wait(1)
processAllPlots()

-- Criar GUI
local function createGUI()
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "X Videos"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.Parent = player:WaitForChild("PlayerGui")
    
    -- Frame principal (posicionado na esquerda-meio)
    local MainFrame = Instance.new("Frame")
    MainFrame.Name = "MainFrame"
    MainFrame.Size = UDim2.new(0, 250, 0, 120)
    MainFrame.Position = UDim2.new(0, 20, 0.5, -60)
    MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    MainFrame.BackgroundTransparency = 0
    MainFrame.BorderSizePixel = 0
    MainFrame.Active = true
    MainFrame.Parent = ScreenGui
    
    local UICorner = Instance.new("UICorner")
    UICorner.CornerRadius = UDim.new(0, 12)
    UICorner.Parent = MainFrame
    
    -- Container para título
    local TopBar = Instance.new("Frame")
    TopBar.Name = "TopBar"
    TopBar.Size = UDim2.new(1, 0, 0, 40)
    TopBar.Position = UDim2.new(0, 0, 0, 0)
    TopBar.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    TopBar.BackgroundTransparency = 0
    TopBar.BorderSizePixel = 0
    TopBar.Parent = MainFrame
    
    local TopBarCorner = Instance.new("UICorner")
    TopBarCorner.CornerRadius = UDim.new(0, 12)
    TopBarCorner.Parent = TopBar
    
    -- Título "X videos"
    local Title = Instance.new("TextLabel")
    Title.Name = "Title"
    Title.Size = UDim2.new(1, -70, 1, 0)
    Title.Position = UDim2.new(0, 35, 0, 0)
    Title.BackgroundTransparency = 1
    Title.Font = Enum.Font.GothamBold
    Title.TextSize = 22
    Title.RichText = true
    Title.Text = '<font color="#FF0000">X</font> <font color="#FFFFFF">videos</font>'
    Title.TextXAlignment = Enum.TextXAlignment.Center
    Title.TextYAlignment = Enum.TextYAlignment.Center
    Title.Parent = TopBar
    
    -- Minimizar botão
    local MinimizeButton = Instance.new("TextButton")
    MinimizeButton.Name = "MinimizeButton"
    MinimizeButton.Size = UDim2.new(0, 30, 0, 30)
    MinimizeButton.Position = UDim2.new(1, -38, 0, 5)
    MinimizeButton.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    MinimizeButton.BorderSizePixel = 0
    MinimizeButton.Text = "—"
    MinimizeButton.TextSize = 18
    MinimizeButton.Font = Enum.Font.GothamBold
    MinimizeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    MinimizeButton.ZIndex = 2
    MinimizeButton.Parent = TopBar
    
    local MinimizeCorner = Instance.new("UICorner")
    MinimizeCorner.CornerRadius = UDim.new(0, 6)
    MinimizeCorner.Parent = MinimizeButton
    
    -- Toggle Auto Merge
    local ToggleButton = Instance.new("TextButton")
    ToggleButton.Name = "AutoMergeToggle"
    ToggleButton.Size = UDim2.new(1, -20, 0, 30)
    ToggleButton.Position = UDim2.new(0, 10, 0, 50)
    ToggleButton.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
    ToggleButton.BorderSizePixel = 0
    ToggleButton.Text = "Auto Merge: ON"
    ToggleButton.TextSize = 14
    ToggleButton.Font = Enum.Font.GothamBold
    ToggleButton.TextColor3 = Color3.fromRGB(0, 0, 0)
    ToggleButton.ZIndex = 2
    ToggleButton.Parent = MainFrame
    
    local ButtonCorner = Instance.new("UICorner")
    ButtonCorner.CornerRadius = UDim.new(0, 6)
    ButtonCorner.Parent = ToggleButton
    
    -- Rodapé com créditos
    local FooterBar = Instance.new("Frame")
    FooterBar.Name = "FooterBar"
    FooterBar.Size = UDim2.new(1, 0, 0, 30)
    FooterBar.Position = UDim2.new(0, 0, 1, -30)
    FooterBar.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    FooterBar.BackgroundTransparency = 0
    FooterBar.BorderSizePixel = 0
    FooterBar.Parent = MainFrame
    
    local FooterCorner = Instance.new("UICorner")
    FooterCorner.CornerRadius = UDim.new(0, 12)
    FooterCorner.Parent = FooterBar
    
    -- Créditos
    local Credits = Instance.new("TextLabel")
    Credits.Name = "Credits"
    Credits.Size = UDim2.new(1, 0, 1, 0)
    Credits.Position = UDim2.new(0, 0, 0, 0)
    Credits.BackgroundTransparency = 1
    Credits.Font = Enum.Font.Gotham
    Credits.TextSize = 11
    Credits.Text = "made by pablo"
    Credits.TextColor3 = Color3.fromRGB(150, 150, 150)
    Credits.TextXAlignment = Enum.TextXAlignment.Center
    Credits.TextYAlignment = Enum.TextYAlignment.Center
    Credits.ZIndex = 1
    Credits.Parent = FooterBar
    
    -- Toggle função
    ToggleButton.MouseButton1Click:Connect(function()
        autoMergeEnabled = not autoMergeEnabled
        if autoMergeEnabled then
            ToggleButton.Text = "Auto Merge: ON"
            ToggleButton.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
            ToggleButton.TextColor3 = Color3.fromRGB(0, 0, 0)
        else
            ToggleButton.Text = "Auto Merge: OFF"
            ToggleButton.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
            ToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        end
    end)
    
    -- Sistema de minimizar
    local isMinimized = false
    MinimizeButton.MouseButton1Click:Connect(function()
        isMinimized = not isMinimized
        if isMinimized then
            ToggleButton.Visible = false
            FooterBar.Visible = false
            MainFrame.Size = UDim2.new(0, 250, 0, 40)
            MinimizeButton.Text = "+"
        else
            ToggleButton.Visible = true
            FooterBar.Visible = true
            MainFrame.Size = UDim2.new(0, 250, 0, 120)
            MinimizeButton.Text = "—"
        end
    end)
    
    -- Sistema de arrasto para MOBILE (Touch)
    local dragging = false
    local dragStart = nil
    local startPos = nil
    
    TopBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = MainFrame.Position
        end
    end)
    
    TopBar.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.Touch then
            local delta = input.Position - dragStart
            MainFrame.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end)
    
    TopBar.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
end

createGUI()

print("Auto-Merge OTIMIZADO E SUPER RÁPIDO ativado!")
print("GUI 'X videos' criada na esquerda-meio!")
print("Toggle Auto Merge: ON/OFF disponível")
print("GUI arrastável com TOUCH e minimizável")
print("Digite 'm' para mesclar manualmente")