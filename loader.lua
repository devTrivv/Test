local DELAY_APOS_ROLL = 0.05
local USAR_PLAYER_GUI = true
local MAX_ITENS = 400

local NOME_ARQUIVO          = "reroll_quirk_config.json"
local NOME_ARQUIVO_AUTOLOAD = "reroll_quirk_autoload.json"
local AUTO_RECONNECT        = true
local TEMPO_RECONNECT       = 5
local MAX_PASSADAS          = 20

local CORES = {
    fundo          = Color3.fromRGB(24, 24, 36),
    fundo2         = Color3.fromRGB(30, 30, 46),
    fundo3         = Color3.fromRGB(38, 38, 58),
    borda          = Color3.fromRGB(70, 70, 110),
    primaria       = Color3.fromRGB(130, 100, 220),
    primariaClara  = Color3.fromRGB(160, 130, 255),
    verde          = Color3.fromRGB(85, 220, 120),
    verdeClaro     = Color3.fromRGB(140, 255, 170),
    verdeTexto     = Color3.fromRGB(15, 40, 20),
    vermelho       = Color3.fromRGB(220, 70, 90),
    amarelo        = Color3.fromRGB(255, 200, 90),
    texto          = Color3.fromRGB(235, 235, 250),
    textoFraco     = Color3.fromRGB(150, 150, 180),
    verdeLabel     = Color3.fromRGB(120, 255, 150),
}

local Scroll = nil

local function Log(msg)
    pcall(function() print("[REROLL] " .. tostring(msg)) end)
end

Log("🚀 Script iniciado!")

local ERROS = {}
local function LogErro(contexto, err)
    local msg = string.format("[%s] %s", contexto, tostring(err))
    table.insert(ERROS, msg)
    if #ERROS > 50 then table.remove(ERROS, 1) end
    Log("⚠️ " .. msg)
end

local function SafeCall(nome, fn, ...)
    local ok, res = pcall(fn, ...)
    if not ok then LogErro(nome, res) end
    return ok, res
end

local ReplicatedStorage, Players, VirtualUser, CoreGui, TeleportService, TweenService, UserInputService, RunService
SafeCall("GetService", function()
    ReplicatedStorage = game:GetService("ReplicatedStorage")
    Players = game:GetService("Players")
    VirtualUser = game:GetService("VirtualUser")
    CoreGui = game:GetService("CoreGui")
    TeleportService = game:GetService("TeleportService")
    TweenService = game:GetService("TweenService")
    UserInputService = game:GetService("UserInputService")
    RunService = game:GetService("RunService")
end)

if not ReplicatedStorage then Log("❌ ReplicatedStorage indisponível!") return end

local LocalPlayer
SafeCall("LocalPlayer", function()
    LocalPlayer = Players.LocalPlayer
end)

if not LocalPlayer then Log("❌ LocalPlayer indisponível!") return end

Log("✅ Serviços carregados")

if AUTO_RECONNECT then
    SafeCall("AutoReconnect", function()
        local PlaceId = game.PlaceId
        local JobId = game.JobId

        task.spawn(function()
            while task.wait(TEMPO_RECONNECT) do
                pcall(function()
                    if not LocalPlayer or not LocalPlayer.Parent then
                        pcall(function() TeleportService:TeleportToPlaceInstance(PlaceId, JobId, LocalPlayer) end)
                        task.wait(3)
                        pcall(function() TeleportService:Teleport(PlaceId, LocalPlayer) end)
                    end
                end)
            end
        end)

        task.spawn(function()
            local ultimoHeartbeat = tick()
            RunService.Heartbeat:Connect(function() ultimoHeartbeat = tick() end)
            while task.wait(3) do
                if tick() - ultimoHeartbeat > 15 then
                    pcall(function() TeleportService:TeleportToPlaceInstance(PlaceId, JobId, LocalPlayer) end)
                    task.wait(5)
                end
            end
        end)
    end)
end

local RollEvent = nil
local function ReconectarRoll()
    local ok, ev = pcall(function()
        return ReplicatedStorage.Network.QuirkService.RE.Roll
    end)
    if ok and ev then RollEvent = ev; return true end
    return false
end
ReconectarRoll()
if not RollEvent then Log("❌ Evento Roll não encontrado!") return end
Log("✅ Evento Roll encontrado!")

SafeCall("AntiAFK", function()
    if LocalPlayer then
        LocalPlayer.Idled:Connect(function()
            pcall(function()
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.new())
            end)
        end)
    end
end)

task.spawn(function()
    while task.wait(60) do
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end)
    end
end)
Log("✅ Anti-AFK ativado!")

local function SerializarConfig(quirks, locks, selecionadosSet)
    local partes = { "{" }
    table.insert(partes, '"quirks":{')
    local quirkParts = {}
    for nome, marcada in pairs(quirks) do
        table.insert(quirkParts, string.format('["%s"]=%s', nome:gsub('"', '\\"'), tostring(marcada)))
    end
    table.insert(partes, table.concat(quirkParts, ","))
    table.insert(partes, '},"locks":{')
    local lockParts = {}
    for nome, travada in pairs(locks) do
        table.insert(lockParts, string.format('["%s"]=%s', nome:gsub('"', '\\"'), tostring(travada)))
    end
    table.insert(partes, table.concat(lockParts, ","))
    table.insert(partes, '},"selecionados":[')
    local selParts = {}
    for cod in pairs(selecionadosSet) do
        table.insert(selParts, string.format('"%s"', cod))
    end
    table.insert(partes, table.concat(selParts, ","))
    table.insert(partes, "]}")
    return table.concat(partes, "")
end

local function SalvarConfig(quirks, locks, selecionadosSet)
    if not writefile then return false, "Sem writefile" end
    local json = SerializarConfig(quirks, locks, selecionadosSet)
    local ok, err = pcall(writefile, NOME_ARQUIVO, json)
    if not ok then return false, tostring(err) end
    return true
end

local function CarregarConfig()
    local resultado = { quirks = {}, locks = {}, selecionados = {} }
    if not readfile or not isfile then return resultado, false, "Sem readfile" end
    local ok, existe = pcall(isfile, NOME_ARQUIVO)
    if not ok or not existe then return resultado, false, "Nenhum save" end
    local ok2, conteudo = pcall(readfile, NOME_ARQUIVO)
    if not ok2 or not conteudo then return resultado, false, "Falha ao ler" end

    local quirksBloco = conteudo:match('"quirks":{(.-)}')
    if quirksBloco then
        for chave, valor in quirksBloco:gmatch('%["(.-)"%]%s*=%s*(%a+)') do
            resultado.quirks[chave] = (valor == "true")
        end
    end
    local locksBloco = conteudo:match('"locks":{(.-)}')
    if locksBloco then
        for chave, valor in locksBloco:gmatch('%["(.-)"%]%s*=%s*(%a+)') do
            resultado.locks[chave] = (valor == "true")
        end
    end
    local selBloco = conteudo:match('"selecionados":%[(.-)%]')
    if selBloco and selBloco ~= "" then
        for cod in selBloco:gmatch('"([^"]+)"') do
            table.insert(resultado.selecionados, cod)
        end
    end
    return resultado, true
end

local autoLoadAtivo = false

local function SalvarAutoLoadFlag(valor)
    if not writefile then return end
    pcall(writefile, NOME_ARQUIVO_AUTOLOAD, valor and "true" or "false")
end

