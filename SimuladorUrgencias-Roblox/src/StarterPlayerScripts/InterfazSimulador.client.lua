--[[
	InterfazSimulador (LocalScript)  ->  StarterPlayer/StarterPlayerScripts/InterfazSimulador

	Toda la interfaz se construye por código: menú de casos, barra superior con
	reloj clínico, barra lateral de acciones, monitor de signos vitales, ventana
	de diálogo con el paciente, paneles de exploración / pruebas / tratamiento /
	resultados / diagnóstico y pantalla de debriefing.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local TextChatService = game:GetService("TextChatService")
local RunService = game:GetService("RunService")

local jugador = Players.LocalPlayer
local remotos = ReplicatedStorage:WaitForChild("SimRemotos")
local Accion = remotos:WaitForChild("Accion")
local Actualizar = remotos:WaitForChild("Actualizar")
local ObtenerCasos = remotos:WaitForChild("ObtenerCasos")

--------------------------------------------------------------------------------
-- Estilo
--------------------------------------------------------------------------------
local C = {
	fondo = Color3.fromRGB(14, 20, 38),
	panel = Color3.fromRGB(24, 33, 58),
	panel2 = Color3.fromRGB(34, 46, 78),
	acento = Color3.fromRGB(38, 198, 218),
	acentoOscuro = Color3.fromRGB(22, 140, 160),
	texto = Color3.fromRGB(240, 244, 250),
	suave = Color3.fromRGB(160, 176, 204),
	burbujaMed = Color3.fromRGB(235, 240, 248),
	burbujaPac = Color3.fromRGB(214, 226, 242),
	ok = Color3.fromRGB(76, 200, 120),
	alerta = Color3.fromRGB(255, 190, 60),
	error = Color3.fromRGB(240, 80, 80),
	fc = Color3.fromRGB(0, 230, 118),
	spo2 = Color3.fromRGB(0, 200, 255),
	pa = Color3.fromRGB(255, 92, 92),
	fr = Color3.fromRGB(255, 214, 0),
	temp = Color3.fromRGB(240, 240, 240),
}
local F = { normal = Enum.Font.Gotham, medio = Enum.Font.GothamMedium, negrita = Enum.Font.GothamBold }

local function nuevo(clase, props, hijos)
	local o = Instance.new(clase)
	local padre
	for k, v in pairs(props or {}) do
		if k == "Parent" then
			padre = v
		else
			o[k] = v
		end
	end
	for _, h in ipairs(hijos or {}) do
		h.Parent = o
	end
	if padre then
		o.Parent = padre
	end
	return o
end

local function esquinas(r)
	return nuevo("UICorner", { CornerRadius = UDim.new(0, r or 10) })
end

local function relleno(p)
	return nuevo("UIPadding", {
		PaddingTop = UDim.new(0, p), PaddingBottom = UDim.new(0, p),
		PaddingLeft = UDim.new(0, p), PaddingRight = UDim.new(0, p),
	})
end

local function lista(espacio, horizontal)
	return nuevo("UIListLayout", {
		Padding = UDim.new(0, espacio or 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		FillDirection = horizontal and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical,
	})
end

local function texto(props)
	local base = {
		BackgroundTransparency = 1,
		Font = F.normal,
		TextColor3 = C.texto,
		TextSize = 16,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		RichText = true,
	}
	for k, v in pairs(props) do
		base[k] = v
	end
	return nuevo("TextLabel", base)
end

local function boton(props, alClic)
	local base = {
		AutoButtonColor = true,
		BackgroundColor3 = C.acento,
		Font = F.medio,
		TextColor3 = C.texto,
		TextSize = 16,
		TextWrapped = true,
	}
	for k, v in pairs(props) do
		base[k] = v
	end
	local b = nuevo("TextButton", base, { esquinas(8) })
	if alClic then
		b.MouseButton1Click:Connect(alClic)
	end
	return b
end

local function reloj(seg)
	seg = math.max(0, math.floor(seg or 0))
	return string.format("%02d:%02d:%02d", seg // 3600, (seg % 3600) // 60, seg % 60)
end

local function escapar(s)
	s = string.gsub(s, "&", "&amp;")
	s = string.gsub(s, "<", "&lt;")
	s = string.gsub(s, ">", "&gt;")
	return s
end

--------------------------------------------------------------------------------
-- Cámara fija sobre el paciente
--------------------------------------------------------------------------------
local camara = workspace.CurrentCamera
task.spawn(function()
	local escena = workspace:WaitForChild("SimEscena")
	local punto = escena:WaitForChild("PuntoCamara")
	camara.CameraType = Enum.CameraType.Scriptable
	camara.FieldOfView = 55
	RunService.RenderStepped:Connect(function()
		camara.CameraType = Enum.CameraType.Scriptable
		camara.CFrame = CFrame.lookAt(punto.Position, punto:GetAttribute("Objetivo") or Vector3.new(0, 3.5, 5))
	end)
end)

--------------------------------------------------------------------------------
-- Raíz de la interfaz
--------------------------------------------------------------------------------
local gui = nuevo("ScreenGui", {
	Name = "SimUrgenciasUI",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = jugador:WaitForChild("PlayerGui"),
})

local casoActual = nil
local ultimoT = 0

--------------------------------------------------------------------------------
-- HUD
--------------------------------------------------------------------------------
local hud = nuevo("Frame", { Name = "HUD", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, Parent = gui })

-- Barra superior
local barra = nuevo("Frame", {
	BackgroundColor3 = C.fondo, BackgroundTransparency = 0.05,
	Size = UDim2.new(1, 0, 0, 56), Parent = hud,
})
texto({ Text = "SIM<font color=\"#26C6DA\">·</font>URGENCIAS", Font = F.negrita, TextSize = 22,
	Position = UDim2.fromOffset(20, 0), Size = UDim2.new(0, 260, 1, 0), TextYAlignment = Enum.TextYAlignment.Center, Parent = barra })
local lblPaciente = texto({ Text = "", TextSize = 16, TextColor3 = C.suave,
	Position = UDim2.fromOffset(280, 0), Size = UDim2.new(0.45, 0, 1, 0), TextYAlignment = Enum.TextYAlignment.Center, Parent = barra })
local lblReloj = texto({ Text = "T+ 00:00:00", Font = F.negrita, TextSize = 20, TextColor3 = C.acento,
	AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -330, 0, 0), Size = UDim2.fromOffset(150, 56),
	TextXAlignment = Enum.TextXAlignment.Right, TextYAlignment = Enum.TextYAlignment.Center, Parent = barra })

local velocidades = { 1, 3, 6 }
local iVel = 1
local btnVel
btnVel = boton({ Text = "▶ x1", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -170, 0.5, 0),
	Size = UDim2.fromOffset(70, 36), BackgroundColor3 = C.panel2, Parent = barra }, function()
	iVel = iVel % #velocidades + 1
	btnVel.Text = "▶ x" .. velocidades[iVel]
	Accion:FireServer("velocidad", velocidades[iVel])
end)
boton({ Text = "Terminar caso", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -16, 0.5, 0),
	Size = UDim2.fromOffset(140, 36), BackgroundColor3 = C.error, Parent = barra }, function()
	Accion:FireServer("finalizar")
end)

-- Barra lateral de acciones
local lateral = nuevo("Frame", {
	BackgroundColor3 = C.fondo, BackgroundTransparency = 0.1,
	Position = UDim2.fromOffset(12, 70), Size = UDim2.fromOffset(92, 470), Parent = hud,
}, { esquinas(14), relleno(8), lista(8) })

-- Panel izquierdo de contenido (exploración, pruebas, etc.)
local panel = nuevo("Frame", {
	BackgroundColor3 = C.panel, BackgroundTransparency = 0.04,
	Position = UDim2.fromOffset(114, 70), Size = UDim2.new(0, 400, 1, -150), Visible = false, Parent = hud,
}, { esquinas(14) })
local panelTitulo = texto({ Text = "", Font = F.negrita, TextSize = 20, Position = UDim2.fromOffset(16, 10),
	Size = UDim2.new(1, -60, 0, 30), Parent = panel })
boton({ Text = "✕", BackgroundColor3 = C.panel2, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 10),
	Size = UDim2.fromOffset(30, 30), Parent = panel }, function()
	panel.Visible = false
end)
local panelLista = nuevo("ScrollingFrame", {
	BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(10, 50), Size = UDim2.new(1, -20, 1, -60),
	CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 6, Parent = panel,
}, { lista(6) })

