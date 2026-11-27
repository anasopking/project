--[[
	ConstructorEscena (Script)  ->  ServerScriptService/ConstructorEscena

	Construye un box de urgencias sencillo: piso, paredes, cama, almohada,
	monitor de signos vitales (SurfaceGui), mesa de Mayo, soporte de suero y
	el punto desde donde mira la cámara. Si ya armaste tu propia sala en Studio,
	basta con que exista workspace.SimEscena con las piezas "Colchon",
	"Monitor" (con un SurfaceGui llamado "Pantalla") y "PuntoCamara".
]]

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")

-- Sin personaje: el estudiante ve la escena desde una cámara fija.
Players.CharacterAutoLoads = false

if workspace:FindFirstChild("SimEscena") then
	return -- ya existe una sala hecha a mano
end

local escena = Instance.new("Folder")
escena.Name = "SimEscena"

local function parte(nombre, props)
	local p = Instance.new("Part")
	p.Name = nombre
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in pairs(props) do
		p[k] = v
	end
	p.Parent = escena
	return p
end

-- Sala
parte("Piso", { Size = Vector3.new(40, 1, 40), Position = Vector3.new(0, 0, 4), Color = Color3.fromRGB(196, 204, 212) })
parte("ParedFondo", { Size = Vector3.new(40, 16, 1), Position = Vector3.new(0, 8, 14), Color = Color3.fromRGB(150, 178, 205) })
parte("ParedIzq", { Size = Vector3.new(1, 16, 40), Position = Vector3.new(-14, 8, 4), Color = Color3.fromRGB(160, 186, 212) })
parte("ParedDer", { Size = Vector3.new(1, 16, 40), Position = Vector3.new(14, 8, 4), Color = Color3.fromRGB(160, 186, 212) })
parte("Techo", { Size = Vector3.new(40, 1, 40), Position = Vector3.new(0, 16, 4), Color = Color3.fromRGB(235, 238, 242) })

local lampara = parte("Lampara", {
	Size = Vector3.new(6, 0.3, 3), Position = Vector3.new(0, 15.4, 4),
	Color = Color3.fromRGB(255, 255, 255), Material = Enum.Material.Neon,
})
local luz = Instance.new("SurfaceLight")
luz.Face = Enum.NormalId.Bottom
luz.Brightness = 2
luz.Range = 20
luz.Angle = 120
luz.Parent = lampara

-- Cama
parte("Base", { Size = Vector3.new(4.4, 1, 8.4), Position = Vector3.new(0, 2, 4), Color = Color3.fromRGB(90, 96, 108), Material = Enum.Material.Metal })
for _, x in ipairs({ -1.9, 1.9 }) do
	for _, z in ipairs({ 0.2, 7.8 }) do
		parte("Pata", { Size = Vector3.new(0.4, 1.5, 0.4), Position = Vector3.new(x, 1.25, z), Color = Color3.fromRGB(70, 74, 84), Material = Enum.Material.Metal })
	end
end
parte("Colchon", { Size = Vector3.new(4, 0.6, 8), Position = Vector3.new(0, 2.8, 4), Color = Color3.fromRGB(235, 240, 245), Material = Enum.Material.Fabric })
parte("Almohada", { Size = Vector3.new(2.8, 0.35, 1.3), Position = Vector3.new(0, 3.25, 7.2), Color = Color3.fromRGB(120, 170, 220), Material = Enum.Material.Fabric })
parte("Cabecera", { Size = Vector3.new(4.4, 3, 0.3), Position = Vector3.new(0, 3.5, 8.3), Color = Color3.fromRGB(90, 96, 108), Material = Enum.Material.Metal })

-- Soporte de suero
parte("Poste", { Size = Vector3.new(0.2, 7, 0.2), Position = Vector3.new(-3, 4, 7), Color = Color3.fromRGB(180, 185, 190), Material = Enum.Material.Metal })
parte("Suero", { Size = Vector3.new(0.6, 1, 0.3), Position = Vector3.new(-3, 7, 6.8), Color = Color3.fromRGB(220, 235, 255), Transparency = 0.3, Material = Enum.Material.Glass })