local function LerAutoLoadFlag()
    if not readfile or not isfile then return false end
    local ok, existe = pcall(isfile, NOME_ARQUIVO_AUTOLOAD)
    if not ok or not existe then return false end
    local ok2, conteudo = pcall(readfile, NOME_ARQUIVO_AUTOLOAD)
    if not ok2 or not conteudo then return false end
    return conteudo:gsub("%s", "") == "true"
end

Log("🔍 Buscando matriz de Units...")

local function EhValida(tab)
    if type(tab) ~= "table" then return false end
    if tab == _G or tab == shared or tab == game then return false end
    local ok, mt = pcall(getmetatable, tab)
    if ok and mt then
        if type(mt) == "string" then return false end
        if type(mt) == "table" then
            local ok2, idx = pcall(rawget, mt, "__index")
            if ok2 and idx then return false end
            local ok3, s = pcall(tostring, mt)
            if ok3 and s and (s:match("Connection") or s:match("Signal")) then return false end
        end
    end
    return true
end

local function ContarUnits(tab)
    local totalUnits = 0
    pcall(function()
        local contador = 0
        for k, v in pairs(tab) do
            contador = contador + 1
            if contador > 1000 then return end

            if type(v) == "table" then
                local ehUnit = false
                pcall(function()
                    for k2, v2 in pairs(v) do
                        if tostring(k2):lower() == "kind" and tostring(v2) == "Unit" then
                            ehUnit = true
                            return
                        end
                    end
                end)
                if ehUnit then
                    totalUnits = totalUnits + 1
                end
            end
        end
    end)
    return totalUnits
end

local function BuscarMatriz()
    local candidatos = {}

    Log("🔍 Procurando matriz de Units (filtro: 50-250)...")

    pcall(function()
        for _, obj in pairs(getgc(true)) do
            if EhValida(obj) then
                local units = ContarUnits(obj)
                if units >= 50 and units <= 250 then
                    table.insert(candidatos, {
                        tabela = obj,
                        units = units
                    })
                end
            end
        end
    end)

    if #candidatos > 0 then
        table.sort(candidatos, function(a, b) return a.units > b.units end)
        Log(string.format("✅ Matriz! (%d bonecos)", candidatos[1].units))
        return candidatos[1].tabela
    end

    return nil
end

local Matriz = BuscarMatriz()
if not Matriz then Log("❌ Matriz não encontrada! Você tem 50+ bonecos?") return end
Log("✅ Matriz encontrada!")

local function LerQuirkDoBoneco(dadosBoneco)
    if type(dadosBoneco) ~= "table" then return nil end
    local resultado = nil

    pcall(function()
        for k, v in pairs(dadosBoneco) do
            if type(k) == "string" and k:lower():find("quirk") then
                if type(v) == "string" and v ~= "" then resultado = v; return end
                if type(v) == "table" then
                    for k2, v2 in pairs(v) do
                        if type(k2) == "string" and k2:lower() == "quirk" and type(v2) == "string" then
                            resultado = v2; return
                        end
                    end
                    if type(v.Name) == "string" then resultado = v.Name; return end
                    if type(v.name) == "string" then resultado = v.name; return end
                end
            end
        end
    end)

    if resultado then return resultado end

    pcall(function()
        for _, v in pairs(dadosBoneco) do
            if type(v) == "table" and v ~= dadosBoneco then
                for k2, v2 in pairs(v) do
                    if type(k2) == "string" and k2:lower():find("quirk") then
                        if type(v2) == "string" and v2 ~= "" then
                            resultado = v2
                            return
                        end
                    end
                end
            end
        end
    end)
    return resultado
end

local listaPersonagens = {}
SafeCall("ExtrairPersonagens", function()
    local total = 0
    for _ in pairs(Matriz) do total = total + 1 end
    Log("📊 Total na matriz: " .. total)

    local uuidsUsados = {}

    for chave, dados in pairs(Matriz) do
        if type(dados) == "table" then
            local ehUnit = false
            pcall(function()
                for k, v in pairs(dados) do
                    if tostring(k):lower() == "kind" and tostring(v) == "Unit" then
                        ehUnit = true
                        return
                    end
                end
            end)

            if ehUnit then
                local uuid = dados.key or dados.Key or (type(chave) == "string" and chave) or dados.UUID or dados.Id
                local nome = dados.name or dados.Name

                if uuid and nome then
                    uuid = tostring(uuid)
                    nome = tostring(nome)

                    if not uuidsUsados[uuid] then
                        uuidsUsados[uuid] = true
                        local quirkAtual = LerQuirkDoBoneco(dados)
                        table.insert(listaPersonagens, {
                            nome = nome,
                            codigo = uuid,
                            quirk = quirkAtual,
                            dadosOriginais = dados
                        })
                    end
                end
            end
        end
    end

    Log("📋 Bonecos Unit extraídos: " .. #listaPersonagens)
end)

table.sort(listaPersonagens, function(a, b)
    return (a.nome or ""):lower() < (b.nome or ""):lower()
end)

if #listaPersonagens == 0 then
    Log("❌ Nenhum personagem. Abortando.")
    return
end

local QUIRKS_OPCOES = {
    "Midas Touch",
    "Fortune's Favor",
    "Prodigy",
    "Tycoon",
}
local quirksMarcadas = {}
local quirksTravadas = {}
for _, q in ipairs(QUIRKS_OPCOES) do
    quirksMarcadas[q] = false
    quirksTravadas[q] = false
end

Log("🎨 Criando GUI...")

local ScreenGui
SafeCall("CriarGUI", function()
    local playerGui = LocalPlayer:WaitForChild("PlayerGui", 10)

    if playerGui then
        local antiga = playerGui:FindFirstChild("RerollMini")
        if antiga then antiga:Destroy() end
    end

    local antigaCore = CoreGui:FindFirstChild("RerollMini")
    if antigaCore then antigaCore:Destroy() end

    ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "RerollMini"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    ScreenGui.DisplayOrder = 2147483647
    ScreenGui.IgnoreGuiInset = true

    local sucesso = false

    if not USAR_PLAYER_GUI then
        local ok = pcall(function() ScreenGui.Parent = CoreGui end)
        if ok and ScreenGui.Parent then
            sucesso = true
            Log("✅ GUI no CoreGui")
        end
    end

    if not sucesso and playerGui then
        local ok2 = pcall(function() ScreenGui.Parent = playerGui end)
        if ok2 and ScreenGui.Parent then
            sucesso = true
            Log("✅ GUI no PlayerGui")
        end
    end

    if not sucesso then
        local ok3 = pcall(function() ScreenGui.Parent = CoreGui end)
        if ok3 and ScreenGui.Parent then
            sucesso = true
            Log("✅ GUI no CoreGui (fallback)")
        end
    end
end)

if not ScreenGui or not ScreenGui.Parent then
    Log("❌ GUI não pôde ser criada. Abortando.")
    return
end

Log("✅ GUI criada com sucesso!")

local function AplicarCorner(obj, raio)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, raio or 8)
    c.Parent = obj
    return c
end

local function AplicarStroke(obj, cor, espessura, transparencia)
    local s = Instance.new("UIStroke")
    s.Color = cor or CORES.borda
    s.Thickness = espessura or 1
    s.Transparency = transparencia or 0
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent = obj
    return s
end