-- Monitor de signos vitales (arriba a la derecha)
local monitor = nuevo("Frame", {
	BackgroundColor3 = Color3.fromRGB(6, 10, 18), BackgroundTransparency = 0.05,
	AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 70), Size = UDim2.fromOffset(420, 190), Parent = hud,
}, { esquinas(14), nuevo("UIStroke", { Color = Color3.fromRGB(50, 60, 90), Thickness = 1 }) })
local celdas = {}
local function celdaMonitor(clave, etiqueta, unidad, color, x, y, ancho)
	local f = nuevo("Frame", { BackgroundTransparency = 1, Position = UDim2.fromScale(x, y), Size = UDim2.fromScale(ancho or 1 / 3, 0.5), Parent = monitor })
	texto({ Text = etiqueta, Font = F.negrita, TextSize = 13, TextColor3 = color, Position = UDim2.fromOffset(12, 8), Size = UDim2.new(1, -16, 0, 16), Parent = f })
	texto({ Text = unidad, TextSize = 11, TextColor3 = C.suave, Position = UDim2.fromOffset(12, 24), Size = UDim2.new(1, -16, 0, 14), Parent = f })
	celdas[clave] = texto({ Text = "--", Font = F.negrita, TextSize = 38, TextColor3 = color,
		Position = UDim2.fromOffset(12, 36), Size = UDim2.new(1, -16, 0, 50), TextXAlignment = Enum.TextXAlignment.Right, Parent = f })