-- Mesa de Mayo
parte("Mesa", { Size = Vector3.new(2.5, 0.2, 1.6), Position = Vector3.new(-4, 3.6, 2), Color = Color3.fromRGB(200, 205, 210), Material = Enum.Material.Metal })
parte("PataMesa", { Size = Vector3.new(0.2, 3.5, 0.2), Position = Vector3.new(-4, 1.8, 2), Color = Color3.fromRGB(150, 155, 160), Material = Enum.Material.Metal })

-- Monitor de signos vitales
parte("BrazoMonitor", { Size = Vector3.new(0.3, 5.5, 0.3), Position = Vector3.new(4.2, 3.2, 8), Color = Color3.fromRGB(70, 74, 84), Material = Enum.Material.Metal })
local monitor = parte("Monitor", {
	Size = Vector3.new(3.6, 2.4, 0.4), Position = Vector3.new(4.2, 6.6, 8),
	Color = Color3.fromRGB(25, 28, 36),
	CFrame = CFrame.new(Vector3.new(4.2, 6.6, 8), Vector3.new(0, 6, -4)),
})

local gui = Instance.new("SurfaceGui")
gui.Name = "Pantalla"
gui.Face = Enum.NormalId.Front
gui.CanvasSize = Vector2.new(360, 240)
gui.LightInfluence = 0
gui.Parent = monitor

local fondo = Instance.new("Frame")
fondo.Size = UDim2.fromScale(1, 1)
fondo.BackgroundColor3 = Color3.fromRGB(5, 8, 14)
fondo.Parent = gui

local function celda(nombre, etiqueta, color, x, y)
	local f = Instance.new("Frame")
	f.BackgroundTransparency = 1
	f.Position = UDim2.fromScale(x, y)
	f.Size = UDim2.fromScale(0.5, 0.5)
	f.Parent = fondo
	local e = Instance.new("TextLabel")
	e.BackgroundTransparency = 1
	e.Size = UDim2.fromScale(1, 0.3)
	e.Font = Enum.Font.GothamBold
	e.TextScaled = true
	e.TextColor3 = color
	e.TextXAlignment = Enum.TextXAlignment.Left
	e.Text = "  " .. etiqueta
	e.Parent = f
	local valor = Instance.new("TextLabel")
	valor.Name = nombre
	valor.BackgroundTransparency = 1
	valor.Position = UDim2.fromScale(0, 0.3)
	valor.Size = UDim2.fromScale(1, 0.7)
	valor.Font = Enum.Font.GothamBold
	valor.TextScaled = true
	valor.TextColor3 = color
	valor.Text = "--"
	valor.Parent = f
end
celda("FC", "FC", Color3.fromRGB(0, 230, 118), 0, 0)
celda("SpO2", "SpO₂", Color3.fromRGB(0, 200, 255), 0.5, 0)
celda("PA", "PA", Color3.fromRGB(255, 82, 82), 0, 0.5)
celda("FR", "FR", Color3.fromRGB(255, 214, 0), 0.5, 0.5)

-- Cámara: a los pies de la cama, elevada, mirando al paciente.
local camara = parte("PuntoCamara", {
	Size = Vector3.new(0.2, 0.2, 0.2), Position = Vector3.new(-1.5, 10, -5.5),
	Transparency = 1, CanCollide = false, CanQuery = false,
})
camara:SetAttribute("Objetivo", Vector3.new(1.6, 3.8, 5))

-- Iluminación clínica
Lighting.ClockTime = 13
Lighting.Brightness = 2
Lighting.Ambient = Color3.fromRGB(120, 125, 135)
Lighting.OutdoorAmbient = Color3.fromRGB(140, 145, 155)

escena.Parent = workspace