local function CliquePuro(botao, callback)
    local toqueInicio = nil
    local moveu = false
    local tempoInicio = 0
    local scrollPosInicial = nil

    botao.InputBegan:Connect(function(input)
        pcall(function()
            if input.UserInputType == Enum.UserInputType.MouseButton1
               or input.UserInputType == Enum.UserInputType.Touch then
                toqueInicio = input.Position
                moveu = false
                tempoInicio = tick()
                if Scroll then scrollPosInicial = Scroll.CanvasPosition end
            end
        end)
    end)

    botao.InputChanged:Connect(function(input)
        pcall(function()
            if not toqueInicio then return end
            if input.UserInputType == Enum.UserInputType.MouseMovement
               or input.UserInputType == Enum.UserInputType.Touch then
                local delta = input.Position - toqueInicio
                if math.abs(delta.X) > 6 or math.abs(delta.Y) > 6 then moveu = true end
            end
        end)
    end)

    botao.InputEnded:Connect(function(input)
        pcall(function()
            if input.UserInputType == Enum.UserInputType.MouseButton1
               or input.UserInputType == Enum.UserInputType.Touch then
                local duracao = tick() - tempoInicio
                local scrollMoveu = false
                if Scroll and scrollPosInicial then
                    local deltaScroll = Scroll.CanvasPosition - scrollPosInicial
                    if math.abs(deltaScroll.X) > 3 or math.abs(deltaScroll.Y) > 3 then scrollMoveu = true end
                end
                local foiClique = (toqueInicio ~= nil) and (not moveu) and (duracao < 0.6) and (not scrollMoveu)
                toqueInicio = nil
                moveu = false
                scrollPosInicial = nil
                if foiClique then callback() end
            end
        end)
    end)
end

local BolaFlutuante = Instance.new("TextButton")
BolaFlutuante.Name = "BolaFlutuante"
BolaFlutuante.Size = UDim2.new(0, 50, 0, 50)
BolaFlutuante.Position = UDim2.new(0, 20, 0, 55)
BolaFlutuante.BackgroundColor3 = CORES.primaria
BolaFlutuante.Text = "🎲"
BolaFlutuante.TextColor3 = Color3.fromRGB(255, 255, 255)
BolaFlutuante.TextSize = 24
BolaFlutuante.Font = Enum.Font.GothamBold
BolaFlutuante.BorderSizePixel = 0
BolaFlutuante.Visible = true
BolaFlutuante.Active = true
BolaFlutuante.ZIndex = 100
BolaFlutuante.AutoButtonColor = false
BolaFlutuante.Parent = ScreenGui
AplicarCorner(BolaFlutuante, 25)
local strokeBola = AplicarStroke(BolaFlutuante, CORES.primariaClara, 2.5, 0)
strokeBola.ZIndex = 101

local Main = Instance.new("Frame")
Main.Name = "Main"
Main.Size = UDim2.new(0, 290, 0, 310)
Main.Position = UDim2.new(0, 20, 0, 55)
Main.BackgroundColor3 = CORES.fundo
Main.BorderSizePixel = 0
Main.Active = true
Main.Draggable = true
Main.Visible = true
Main.ZIndex = 2
Main.Parent = ScreenGui
AplicarCorner(Main, 10)
AplicarStroke(Main, CORES.borda, 1.2, 0)

do
    local bolaToqueInicio = nil
    local bolaMoveu = false

    BolaFlutuante.InputBegan:Connect(function(input)
        pcall(function()
            if input.UserInputType == Enum.UserInputType.MouseButton1
               or input.UserInputType == Enum.UserInputType.Touch then
                bolaToqueInicio = input.Position
                bolaMoveu = false
            end
        end)
    end)

    BolaFlutuante.InputChanged:Connect(function(input)
        pcall(function()
            if not bolaToqueInicio then return end
            if input.UserInputType == Enum.UserInputType.MouseMovement
               or input.UserInputType == Enum.UserInputType.Touch then
                local delta = input.Position - bolaToqueInicio
                if math.abs(delta.X) > 6 or math.abs(delta.Y) > 6 then
                    bolaMoveu = true
                    BolaFlutuante.Position = UDim2.new(
                        0, BolaFlutuante.Position.X.Offset + delta.X * 0.05,
                        0, BolaFlutuante.Position.Y.Offset + delta.Y * 0.05
                    )
                end
            end
        end)
    end)

    BolaFlutuante.InputEnded:Connect(function(input)
        pcall(function()
            if input.UserInputType == Enum.UserInputType.MouseButton1
               or input.UserInputType == Enum.UserInputType.Touch then
                if not bolaMoveu then Main.Visible = not Main.Visible end
                bolaToqueInicio = nil
                bolaMoveu = false
            end
        end)
    end)
end

local TopBar = Instance.new("Frame")
TopBar.Size = UDim2.new(1, 0, 0, 26)
TopBar.BackgroundColor3 = CORES.fundo2
TopBar.BorderSizePixel = 0
TopBar.ZIndex = 3
TopBar.Parent = Main
AplicarCorner(TopBar, 10)

local TopBarFix = Instance.new("Frame")
TopBarFix.Size = UDim2.new(1, 0, 0, 8)
TopBarFix.Position = UDim2.new(0, 0, 1, -8)
TopBarFix.BackgroundColor3 = CORES.fundo2
TopBarFix.BorderSizePixel = 0
TopBarFix.ZIndex = 3
TopBarFix.Parent = TopBar

local BolaTitulo = Instance.new("Frame")
BolaTitulo.Size = UDim2.new(0, 7, 0, 7)
BolaTitulo.Position = UDim2.new(0, 10, 0.5, -3.5)
BolaTitulo.BackgroundColor3 = CORES.primaria
BolaTitulo.BorderSizePixel = 0
BolaTitulo.ZIndex = 4
BolaTitulo.Parent = TopBar
AplicarCorner(BolaTitulo, 4)

local Titulo = Instance.new("TextLabel")
Titulo.Size = UDim2.new(1, -40, 1, 0)
Titulo.Position = UDim2.new(0, 22, 0, 0)
Titulo.BackgroundTransparency = 1
Titulo.Text = "REROLL QUIRK"
Titulo.TextColor3 = CORES.texto
Titulo.TextSize = 10
Titulo.Font = Enum.Font.GothamBold
Titulo.TextXAlignment = Enum.TextXAlignment.Left
Titulo.ZIndex = 4
Titulo.Parent = TopBar

local Fechar = Instance.new("TextButton")
Fechar.Size = UDim2.new(0, 18, 0, 18)
Fechar.Position = UDim2.new(1, -22, 0.5, -9)
Fechar.BackgroundColor3 = CORES.fundo3
Fechar.Text = "✕"
Fechar.TextColor3 = CORES.textoFraco
Fechar.TextSize = 9
Fechar.Font = Enum.Font.GothamBold
Fechar.BorderSizePixel = 0
Fechar.ZIndex = 4
Fechar.AutoButtonColor = false
Fechar.Parent = TopBar
AplicarCorner(Fechar, 5)
Fechar.MouseButton1Click:Connect(function()
    pcall(function() ScreenGui:Destroy() end)
end)

local Conteudo = Instance.new("Frame")
Conteudo.Size = UDim2.new(1, 0, 1, -26)
Conteudo.Position = UDim2.new(0, 0, 0, 26)
Conteudo.BackgroundTransparency = 1
Conteudo.ZIndex = 2
Conteudo.Parent = Main