end
celdaMonitor("fc", "FC  ♥", "lpm", C.fc, 0, 0)
celdaMonitor("spo2", "SpO₂", "%", C.spo2, 1 / 3, 0)
celdaMonitor("fr", "FR", "rpm", C.fr, 2 / 3, 0)
celdaMonitor("pa", "PA (PAM)", "mmHg", C.pa, 0, 0.5, 2 / 3)
celdaMonitor("temp", "Temp", "°C", C.temp, 2 / 3, 0.5)

local latido = texto({ Text = "♥", Font = F.negrita, TextSize = 22, TextColor3 = C.fc,
	Position = UDim2.fromOffset(60, 4), Size = UDim2.fromOffset(24, 24), Parent = monitor })

-- Ventana de diálogo (derecha, debajo del monitor)
local dialogo = nuevo("Frame", {
	BackgroundColor3 = C.burbujaMed, BackgroundTransparency = 0.05,
	AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 272), Size = UDim2.new(0, 420, 1, -284), Parent = hud,
}, { esquinas(14) })
texto({ Text = "Diálogo", Font = F.negrita, TextSize = 18, TextColor3 = Color3.fromRGB(30, 40, 60),
	Position = UDim2.fromOffset(16, 10), Size = UDim2.new(1, -32, 0, 24), Parent = dialogo })
local chat = nuevo("ScrollingFrame", {
	BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(10, 40), Size = UDim2.new(1, -20, 1, -150),
	CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 5,
	ScrollBarImageColor3 = Color3.fromRGB(120, 130, 150), Parent = dialogo,
}, { lista(8) })
local sugerencias = nuevo("ScrollingFrame", {
	BackgroundTransparency = 1, BorderSizePixel = 0, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 10, 1, -62),
	Size = UDim2.new(1, -20, 0, 40), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.X,
	ScrollingDirection = Enum.ScrollingDirection.X, ScrollBarThickness = 3, Parent = dialogo,
}, { lista(6, true) })
local entradaMarco = nuevo("Frame", {
	BackgroundColor3 = Color3.fromRGB(255, 255, 255), AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 10, 1, -10),
	Size = UDim2.new(1, -20, 0, 44), Parent = dialogo,
}, { esquinas(10), nuevo("UIStroke", { Color = C.acento, Thickness = 1.5 }) })
local entrada = nuevo("TextBox", {
	BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -70, 1, 0),
	Font = F.normal, TextSize = 16, TextColor3 = Color3.fromRGB(30, 40, 60), PlaceholderText = "Escribe tu pregunta al paciente…",
	PlaceholderColor3 = Color3.fromRGB(140, 150, 170), Text = "", ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Left,
	Parent = entradaMarco,
})

local orden = 0
local function mensaje(quien, contenido, esMedico)
	orden += 1
	local m = nuevo("Frame", {
		BackgroundColor3 = esMedico and Color3.fromRGB(255, 255, 255) or C.burbujaPac,
		Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = orden, Parent = chat,
	}, { esquinas(10), relleno(10), lista(4) })
	texto({ Text = string.format("<b>%s</b>  <font color=\"#8A94A8\">%s</font>", escapar(quien), reloj(ultimoT)),
		TextSize = 13, TextColor3 = Color3.fromRGB(70, 80, 100), Size = UDim2.new(1, 0, 0, 16), LayoutOrder = 1, Parent = m })
	texto({ Text = escapar(contenido), TextSize = 15, TextColor3 = Color3.fromRGB(30, 40, 60),
		Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, Parent = m })
	task.defer(function()
		chat.CanvasPosition = Vector2.new(0, math.max(0, chat.AbsoluteCanvasSize.Y - chat.AbsoluteSize.Y))
	end)
end

local function enviarPregunta(t)
	t = string.gsub(t or "", "^%s+", "")
	if #t == 0 then
		return
	end
	mensaje("Tú (médico)", t, true)
	Accion:FireServer("preguntar", t)
	entrada.Text = ""