local ColunaEsq = Instance.new("Frame")
ColunaEsq.Size = UDim2.new(0, 130, 1, -12)
ColunaEsq.Position = UDim2.new(0, 6, 0, 6)
ColunaEsq.BackgroundTransparency = 1
ColunaEsq.ZIndex = 2
ColunaEsq.Parent = Conteudo

local StatusFrame = Instance.new("Frame")
StatusFrame.Size = UDim2.new(1, 0, 0, 32)
StatusFrame.Position = UDim2.new(0, 0, 0, 0)
StatusFrame.BackgroundColor3 = CORES.fundo2
StatusFrame.BorderSizePixel = 0
StatusFrame.ZIndex = 2
StatusFrame.Parent = ColunaEsq
AplicarCorner(StatusFrame, 7)
AplicarStroke(StatusFrame, CORES.borda, 1, 0.7)

local StLinha1 = Instance.new("TextLabel")
StLinha1.Size = UDim2.new(1, -10, 0, 14)
StLinha1.Position = UDim2.new(0, 6, 0, 3)
StLinha1.BackgroundTransparency = 1
StLinha1.Text = "🎲 Parado"
StLinha1.TextColor3 = CORES.amarelo
StLinha1.TextSize = 9
StLinha1.Font = Enum.Font.GothamBold
StLinha1.TextXAlignment = Enum.TextXAlignment.Left
StLinha1.TextTruncate = Enum.TextTruncate.AtEnd
StLinha1.ZIndex = 3
StLinha1.Parent = StatusFrame

local StLinha2 = Instance.new("TextLabel")
StLinha2.Size = UDim2.new(1, -10, 0, 12)
StLinha2.Position = UDim2.new(0, 6, 0, 17)
StLinha2.BackgroundTransparency = 1
StLinha2.Text = "Pronto"
StLinha2.TextColor3 = CORES.textoFraco
StLinha2.TextSize = 8
StLinha2.Font = Enum.Font.Gotham
StLinha2.TextXAlignment = Enum.TextXAlignment.Left
StLinha2.TextTruncate = Enum.TextTruncate.AtEnd
StLinha2.ZIndex = 3
StLinha2.Parent = StatusFrame

local ContadorFrame = Instance.new("Frame")
ContadorFrame.Size = UDim2.new(1, 0, 0, 74)
ContadorFrame.Position = UDim2.new(0, 0, 0, 38)
ContadorFrame.BackgroundColor3 = CORES.fundo2
ContadorFrame.BorderSizePixel = 0
ContadorFrame.ZIndex = 2
ContadorFrame.Parent = ColunaEsq
AplicarCorner(ContadorFrame, 7)
AplicarStroke(ContadorFrame, CORES.verde, 1, 0.5)

local ContadorTitulo = Instance.new("TextLabel")
ContadorTitulo.Size = UDim2.new(1, -10, 0, 13)
ContadorTitulo.Position = UDim2.new(0, 5, 0, 3)
ContadorTitulo.BackgroundTransparency = 1
ContadorTitulo.Text = "📊 INVENTÁRIO"
ContadorTitulo.TextColor3 = CORES.verdeLabel
ContadorTitulo.TextSize = 9
ContadorTitulo.Font = Enum.Font.GothamBold
ContadorTitulo.TextXAlignment = Enum.TextXAlignment.Left
ContadorTitulo.ZIndex = 3
ContadorTitulo.Parent = ContadorFrame

local ContadorLista = Instance.new("Frame")
ContadorLista.Size = UDim2.new(1, -10, 0, 56)
ContadorLista.Position = UDim2.new(0, 5, 0, 16)
ContadorLista.BackgroundTransparency = 1
ContadorLista.ZIndex = 3
ContadorLista.Parent = ContadorFrame

local ContadorLayout = Instance.new("UIListLayout")
ContadorLayout.Padding = UDim.new(0, 0)
ContadorLayout.SortOrder = Enum.SortOrder.LayoutOrder
ContadorLayout.Parent = ContadorLista

local labelsContador = {}
for idx, quirkNome in ipairs(QUIRKS_OPCOES) do
    local Row = Instance.new("Frame")
    Row.Size = UDim2.new(1, 0, 0, 13)
    Row.BackgroundTransparency = 1
    Row.LayoutOrder = idx
    Row.ZIndex = 3
    Row.Parent = ContadorLista

    local Bullet = Instance.new("Frame")
    Bullet.Size = UDim2.new(0, 5, 0, 5)
    Bullet.Position = UDim2.new(0, 2, 0.5, -2.5)
    Bullet.BackgroundColor3 = CORES.verde
    Bullet.BorderSizePixel = 0
    Bullet.ZIndex = 4
    Bullet.Parent = Row
    AplicarCorner(Bullet, 3)

    local Label = Instance.new("TextLabel")
    Label.Size = UDim2.new(1, -12, 1, 0)
    Label.Position = UDim2.new(0, 12, 0, 0)
    Label.BackgroundTransparency = 1
    Label.Text = quirkNome .. ": 0"
    Label.TextColor3 = CORES.verdeLabel
    Label.TextSize = 10
    Label.Font = Enum.Font.GothamMedium
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.TextTruncate = Enum.TextTruncate.AtEnd
    Label.ZIndex = 4
    Label.Parent = Row
    labelsContador[quirkNome] = Label
end

local AlvoTitulo = Instance.new("TextLabel")
AlvoTitulo.Size = UDim2.new(1, 0, 0, 12)
AlvoTitulo.Position = UDim2.new(0, 0, 0, 118)
AlvoTitulo.BackgroundTransparency = 1
AlvoTitulo.Text = "🎯 PARAR QUANDO PEGAR"
AlvoTitulo.TextColor3 = CORES.primariaClara
AlvoTitulo.TextSize = 8
AlvoTitulo.Font = Enum.Font.GothamBold
AlvoTitulo.TextXAlignment = Enum.TextXAlignment.Left
AlvoTitulo.ZIndex = 3
AlvoTitulo.Parent = ColunaEsq

local AlvoContainer = Instance.new("Frame")
AlvoContainer.Size = UDim2.new(1, 0, 0, 68)
AlvoContainer.Position = UDim2.new(0, 0, 0, 132)
AlvoContainer.BackgroundTransparency = 1
AlvoContainer.ZIndex = 3
AlvoContainer.Parent = ColunaEsq

local AlvoLayout = Instance.new("UIListLayout")
AlvoLayout.Padding = UDim.new(0, 2)
AlvoLayout.SortOrder = Enum.SortOrder.LayoutOrder
AlvoLayout.Parent = AlvoContainer

local botoesQuirk = {}
local botoesLock = {}

for idx, quirkNome in ipairs(QUIRKS_OPCOES) do
    local Linha = Instance.new("Frame")
    Linha.Size = UDim2.new(1, 0, 0, 16)
    Linha.BackgroundTransparency = 1
    Linha.LayoutOrder = idx
    Linha.ZIndex = 3
    Linha.Parent = AlvoContainer

    local AlvoBtn = Instance.new("TextButton")
    AlvoBtn.Size = UDim2.new(1, -20, 1, 0)
    AlvoBtn.Position = UDim2.new(0, 0, 0, 0)
    AlvoBtn.BackgroundColor3 = CORES.fundo3
    AlvoBtn.Text = "☐ " .. quirkNome
    AlvoBtn.TextColor3 = CORES.texto
    AlvoBtn.TextSize = 8
    AlvoBtn.Font = Enum.Font.GothamMedium
    AlvoBtn.BorderSizePixel = 0
    AlvoBtn.ZIndex = 4
    AlvoBtn.AutoButtonColor = false
    AlvoBtn.Parent = Linha
    AplicarCorner(AlvoBtn, 5)

    botoesQuirk[quirkNome] = AlvoBtn

    local LockBtn = Instance.new("TextButton")
    LockBtn.Size = UDim2.new(0, 18, 1, 0)
    LockBtn.Position = UDim2.new(1, -18, 0, 0)
    LockBtn.BackgroundColor3 = CORES.fundo3
    LockBtn.Text = "🔓"
    LockBtn.TextColor3 = CORES.textoFraco
    LockBtn.TextSize = 10
    LockBtn.Font = Enum.Font.GothamBold
    LockBtn.BorderSizePixel = 0
    LockBtn.ZIndex = 4
    LockBtn.AutoButtonColor = false
    LockBtn.Parent = Linha
    AplicarCorner(LockBtn, 5)

    botoesLock[quirkNome] = LockBtn

    local function AtualizarVisualQuirk()
        if quirksTravadas[quirkNome] then
            AlvoBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 42)
            AlvoBtn.TextColor3 = Color3.fromRGB(120, 120, 140)
            if quirksMarcadas[quirkNome] then
                AlvoBtn.Text = "☑ " .. quirkNome .. " 🔒"
            else
                AlvoBtn.Text = "☐ " .. quirkNome .. " 🔒"
            end
        else
            if quirksMarcadas[quirkNome] then
                AlvoBtn.Text = "☑ " .. quirkNome
                AlvoBtn.BackgroundColor3 = CORES.verde
                AlvoBtn.TextColor3 = CORES.verdeTexto
            else
                AlvoBtn.Text = "☐ " .. quirkNome
                AlvoBtn.BackgroundColor3 = CORES.fundo3
                AlvoBtn.TextColor3 = CORES.texto
            end
        end
    end

    local function AtualizarVisualLock()
        if quirksTravadas[quirkNome] then
            LockBtn.Text = "🔒"
            LockBtn.BackgroundColor3 = CORES.amarelo
            LockBtn.TextColor3 = Color3.fromRGB(60, 40, 0)
        else
            LockBtn.Text = "🔓"
            LockBtn.BackgroundColor3 = CORES.fundo3
            LockBtn.TextColor3 = CORES.textoFraco
        end
    end

    CliquePuro(AlvoBtn, function()
        quirksMarcadas[quirkNome] = not quirksMarcadas[quirkNome]
        AtualizarVisualQuirk()
    end)

    CliquePuro(LockBtn, function()
        quirksTravadas[quirkNome] = not quirksTravadas[quirkNome]
        AtualizarVisualLock()
        AtualizarVisualQuirk()
    end)

    botoesQuirk[quirkNome .. "_update"] = AtualizarVisualQuirk
    botoesLock[quirkNome .. "_update"] = AtualizarVisualLock
end

local ColunaDir = Instance.new("Frame")
ColunaDir.Size = UDim2.new(1, -146, 1, -12)
ColunaDir.Position = UDim2.new(0, 140, 0, 6)
ColunaDir.BackgroundTransparency = 1
ColunaDir.ZIndex = 2
ColunaDir.Parent = Conteudo

local BuscaBox = Instance.new("TextBox")
BuscaBox.Size = UDim2.new(1, 0, 0, 20)
BuscaBox.Position = UDim2.new(0, 0, 0, 0)
BuscaBox.BackgroundColor3 = CORES.fundo2
BuscaBox.BorderSizePixel = 0
BuscaBox.Text = ""
BuscaBox.PlaceholderText = "🔍 Buscar..."
BuscaBox.TextColor3 = CORES.texto
BuscaBox.PlaceholderColor3 = CORES.textoFraco
BuscaBox.TextSize = 9
BuscaBox.Font = Enum.Font.Gotham
BuscaBox.ClearTextOnFocus = false
BuscaBox.TextXAlignment = Enum.TextXAlignment.Left
BuscaBox.ZIndex = 3
BuscaBox.Parent = ColunaDir
AplicarCorner(BuscaBox, 6)
AplicarStroke(BuscaBox, CORES.borda, 1, 0.5)

local PaddingBusca = Instance.new("UIPadding")
PaddingBusca.PaddingLeft = UDim.new(0, 6)
PaddingBusca.Parent = BuscaBox

local LinhaInfo = Instance.new("Frame")
LinhaInfo.Size = UDim2.new(1, 0, 0, 18)
LinhaInfo.Position = UDim2.new(0, 0, 0, 24)
LinhaInfo.BackgroundTransparency = 1
LinhaInfo.ZIndex = 3
LinhaInfo.Parent = ColunaDir

local Contador = Instance.new("TextLabel")
Contador.Size = UDim2.new(0.4, 0, 1, 0)
Contador.Position = UDim2.new(0, 0, 0, 0)
Contador.BackgroundTransparency = 1
Contador.Text = "0 / 0"
Contador.TextColor3 = CORES.textoFraco
Contador.TextSize = 9
Contador.Font = Enum.Font.GothamMedium
Contador.TextXAlignment = Enum.TextXAlignment.Left
Contador.ZIndex = 4
Contador.Parent = LinhaInfo

local BtnTodos = Instance.new("TextButton")
BtnTodos.Size = UDim2.new(0, 52, 1, 0)
BtnTodos.Position = UDim2.new(1, -112, 0, 0)
BtnTodos.BackgroundColor3 = CORES.verde
BtnTodos.Text = "✅ Todos"
BtnTodos.TextColor3 = CORES.verdeTexto
BtnTodos.TextSize = 8
BtnTodos.Font = Enum.Font.GothamBold
BtnTodos.BorderSizePixel = 0
BtnTodos.ZIndex = 4
BtnTodos.AutoButtonColor = false
BtnTodos.Parent = LinhaInfo
AplicarCorner(BtnTodos, 5)

local BtnLimpar = Instance.new("TextButton")
BtnLimpar.Size = UDim2.new(0, 54, 1, 0)
BtnLimpar.Position = UDim2.new(1, -56, 0, 0)
BtnLimpar.BackgroundColor3 = CORES.vermelho
BtnLimpar.Text = "🗑️ Limpar"
BtnLimpar.TextColor3 = Color3.fromRGB(255, 255, 255)
BtnLimpar.TextSize = 8
BtnLimpar.Font = Enum.Font.GothamBold
BtnLimpar.BorderSizePixel = 0
BtnLimpar.ZIndex = 4
BtnLimpar.AutoButtonColor = false
BtnLimpar.Parent = LinhaInfo
AplicarCorner(BtnLimpar, 5)

local PainelConfig = Instance.new("Frame")
PainelConfig.Size = UDim2.new(1, 0, 0, 20)
PainelConfig.Position = UDim2.new(0, 0, 0, 46)
PainelConfig.BackgroundTransparency = 1
PainelConfig.ZIndex = 5
PainelConfig.Parent = ColunaDir

local BtnSalvar = Instance.new("TextButton")
BtnSalvar.Size = UDim2.new(0.33, -1, 1, 0)
BtnSalvar.Position = UDim2.new(0, 0, 0, 0)
BtnSalvar.BackgroundColor3 = Color3.fromRGB(50, 110, 170)
BtnSalvar.Text = "💾 Salvar"
BtnSalvar.TextColor3 = Color3.fromRGB(255, 255, 255)
BtnSalvar.TextSize = 7
BtnSalvar.Font = Enum.Font.GothamBold
BtnSalvar.BorderSizePixel = 0
BtnSalvar.ZIndex = 6
BtnSalvar.AutoButtonColor = false
BtnSalvar.Parent = PainelConfig
AplicarCorner(BtnSalvar, 5)