end
entrada.FocusLost:Connect(function(enter)
	if enter then
		enviarPregunta(entrada.Text)
	end
end)
boton({ Text = "➤", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0), Size = UDim2.fromOffset(44, 34),
	Parent = entradaMarco }, function()
	enviarPregunta(entrada.Text)
end)

-- Notificaciones flotantes
local avisos = nuevo("Frame", {
	BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, -100, 0, 66),
	Size = UDim2.fromOffset(460, 400), Parent = hud,
}, { lista(6) })
local function notificar(t, nivel)
	local color = ({ ok = C.ok, alerta = C.alerta, error = C.error })[nivel] or C.acentoOscuro
	local n = nuevo("Frame", {
		BackgroundColor3 = color, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = avisos,
	}, { esquinas(10), relleno(10) })
	texto({ Text = escapar(t), Font = F.medio, TextSize = 15, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = n })
	task.delay(nivel == "error" and 9 or 5, function()
		n:Destroy()
	end)
end

--------------------------------------------------------------------------------
-- Resultados (registro de lo explorado y de las pruebas)
--------------------------------------------------------------------------------
local resultados = {} -- lista ordenada {titulo, texto, estado, listoEn}
local panelActual = nil

local function filaResultado(r, ordenFila)
	local f = nuevo("Frame", {
		BackgroundColor3 = C.panel2, Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = ordenFila, Parent = panelLista,
	}, { esquinas(8), relleno(10), lista(4) })
	local estado
	if r.estado == "pendiente" then
		estado = string.format("<font color=\"#FFBE3C\">Pendiente · listo en %s</font>", reloj(r.listoEn - ultimoT))
	else
		estado = string.format("<font color=\"#26C6DA\">%s · %s</font>", r.tipo, reloj(r.t))
	end
	texto({ Text = "<b>" .. escapar(r.titulo) .. "</b>   " .. estado, TextSize = 14, Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1, Parent = f })
	if r.texto then
		texto({ Text = escapar(r.texto), TextSize = 14, TextColor3 = C.suave, Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, Parent = f })
	end
end

local function limpiarPanel()
	for _, h in ipairs(panelLista:GetChildren()) do
		if not h:IsA("UIListLayout") then
			h:Destroy()
		end
	end
end

local mostrarPanel -- declarada abajo

local function refrescarResultados(soloSiPendientes)
	if panelActual ~= "resultados" or not panel.Visible then
		return
	end
	if soloSiPendientes then
		local hay = false
		for _, r in ipairs(resultados) do
			if r.estado == "pendiente" then
				hay = true
				break
			end
		end
		if not hay then
			return
		end
	end
	local pos = panelLista.CanvasPosition
	mostrarPanel("resultados")
	task.defer(function()
		panelLista.CanvasPosition = pos
	end)
end

--------------------------------------------------------------------------------
-- Paneles de acciones
--------------------------------------------------------------------------------
local function porGrupos(items, alClic, sufijo)
	local grupos, ordenGrupos = {}, {}
	for _, it in ipairs(items) do
		if not grupos[it.grupo] then
			grupos[it.grupo] = {}
			table.insert(ordenGrupos, it.grupo)
		end
		table.insert(grupos[it.grupo], it)
	end
	local n = 0
	for _, g in ipairs(ordenGrupos) do
		n += 1
		texto({ Text = string.upper(g), Font = F.negrita, TextSize = 12, TextColor3 = C.acento,
			Size = UDim2.new(1, -8, 0, 20), TextYAlignment = Enum.TextYAlignment.Bottom, LayoutOrder = n, Parent = panelLista })
		for _, it in ipairs(grupos[g]) do
			n += 1
			local etiqueta = it.nombre .. (sufijo and sufijo(it) or "")
			boton({ Text = etiqueta, BackgroundColor3 = C.panel2, TextXAlignment = Enum.TextXAlignment.Left, TextSize = 15,
				Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = n, Parent = panelLista },
				function()
					alClic(it)
				end):SetAttribute("id", it.id)
		end
	end
	for _, b in ipairs(panelLista:GetChildren()) do
		if b:IsA("TextButton") then
			relleno(10).Parent = b
		end
	end
end

local function confirmar(pregunta, alAceptar)
	local capa = nuevo("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45, Size = UDim2.fromScale(1, 1), ZIndex = 20, Parent = gui })
	local caja = nuevo("Frame", { BackgroundColor3 = C.panel, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(460, 190), ZIndex = 21, Parent = capa }, { esquinas(14) })
	texto({ Text = pregunta, TextSize = 17, Position = UDim2.fromOffset(20, 20), Size = UDim2.new(1, -40, 0, 100), ZIndex = 22, Parent = caja })
	boton({ Text = "Cancelar", BackgroundColor3 = C.panel2, Position = UDim2.new(0, 20, 1, -60), Size = UDim2.new(0.5, -30, 0, 40), ZIndex = 22, Parent = caja },
		function() capa:Destroy() end)
	boton({ Text = "Confirmar", Position = UDim2.new(0.5, 10, 1, -60), Size = UDim2.new(0.5, -30, 0, 40), ZIndex = 22, Parent = caja },
		function() capa:Destroy(); alAceptar() end)
end

local diagnosticoElegido = nil

function mostrarPanel(nombre)
	if not casoActual then
		return
	end
	panelActual = nombre
	limpiarPanel()
	panel.Visible = true

	if nombre == "exploracion" then
		panelTitulo.Text = "🩺  Exploración física"
		porGrupos(casoActual.exploracion, function(it)
			Accion:FireServer("explorar", it.id)
		end)
	elseif nombre == "pruebas" then
		panelTitulo.Text = "🧪  Pruebas diagnósticas"
		porGrupos(casoActual.pruebas, function(it)
			Accion:FireServer("prueba", it.id)
		end, function(it)
			local m = math.floor(it.tiempo / 60)
			return m >= 60 and string.format("   (~%d h)", m // 60) or string.format("   (~%d min)", math.max(1, m))
		end)
	elseif nombre == "tratamiento" then
		panelTitulo.Text = "💊  Tratamiento"
		porGrupos(casoActual.tratamientos, function(it)
			confirmar("¿Indicar?\n\n<b>" .. escapar(it.nombre) .. "</b>", function()
				Accion:FireServer("tratar", it.id)
			end)
		end)
	elseif nombre == "resultados" then
		panelTitulo.Text = "📄  Resultados y hallazgos"
		if #resultados == 0 then
			texto({ Text = "Aún no hay hallazgos. Explora al paciente o solicita pruebas.", TextColor3 = C.suave,
				Size = UDim2.new(1, -8, 0, 40), Parent = panelLista })
		end
		for i = #resultados, 1, -1 do
			filaResultado(resultados[i], #resultados - i)
		end
	elseif nombre == "diagnostico" then
		panelTitulo.Text = "📋  Impresión diagnóstica"
		texto({ Text = "Elige tu diagnóstico principal. Puedes cambiarlo antes de terminar el caso.", TextColor3 = C.suave,
			TextSize = 14, Size = UDim2.new(1, -8, 0, 40), LayoutOrder = 0, Parent = panelLista })
		for i, d in ipairs(casoActual.diagnosticos) do
			local elegido = diagnosticoElegido == d.id
			boton({ Text = (elegido and "●  " or "○  ") .. d.nombre, TextXAlignment = Enum.TextXAlignment.Left,
				BackgroundColor3 = elegido and C.acentoOscuro or C.panel2, Size = UDim2.new(1, -8, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = i, Parent = panelLista }, function()
				diagnosticoElegido = d.id
				Accion:FireServer("diagnostico", d.id)
				mostrarPanel("diagnostico")
			end)
		end
		boton({ Text = "Terminar caso y ver debriefing", BackgroundColor3 = C.ok, Size = UDim2.new(1, -8, 0, 44),
			LayoutOrder = 999, Parent = panelLista }, function()
			confirmar("¿Terminar el caso? Se evaluará lo que hiciste hasta ahora.", function()
				Accion:FireServer("finalizar")
			end)
		end)
		for _, b in ipairs(panelLista:GetChildren()) do
			if b:IsA("TextButton") then
				relleno(10).Parent = b
			end
		end
	end
end

local function botonLateral(icono, nombre, alClic)
	local b = boton({ Text = "", BackgroundColor3 = C.panel2, Size = UDim2.new(1, 0, 0, 68) }, alClic)
	texto({ Text = icono, TextSize = 26, Size = UDim2.new(1, 0, 0, 38), TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center, Parent = b })
	texto({ Text = nombre, TextSize = 11, Font = F.medio, Position = UDim2.fromOffset(0, 40), Size = UDim2.new(1, 0, 0, 20),
		TextXAlignment = Enum.TextXAlignment.Center, Parent = b })
	b.Parent = lateral
	return b
end
botonLateral("💬", "Diálogo", function()
	panel.Visible = false
	entrada:CaptureFocus()
end)
botonLateral("🩺", "Exploración", function() mostrarPanel("exploracion") end)
botonLateral("🧪", "Pruebas", function() mostrarPanel("pruebas") end)
botonLateral("💊", "Tratamiento", function() mostrarPanel("tratamiento") end)
botonLateral("📄", "Resultados", function() mostrarPanel("resultados") end)
botonLateral("📋", "Diagnóstico", function() mostrarPanel("diagnostico") end)

--------------------------------------------------------------------------------
-- Menú de inicio
--------------------------------------------------------------------------------
local menu = nuevo("Frame", { BackgroundColor3 = C.fondo, Size = UDim2.fromScale(1, 1), Parent = gui })
nuevo("UIGradient", {
	Color = ColorSequence.new(Color3.fromRGB(14, 20, 38), Color3.fromRGB(20, 60, 90)), Rotation = 35, Parent = menu,
})
texto({ Text = "SIM<font color=\"#26C6DA\">·</font>URGENCIAS", Font = F.negrita, TextSize = 46,
	Position = UDim2.new(0, 60, 0, 50), Size = UDim2.new(1, -120, 0, 60), Parent = menu })
texto({ Text = "Simulador de pacientes virtuales para el estudio del manejo en urgencias.\nPregunta, explora, solicita estudios, trata… y recibe retroalimentación basada en guías.",
	TextSize = 18, TextColor3 = C.suave, Position = UDim2.new(0, 60, 0, 115), Size = UDim2.new(1, -120, 0, 60), Parent = menu })

local tarjetas = nuevo("ScrollingFrame", {
	BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.new(0, 60, 0, 200), Size = UDim2.new(1, -120, 1, -300),
	CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 6, Parent = menu,
}, { nuevo("UIGridLayout", { CellSize = UDim2.fromOffset(340, 230), CellPadding = UDim2.fromOffset(20, 20), SortOrder = Enum.SortOrder.LayoutOrder }) })

texto({ Text = "Herramienta educativa. Los escenarios simplifican la fisiología y no sustituyen el juicio clínico, la supervisión docente ni los protocolos de tu institución.",
	TextSize = 13, TextColor3 = C.suave, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 60, 1, -30),
	Size = UDim2.new(1, -120, 0, 40), Parent = menu })

local colorDificultad = { ["Básico"] = C.ok, ["Intermedio"] = C.alerta, ["Avanzado"] = C.error }

local function cargarMenu()
	local ok, casos = pcall(function()
		return ObtenerCasos:InvokeServer()
	end)
	if not ok or type(casos) ~= "table" then
		warn("[SimUrgencias] No se pudieron cargar los casos")
		return
	end
	for i, caso in ipairs(casos) do
		local t = nuevo("Frame", { BackgroundColor3 = C.panel, LayoutOrder = i, Parent = tarjetas }, { esquinas(16), relleno(18) })
		texto({ Text = string.upper(caso.dificultad or ""), Font = F.negrita, TextSize = 12,
			TextColor3 = colorDificultad[caso.dificultad] or C.acento, Size = UDim2.new(1, 0, 0, 16), Parent = t })
		texto({ Text = caso.titulo, Font = F.negrita, TextSize = 22, Position = UDim2.fromOffset(0, 20), Size = UDim2.new(1, 0, 0, 30), Parent = t })
		texto({ Text = caso.area or "", TextSize = 13, TextColor3 = C.acento, Position = UDim2.fromOffset(0, 52), Size = UDim2.new(1, 0, 0, 18), Parent = t })
		texto({ Text = caso.resumen, TextSize = 15, TextColor3 = C.suave, Position = UDim2.fromOffset(0, 76), Size = UDim2.new(1, 0, 0, 60), Parent = t })
		boton({ Text = "Iniciar caso", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 42), Parent = t },
			function()
				Accion:FireServer("iniciar", caso.id)
			end)
	end
end

--------------------------------------------------------------------------------
-- Debriefing
--------------------------------------------------------------------------------
local debrief = nuevo("Frame", { BackgroundColor3 = C.fondo, Size = UDim2.fromScale(1, 1), Visible = false, ZIndex = 10, Parent = gui })
local debriefLista = nuevo("ScrollingFrame", {
	BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.new(0.5, -440, 0, 30), Size = UDim2.new(0, 880, 1, -110),
	CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 6, ZIndex = 10, Parent = debrief,
}, { lista(10) })

local function mostrarDebrief(inf)
	for _, h in ipairs(debriefLista:GetChildren()) do
		if not h:IsA("UIListLayout") then
			h:Destroy()
		end
	end
	local n = 0
	local function bloque(titulo, lineas, color)
		n += 1
		local f = nuevo("Frame", { BackgroundColor3 = C.panel, Size = UDim2.new(1, -10, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = n, ZIndex = 10, Parent = debriefLista }, { esquinas(12), relleno(16), lista(6) })
		texto({ Text = titulo, Font = F.negrita, TextSize = 19, TextColor3 = color or C.acento, Size = UDim2.new(1, 0, 0, 24), ZIndex = 10, Parent = f })
		for i, l in ipairs(lineas) do
			texto({ Text = l, TextSize = 15, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = i, ZIndex = 10, Parent = f })
		end
	end

	local pct = math.floor(100 * inf.puntos / math.max(1, inf.maximo) + 0.5)
	local colorPct = pct >= 80 and C.ok or (pct >= 60 and C.alerta or C.error)
	bloque("Debriefing · " .. inf.titulo .. " · " .. inf.paciente, {
		string.format("<font size=\"40\"><b>%d%%</b></font>   (%d / %d puntos)", pct, inf.puntos, inf.maximo),
		(inf.paro and "<font color=\"#F05050\"><b>" or "<font color=\"#4CC878\"><b>") .. escapar(inf.resultado) .. "</b></font>",
		"Tiempo clínico transcurrido: " .. reloj(inf.duracion),
	}, colorPct)

	local obj = {}
	for _, o in ipairs(inf.objetivos) do
		local marca = o.cumplido and "<font color=\"#4CC878\">✔</font>" or (o.tarde and "<font color=\"#FFBE3C\">◷</font>" or "<font color=\"#F05050\">✘</font>")
		local cuando = o.tiempo and (" · " .. reloj(o.tiempo)) or " · no realizado"
		local lim = o.limite and (" (límite " .. reloj(o.limite) .. ")") or ""
		local linea = marca .. "  " .. escapar(o.texto) .. "<font color=\"#A0B0CC\">" .. cuando .. lim .. "</font>"
		if o.fuente and not o.cumplido then
			linea ..= "\n     <font color=\"#A0B0CC\"><i>" .. escapar(o.fuente) .. "</i></font>"
		end
		table.insert(obj, linea)
	end
	bloque("Acciones críticas", obj)

	local a = inf.anamnesis
	local anam = { string.format("Exploraste %d de %d áreas de la historia clínica (%d pts).", a.hechas, a.total, a.puntos) }
	if #a.faltantes > 0 then
		table.insert(anam, "<font color=\"#FFBE3C\">Faltó preguntar por:</font> " .. escapar(table.concat(a.faltantes, " · ")))
	end
	bloque("Anamnesis", anam)

	local d = inf.diagnostico
	bloque("Diagnóstico", {
		(d.correcto and "<font color=\"#4CC878\">✔ Correcto:</font> " or "<font color=\"#F05050\">✘ Tu respuesta:</font> ") .. escapar(d.elegido),
		d.correcto and "" or ("Diagnóstico esperado: <b>" .. escapar(d.esperado or "") .. "</b>"),
		"<font color=\"#A0B0CC\">" .. escapar(d.explicacion or "") .. "</font>",
	})

	if #inf.errores > 0 then
		local e = {}
		for _, x in ipairs(inf.errores) do
			table.insert(e, string.format("%s  %s  <font color=\"#A0B0CC\">(-%d · %s)</font>",
				x.grave and "<font color=\"#F05050\">⚠</font>" or "<font color=\"#FFBE3C\">•</font>", escapar(x.texto), x.puntos, reloj(x.t)))
		end
		bloque("Errores y oportunidades de mejora", e, C.alerta)
	end

	local doc = {}
	for _, x in ipairs(inf.docencia or {}) do
		table.insert(doc, "• " .. escapar(x))
	end
	bloque("Puntos docentes", doc)

	local ref = {}
	for _, x in ipairs(inf.referencias or {}) do
		table.insert(ref, "<font color=\"#A0B0CC\">" .. escapar(x) .. "</font>")
	end
	bloque("Referencias", ref)

	local bit = {}
	for _, x in ipairs(inf.bitacora or {}) do
		table.insert(bit, "<font color=\"#26C6DA\">" .. reloj(x.t) .. "</font>  " .. escapar(x.texto))
	end
	bloque("Línea de tiempo", bit)

	debriefLista.CanvasPosition = Vector2.new()
	debrief.Visible = true
	hud.Visible = false
end

boton({ Text = "Volver al menú de casos", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -20),
	Size = UDim2.fromOffset(300, 46), ZIndex = 11, Parent = debrief }, function()
	debrief.Visible = false
	menu.Visible = true
end)

--------------------------------------------------------------------------------
-- Mensajes del servidor
--------------------------------------------------------------------------------
local fcActual = 0

local function burbujaPaciente(t)
	local paciente = workspace:FindFirstChild("SimEscena") and workspace.SimEscena:FindFirstChild("Paciente")
	local cabeza = paciente and paciente:FindFirstChild("Head")
	if cabeza then
		pcall(function()
			TextChatService:DisplayBubble(cabeza, t)
		end)
	end
end

local function pintarSignos(v)
	fcActual = v.fc
	celdas.fc.Text = tostring(v.fc)
	celdas.spo2.Text = tostring(v.spo2)
	celdas.fr.Text = tostring(v.fr)
	celdas.pa.Text = string.format("%d/%d <font size=\"22\">(%d)</font>", v.pas, v.pad, v.pam)
	celdas.temp.Text = string.format("%.1f", v.temp)
	-- alarmas visuales
	celdas.spo2.TextColor3 = v.spo2 < 90 and C.error or C.spo2
	celdas.pa.TextColor3 = v.pam < 65 and C.error or C.pa
	celdas.fc.TextColor3 = (v.fc < 50 or v.fc > 120) and C.alerta or C.fc
end

Actualizar.OnClientEvent:Connect(function(p)
	if p.t then
		ultimoT = p.t
	end
	if p.tipo == "inicio" then
		casoActual = p.caso
		resultados = {}
		diagnosticoElegido = nil
		iVel = 1
		btnVel.Text = "▶ x1"
		for _, h in ipairs(chat:GetChildren()) do
			if not h:IsA("UIListLayout") then
				h:Destroy()
			end
		end
		for _, h in ipairs(sugerencias:GetChildren()) do
			if not h:IsA("UIListLayout") then
				h:Destroy()
			end
		end
		for _, q in ipairs(casoActual.preguntasSugeridas or {}) do
			local b = boton({ Text = q, TextSize = 13, BackgroundColor3 = C.acentoOscuro, Size = UDim2.fromOffset(0, 32),
				AutomaticSize = Enum.AutomaticSize.X, Parent = sugerencias }, function()
				enviarPregunta(q)
			end)
			relleno(8).Parent = b
		end
		local pac = casoActual.paciente
		lblPaciente.Text = string.format("<b>%s</b> · %d años · %s · %d kg   |   %s",
			escapar(pac.nombre), pac.edad, pac.sexo, pac.peso, escapar(casoActual.titulo))
		pintarSignos(p.signos)
		menu.Visible = false
		debrief.Visible = false
		panel.Visible = false
		hud.Visible = true
		mensaje("Enfermería", "Paciente en el box 3. " .. casoActual.resumen .. " Ya está en la cama, monitorizado con signos iniciales.", false)
	elseif p.tipo == "signos" then
		lblReloj.Text = "T+ " .. reloj(p.t)
		pintarSignos(p.v)
		refrescarResultados(true) -- actualiza las cuentas regresivas
	elseif p.tipo == "dialogo" then
		mensaje(casoActual and casoActual.paciente.nombre or "Paciente", p.texto, false)
		burbujaPaciente(p.texto)
	elseif p.tipo == "examen" then
		table.insert(resultados, { titulo = p.nombre, texto = p.texto, estado = "listo", tipo = "Exploración", t = p.t })
		notificar("🩺 " .. p.nombre .. ": " .. p.texto, "info")
		refrescarResultados()
	elseif p.tipo == "prueba_solicitada" then
		table.insert(resultados, { id = p.id, titulo = p.nombre, estado = "pendiente", listoEn = p.listoEn, tipo = "Prueba", t = p.t })
		notificar("Solicitado: " .. p.nombre, "info")
		refrescarResultados()
	elseif p.tipo == "prueba_resultado" then
		for _, r in ipairs(resultados) do
			if r.id == p.id and r.estado == "pendiente" then
				r.estado = "listo"
				r.texto = p.texto
				r.t = p.t
			end
		end
		notificar("🧪 Resultado listo: " .. p.nombre, "ok")
		refrescarResultados()
	elseif p.tipo == "tratamiento" then
		notificar("💊 Indicado: " .. p.nombre .. (p.dosis and p.dosis > 1 and (" (dosis " .. p.dosis .. ")") or ""), "ok")
		mensaje("Enfermería", "Enterada, doctor(a): " .. p.nombre .. ".", false)
	elseif p.tipo == "aviso" then
		notificar(p.texto, p.nivel)
	elseif p.tipo == "fin" then
		casoActual = nil
		mostrarDebrief(p.informe)
	end
end)

-- Latido del monitor al ritmo de la FC
task.spawn(function()
	while true do
		if hud.Visible and fcActual > 0 then
			latido.TextTransparency = 0
			TweenService:Create(latido, TweenInfo.new(0.25), { TextTransparency = 0.8 }):Play()
			task.wait(60 / math.max(20, fcActual))
		else
			task.wait(0.5)
		end
	end
end)

cargarMenu()