local BtnCarregar = Instance.new("TextButton")
BtnCarregar.Size = UDim2.new(0.33, -1, 1, 0)
BtnCarregar.Position = UDim2.new(0.335, 0, 0, 0)
BtnCarregar.BackgroundColor3 = Color3.fromRGB(160, 110, 50)
BtnCarregar.Text = "📂 Carregar"
BtnCarregar.TextColor3 = Color3.fromRGB(255, 255, 255)
BtnCarregar.TextSize = 7
BtnCarregar.Font = Enum.Font.GothamBold
BtnCarregar.BorderSizePixel = 0
BtnCarregar.ZIndex = 6
BtnCarregar.AutoButtonColor = false
BtnCarregar.Parent = PainelConfig
AplicarCorner(BtnCarregar, 5)

local BtnAutoLoad = Instance.new("TextButton")
BtnAutoLoad.Size = UDim2.new(0.33, -1, 1, 0)
BtnAutoLoad.Position = UDim2.new(0.67, 0, 0, 0)
BtnAutoLoad.BackgroundColor3 = CORES.fundo3
BtnAutoLoad.Text = "☐ Auto"
BtnAutoLoad.TextColor3 = CORES.textoFraco
BtnAutoLoad.TextSize = 7
BtnAutoLoad.Font = Enum.Font.GothamBold
BtnAutoLoad.BorderSizePixel = 0
BtnAutoLoad.ZIndex = 6
BtnAutoLoad.AutoButtonColor = false
BtnAutoLoad.Parent = PainelConfig
AplicarCorner(BtnAutoLoad, 5)

Scroll = Instance.new("ScrollingFrame")
Scroll.Size = UDim2.new(1, 0, 1, -120)
Scroll.Position = UDim2.new(0, 0, 0, 70)
Scroll.BackgroundColor3 = CORES.fundo2
Scroll.BorderSizePixel = 0
Scroll.ScrollBarThickness = 4
Scroll.ScrollBarImageColor3 = CORES.primaria
Scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
Scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
Scroll.ZIndex = 3
Scroll.Parent = ColunaDir
AplicarCorner(Scroll, 7)
AplicarStroke(Scroll, CORES.borda, 1, 0.5)

local Layout = Instance.new("UIListLayout")
Layout.Padding = UDim.new(0, 3)
Layout.SortOrder = Enum.SortOrder.LayoutOrder
Layout.Parent = Scroll

local Pad = Instance.new("UIPadding")
Pad.PaddingTop = UDim.new(0, 5); Pad.PaddingLeft = UDim.new(0, 5)
Pad.PaddingRight = UDim.new(0, 5); Pad.PaddingBottom = UDim.new(0, 5)
Pad.Parent = Scroll

local FaixaBotoes = Instance.new("Frame")
FaixaBotoes.Size = UDim2.new(1, 0, 0, 30)
FaixaBotoes.Position = UDim2.new(0, 0, 1, -30)
FaixaBotoes.BackgroundColor3 = CORES.fundo
FaixaBotoes.BorderSizePixel = 0
FaixaBotoes.ZIndex = 5
FaixaBotoes.Parent = Conteudo
AplicarCorner(FaixaBotoes, 8)

local BtnIniciar = Instance.new("TextButton")
BtnIniciar.Size = UDim2.new(0.68, -3, 1, -8)
BtnIniciar.Position = UDim2.new(0, 7, 0.5, -12)
BtnIniciar.BackgroundColor3 = CORES.verde
BtnIniciar.Text = "▶ INICIAR"
BtnIniciar.TextColor3 = CORES.verdeTexto
BtnIniciar.TextSize = 11
BtnIniciar.Font = Enum.Font.GothamBold
BtnIniciar.BorderSizePixel = 0
BtnIniciar.AutoButtonColor = false
BtnIniciar.ZIndex = 6
BtnIniciar.Parent = FaixaBotoes
AplicarCorner(BtnIniciar, 6)
AplicarStroke(BtnIniciar, CORES.verdeClaro, 1.2, 0)

local BtnParar = Instance.new("TextButton")
BtnParar.Size = UDim2.new(0.32, -4, 1, -8)
BtnParar.Position = UDim2.new(0.68, 0, 0.5, -12)
BtnParar.BackgroundColor3 = CORES.vermelho
BtnParar.Text = "⏸"
BtnParar.TextColor3 = Color3.fromRGB(255, 255, 255)
BtnParar.TextSize = 11
BtnParar.Font = Enum.Font.GothamBold
BtnParar.BorderSizePixel = 0
BtnParar.AutoButtonColor = false
BtnParar.ZIndex = 6
BtnParar.Parent = FaixaBotoes
AplicarCorner(BtnParar, 6)

local selecionados = {}
local itens = {}
local itensPorCodigo = {}

local function AtualizarContador()
    pcall(function()
        local q = 0
        for _ in pairs(selecionados) do q = q + 1 end
        Contador.Text = q .. " / " .. #listaPersonagens
    end)
end

local function AtualizarContagemQuirks()
    pcall(function()
        local contagem = {}
        for _, q in ipairs(QUIRKS_OPCOES) do contagem[q] = 0 end

        for _, it in ipairs(itens) do
            local q = it.quirk
            if q then
                for _, quirkOpcao in ipairs(QUIRKS_OPCOES) do
                    local ql = q:lower()
                    local dl = quirkOpcao:lower()
                    if ql == dl or ql:find(dl, 1, true) then
                        contagem[quirkOpcao] = contagem[quirkOpcao] + 1
                        break
                    end
                end
            end
        end

        for _, quirkNome in ipairs(QUIRKS_OPCOES) do
            local label = labelsContador[quirkNome]
            if label then
                local n = contagem[quirkNome] or 0
                label.Text = quirkNome .. ": " .. n
            end
        end
    end)
end

SafeCall("CriarItens", function()
    local total = math.min(#listaPersonagens, MAX_ITENS)
    Log("📋 Criando " .. total .. " itens")

    for i = 1, total do
        local p = listaPersonagens[i]

        local Item = Instance.new("Frame")
        Item.Size = UDim2.new(1, 0, 0, 30)
        Item.BackgroundColor3 = CORES.fundo3
        Item.BorderSizePixel = 0
        Item.LayoutOrder = i
        Item.ZIndex = 4
        Item.Parent = Scroll
        AplicarCorner(Item, 5)

        local Check = Instance.new("Frame")
        Check.Size = UDim2.new(0, 14, 0, 14)
        Check.Position = UDim2.new(0, 5, 0.5, -7)
        Check.BackgroundColor3 = Color3.fromRGB(55, 55, 80)
        Check.BorderSizePixel = 0
        Check.ZIndex = 5
        Check.Parent = Item
        AplicarCorner(Check, 4)

        local CheckMark = Instance.new("TextLabel")
        CheckMark.Size = UDim2.new(1, 0, 1, 0)
        CheckMark.BackgroundTransparency = 1
        CheckMark.Text = "✓"
        CheckMark.TextColor3 = Color3.fromRGB(255, 255, 255)
        CheckMark.TextSize = 10
        CheckMark.Font = Enum.Font.GothamBold
        CheckMark.Visible = false
        CheckMark.ZIndex = 6
        CheckMark.Parent = Check

        local NomeL = Instance.new("TextLabel")
        NomeL.Size = UDim2.new(1, -28, 0, 14)
        NomeL.Position = UDim2.new(0, 24, 0, 1)
        NomeL.BackgroundTransparency = 1
        NomeL.Text = p.nome
        NomeL.TextColor3 = CORES.texto
        NomeL.TextSize = 9
        NomeL.Font = Enum.Font.GothamBold
        NomeL.TextXAlignment = Enum.TextXAlignment.Left
        NomeL.TextTruncate = Enum.TextTruncate.AtEnd
        NomeL.ZIndex = 5
        NomeL.Parent = Item

        local QuirkL = Instance.new("TextLabel")
        QuirkL.Size = UDim2.new(1, -28, 0, 12)
        QuirkL.Position = UDim2.new(0, 24, 0, 15)
        QuirkL.BackgroundTransparency = 1
        if p.quirk then
            QuirkL.Text = "✨ " .. p.quirk
            QuirkL.TextColor3 = CORES.verdeLabel
        else
            QuirkL.Text = "— sem quirk —"
            QuirkL.TextColor3 = Color3.fromRGB(180, 120, 130)
        end
        QuirkL.TextSize = 8
        QuirkL.Font = Enum.Font.Gotham
        QuirkL.TextXAlignment = Enum.TextXAlignment.Left
        QuirkL.TextTruncate = Enum.TextTruncate.AtEnd
        QuirkL.ZIndex = 5
        QuirkL.Parent = Item

        local Click = Instance.new("TextButton")
        Click.Size = UDim2.new(1, 0, 1, 0)
        Click.BackgroundTransparency = 1
        Click.Text = ""
        Click.ZIndex = 7
        Click.AutoButtonColor = false
        Click.Parent = Item

        local function Att()
            pcall(function()
                if selecionados[p.codigo] then
                    Item.BackgroundColor3 = Color3.fromRGB(60, 85, 140)
                    Check.BackgroundColor3 = CORES.verde
                    CheckMark.Visible = true
                else
                    Item.BackgroundColor3 = CORES.fundo3
                    Check.BackgroundColor3 = Color3.fromRGB(55, 55, 80)
                    CheckMark.Visible = false
                end
            end)
        end

        CliquePuro(Click, function()
            if selecionados[p.codigo] then
                selecionados[p.codigo] = nil
            else
                selecionados[p.codigo] = true
            end
            Att()
            AtualizarContador()
        end)

        local itemRef = {
            frame = Item,
            codigo = p.codigo,
            nome = p.nome,
            quirk = p.quirk,
            quirkLabel = QuirkL,
            dados = p,
            atualizar = Att
        }
        table.insert(itens, itemRef)
        itensPorCodigo[p.codigo] = itemRef
    end
end)

AtualizarContador()
AtualizarContagemQuirks()

Log("✅ " .. #itens .. " itens criados")

local IniciarRolagem

local function AtualizarBotaoAutoLoad()
    if autoLoadAtivo then
        BtnAutoLoad.Text = "☑ Auto"
        BtnAutoLoad.BackgroundColor3 = CORES.verde
        BtnAutoLoad.TextColor3 = CORES.verdeTexto
    else
        BtnAutoLoad.Text = "☐ Auto"
        BtnAutoLoad.BackgroundColor3 = CORES.fundo3
        BtnAutoLoad.TextColor3 = CORES.textoFraco
    end
end

local function AplicarConfigNaGUI(cfg)
    for nome, marcada in pairs(cfg.quirks) do
        if quirksMarcadas[nome] ~= nil then quirksMarcadas[nome] = marcada end
    end
    if cfg.locks then
        for nome, travada in pairs(cfg.locks) do
            if quirksTravadas[nome] ~= nil then quirksTravadas[nome] = travada end
        end
    end
    for nome, _ in pairs(quirksMarcadas) do
        local fnQ = botoesQuirk[nome .. "_update"]
        if fnQ then fnQ() end
        local fnL = botoesLock[nome .. "_update"]
        if fnL then fnL() end
    end

    for _, it in ipairs(itens) do selecionados[it.codigo] = nil end
    for _, cod in ipairs(cfg.selecionados) do
        if itensPorCodigo[cod] then selecionados[cod] = true end
    end
    for _, it in ipairs(itens) do it.atualizar() end

    AtualizarContador()
    AtualizarContagemQuirks()
end

BtnSalvar.MouseButton1Click:Connect(function()
    pcall(function()
        local ok, err = SalvarConfig(quirksMarcadas, quirksTravadas, selecionados)
        if ok then SetStatusTemporario("💾 Salvo!", CORES.verdeClaro)
        else SetStatusTemporario("❌ " .. tostring(err), CORES.vermelho) end
    end)
end)

BtnCarregar.MouseButton1Click:Connect(function()
    pcall(function()
        local cfg, ok, err = CarregarConfig()
        if not ok then SetStatusTemporario("❌ " .. tostring(err), CORES.vermelho); return end
        AplicarConfigNaGUI(cfg)
        SetStatusTemporario("📂 Carregado!", Color3.fromRGB(120, 200, 255))
        task.delay(0.6, function()
            pcall(function() if IniciarRolagem then IniciarRolagem() end end)
        end)
    end)
end)

BtnAutoLoad.MouseButton1Click:Connect(function()
    pcall(function()
        autoLoadAtivo = not autoLoadAtivo
        SalvarAutoLoadFlag(autoLoadAtivo)
        AtualizarBotaoAutoLoad()
        SetStatusTemporario(autoLoadAtivo and "🔁 Auto ON" or "🔁 Auto OFF", CORES.amarelo)
    end)
end)

function SetStatusTemporario(msg, cor)
    pcall(function()
        local txt1 = StLinha1.Text
        local cor1 = StLinha1.TextColor3
        local txt2 = StLinha2.Text
        StLinha1.Text = msg
        StLinha1.TextColor3 = cor or CORES.texto
        StLinha2.Text = ""
        task.delay(1.5, function()
            pcall(function()
                StLinha1.Text = txt1
                StLinha1.TextColor3 = cor1
                StLinha2.Text = txt2
            end)
        end)
    end)
end

autoLoadAtivo = LerAutoLoadFlag()
AtualizarBotaoAutoLoad()

if autoLoadAtivo then
    task.spawn(function()
        task.wait(0.8)
        pcall(function()
            local cfg, ok, err = CarregarConfig()
            if ok then
                AplicarConfigNaGUI(cfg)
                task.delay(0.6, function()
                    pcall(function() if IniciarRolagem then IniciarRolagem() end end)
                end)
            end
        end)
    end)
end

BtnTodos.MouseButton1Click:Connect(function()
    pcall(function()
        local f = BuscaBox.Text:lower()
        for _, it in ipairs(itens) do
            if f == "" or it.nome:lower():find(f, 1, true) then
                selecionados[it.codigo] = true
                it.atualizar()
            end
        end
        AtualizarContador()
    end)
end)

BtnLimpar.MouseButton1Click:Connect(function()
    pcall(function()
        for _, it in ipairs(itens) do
            selecionados[it.codigo] = nil
            it.atualizar()
        end
        AtualizarContador()
    end)
end)

BuscaBox:GetPropertyChangedSignal("Text"):Connect(function()
    pcall(function()
        local f = BuscaBox.Text:lower()
        for _, it in ipairs(itens) do
            it.frame.Visible = (f == "" or it.nome:lower():find(f, 1, true))
        end
    end)
end)

local rodando = false
local pararSolicitado = false

local function SetStatus(l1, l2, cor1, cor2)
    pcall(function()
        StLinha1.Text = l1 or ""
        StLinha2.Text = l2 or ""
        if cor1 then StLinha1.TextColor3 = cor1 end
        if cor2 then StLinha2.TextColor3 = cor2 end
    end)
end

local function GetQuirksAlvo()
    local lista = {}
    pcall(function()
        for nome, marcada in pairs(quirksMarcadas) do
            if marcada and not quirksTravadas[nome] then table.insert(lista, nome) end
        end
    end)
    return lista
end

local function GetQuirksTravadas()
    local lista = {}
    pcall(function()
        for nome, travada in pairs(quirksTravadas) do
            if travada then table.insert(lista, nome) end
        end
    end)
    return lista
end

local function EhDesejada(q)
    if not q then return false end
    local alvos = GetQuirksAlvo()
    if #alvos == 0 then return false end
    local ql = q:lower()
    for _, d in ipairs(alvos) do
        local dl = d:lower()
        if ql == dl or ql:find(dl, 1, true) then return true end
    end
    return false
end

local function EhTravada(q)
    if not q then return false end
    local travadas = GetQuirksTravadas()
    if #travadas == 0 then return false end
    local ql = q:lower()
    for _, d in ipairs(travadas) do
        local dl = d:lower()
        if ql == dl or ql:find(dl, 1, true) then return true end
    end
    return false
end

local ultimoStatus = 0
local function SetStatusThrottled(l1, l2, cor1, cor2)
    local agora = tick()
    if agora - ultimoStatus < 0.1 then return end
    ultimoStatus = agora
    SetStatus(l1, l2, cor1, cor2)
end

local function RollInfinito(codigo)
    if not RollEvent then ReconectarRoll() end
    if not RollEvent then return false end
    local ok = pcall(function() RollEvent:FireServer(codigo) end)
    return ok
end

local function GetListaSelecionados()
    local lista = {}
    pcall(function()
        for codigo in pairs(selecionados) do
            local it = itensPorCodigo[codigo]
            if it then
                table.insert(lista, { codigo = codigo, nome = it.nome, item = it })
            end
        end
        table.sort(lista, function(a, b) return a.nome:lower() < b.nome:lower() end)
    end)
    return lista
end

local function RolarPersonagem(p)
    local item = itensPorCodigo[p.codigo]
    if not item then return false end
    local quirkAtual = item.quirk

    if quirkAtual and EhTravada(quirkAtual) then
        return false
    end

    if quirkAtual and EhDesejada(quirkAtual) then
        return true
    end

    local tentativas = 0
    local ultimaQuirkLida = quirkAtual

    while not pararSolicitado do
        tentativas = tentativas + 1
        RollInfinito(p.codigo)
        task.wait(DELAY_APOS_ROLL)

        local item2 = itensPorCodigo[p.codigo]
        if item2 then
            local dadosBoneco = item2.dados.dadosOriginais
            local quirkNova = LerQuirkDoBoneco(dadosBoneco)

            if quirkNova and quirkNova ~= quirkAtual then
                quirkAtual = quirkNova
                item2.quirk = quirkNova
                pcall(function()
                    item2.quirkLabel.Text = "✨ " .. quirkNova
                    item2.quirkLabel.TextColor3 = CORES.verdeLabel
                end)
                AtualizarContagemQuirks()

                if EhDesejada(quirkNova) then
                    return true
                end

                if ultimaQuirkLida ~= quirkNova then
                    ultimaQuirkLida = quirkNova
                    SetStatusThrottled("🎲 Rolando...", "✨ " .. quirkNova .. " (#" .. tentativas .. ")", CORES.amarelo, CORES.verdeLabel)
                end
            end
        end
    end
    return false
end

IniciarRolagem = function()
    if rodando then return end
    local alvos = GetQuirksAlvo()
    local travadas = GetQuirksTravadas()
    if #alvos == 0 and #travadas == 0 then
        SetStatus("⚠️ Marque 1 quirk!", "", CORES.vermelho); return
    end
    if next(selecionados) == nil then
        SetStatus("⚠️ Selecione 1 boneco!", "", CORES.vermelho); return
    end

    rodando = true
    pararSolicitado = false
    BtnIniciar.Text = "🎲 ROLANDO..."
    BtnIniciar.BackgroundColor3 = CORES.amarelo

    task.spawn(function()
        local sucessoTotal = 0
        local pulados = 0
        local passadaAtual = 0
        local todosOk = false

        while not pararSolicitado and passadaAtual < MAX_PASSADAS and not todosOk do
            passadaAtual = passadaAtual + 1
            local lista = GetListaSelecionados()
            if #lista == 0 then break end

            local faltando = {}
            for _, p in ipairs(lista) do
                local item = itensPorCodigo[p.codigo]
                if item then
                    local q = item.quirk
                    if item.dados and item.dados.dadosOriginais then
                        local qAtual = LerQuirkDoBoneco(item.dados.dadosOriginais)
                        if qAtual then item.quirk = qAtual; q = qAtual end
                    end
                    if q and EhTravada(q) then
                        pulados = pulados + 1
                    elseif not (q and EhDesejada(q)) then
                        table.insert(faltando, p)
                    end
                end
            end

            if #faltando == 0 then todosOk = true; break end

            SetStatus(
                string.format("🔄 Passada %d", passadaAtual),
                string.format("Faltam: %d | 🔒 %d", #faltando, pulados),
                Color3.fromRGB(180, 200, 255),
                CORES.amarelo
            )

            for i, p in ipairs(faltando) do
                if pararSolicitado then break end
                SetStatusThrottled(
                    string.format("🎲 P%d (%d/%d)", passadaAtual, i, #faltando),
                    p.nome,
                    CORES.amarelo,
                    CORES.verdeLabel
                )
                local ok = RolarPersonagem(p)
                if ok then
                    sucessoTotal = sucessoTotal + 1
                    SetStatus(string.format("✅ %s!", p.nome), "Sucesso!", CORES.verdeClaro, Color3.fromRGB(200, 255, 180))
                    task.wait(0.3)
                end
            end
            if pararSolicitado then break end
        end

        rodando = false
        BtnIniciar.Text = "▶ INICIAR"
        BtnIniciar.BackgroundColor3 = CORES.verde

        if pararSolicitado then
            SetStatus("⏸️ Parado", string.format("Sucessos: %d", sucessoTotal), CORES.vermelho)
        elseif todosOk then
            SetStatus("✅ TODOS OK!", string.format("Passadas: %d", passadaAtual), CORES.verdeClaro)
        else
            SetStatus("⚠️ Limite!", string.format("Passadas: %d", passadaAtual), CORES.amarelo)
        end
    end)
end

BtnIniciar.MouseButton1Click:Connect(function()
    pcall(function() IniciarRolagem() end)
end)

BtnParar.MouseButton1Click:Connect(function()
    if rodando then
        pararSolicitado = true
        SetStatus("⏸️ Parando...", "", CORES.vermelho)
    end
end)

Log("✅ Script carregado!")
Log("📋 " .. #listaPersonagens .. " bonecos | GUI criada")
