--[[
	SimuladorServidor (Script)  ->  ServerScriptService/SimuladorServidor

	Motor del simulador: reloj clínico, fisiología, anamnesis por palabras clave,
	exploración, pruebas con tiempo de espera, tratamientos con efecto,
	contraindicaciones y debriefing con puntuación.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")

local Casos = require(ServerStorage:WaitForChild("SimUrgencias"):WaitForChild("CasosClinicos"))

local CONFIG = {
	ESCALA_TIEMPO = 10,       -- 1 s real = 10 s clínicos (10 min clínicos ≈ 1 min real)
	VELOCIDADES = { 1, 3, 6 }, -- multiplicadores que puede elegir el estudiante
	PASO_REAL = 0.5,          -- cada cuánto se calcula la fisiología (s reales)
	PENAL_CONTRAINDICADO = 15,
	PENAL_INNECESARIO = 3,
	PUNTOS_ANAMNESIS = 10,
	PUNTOS_DIAGNOSTICO = 15,
	-- Umbrales de paro (simplificados)
	PARO = { spo2 = 70, pas = 55, fcMin = 30, fcMax = 190 },
}

--------------------------------------------------------------------------------
-- Remotos
--------------------------------------------------------------------------------
local carpeta = Instance.new("Folder")
carpeta.Name = "SimRemotos"
carpeta.Parent = ReplicatedStorage

local Accion = Instance.new("RemoteEvent")
Accion.Name = "Accion"
Accion.Parent = carpeta

local Actualizar = Instance.new("RemoteEvent")
Actualizar.Name = "Actualizar"
Actualizar.Parent = carpeta

local ObtenerCasos = Instance.new("RemoteFunction")
ObtenerCasos.Name = "ObtenerCasos"
ObtenerCasos.Parent = carpeta

--------------------------------------------------------------------------------
-- Utilidades
--------------------------------------------------------------------------------
local ACENTOS = {
	["á"] = "a", ["é"] = "e", ["í"] = "i", ["ó"] = "o", ["ú"] = "u", ["ü"] = "u", ["ñ"] = "n",
	["Á"] = "a", ["É"] = "e", ["Í"] = "i", ["Ó"] = "o", ["Ú"] = "u", ["Ü"] = "u", ["Ñ"] = "n",
	["¿"] = " ", ["¡"] = " ",
}

local function normalizar(texto)
	local s = string.lower(texto)
	for k, v in pairs(ACENTOS) do
		s = string.gsub(s, k, v) -- las claves son UTF-8 sin caracteres mágicos
	end
	s = string.gsub(s, "%p", " ") -- signos de puntuación ASCII
	s = string.gsub(s, "%s+", " ")
	return " " .. s .. " "
end

local function buscar(lista, id)
	for _, item in ipairs(lista) do
		if item.id == id then
			return item
		end
	end
	return nil
end

local function copiar(t)
	local c = {}
	for k, v in pairs(t) do
		c[k] = v
	end
	return c
end

local function pam(v)
	return (v.pas + 2 * v.pad) / 3
end

-- Información del caso que SÍ puede ver el cliente (sin respuestas ni resultados).
local function casoPublico(caso)
	local function lista(origen, campos)
		local r = {}
		for _, item in ipairs(origen) do
			local x = {}
			for _, c in ipairs(campos) do
				x[c] = item[c]
			end
			table.insert(r, x)
		end
		return r
	end
	return {
		id = caso.id,
		titulo = caso.titulo,
		resumen = caso.resumen,
		dificultad = caso.dificultad,
		area = caso.area,
		paciente = {
			nombre = caso.paciente.nombre,
			edad = caso.paciente.edad,
			sexo = caso.paciente.sexo,
			peso = caso.paciente.peso,
		},
		preguntasSugeridas = caso.preguntasSugeridas,
		exploracion = lista(caso.exploracion, { "id", "grupo", "nombre" }),
		pruebas = lista(caso.pruebas, { "id", "grupo", "nombre", "tiempo" }),
		tratamientos = lista(caso.tratamientos, { "id", "grupo", "nombre", "repetible" }),
		diagnosticos = lista(caso.diagnosticos, { "id", "nombre" }),
	}
end

ObtenerCasos.OnServerInvoke = function(_player)
	local r = {}
	for _, id in ipairs(Casos.ORDEN) do
		table.insert(r, casoPublico(Casos[id]))
	end
	return r
end

--------------------------------------------------------------------------------
-- Escena: paciente y monitor del mundo
--------------------------------------------------------------------------------
local escena = workspace:WaitForChild("SimEscena")

local function crearPaciente(caso)
	local viejo = escena:FindFirstChild("Paciente")
	if viejo then
		viejo:Destroy()
	end

	local desc = Instance.new("HumanoidDescription")
	local piel = caso.paciente.colorPiel or Color3.fromRGB(200, 150, 110)
	desc.HeadColor = piel
	desc.LeftArmColor = piel
	desc.RightArmColor = piel
	desc.LeftLegColor = Color3.fromRGB(165, 195, 220) -- bata
	desc.RightLegColor = Color3.fromRGB(165, 195, 220)
	desc.TorsoColor = Color3.fromRGB(165, 195, 220)

	local ok, modelo = pcall(function()
		return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	end)
	if not ok or not modelo then
		warn("[SimUrgencias] No se pudo crear el avatar del paciente:", modelo)
		return
	end

	modelo.Name = "Paciente"
	local humanoide = modelo:FindFirstChildOfClass("Humanoid")
	if humanoide then
		humanoide.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoide.PlatformStand = true
	end
	for _, d in ipairs(modelo:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CanCollide = false
		end
	end
	local raiz = modelo:FindFirstChild("HumanoidRootPart")
	modelo.PrimaryPart = raiz

	-- Acostado boca arriba sobre la cama, cabeza hacia la almohada (+Z).
	local cama = escena:FindFirstChild("Colchon")
	local base = cama and cama.Position or Vector3.new(0, 2.8, 4)
	local superficie = base.Y + (cama and cama.Size.Y / 2 or 0.3)
	modelo:PivotTo(CFrame.new(0, superficie + 0.6, base.Z + 1.2) * CFrame.Angles(math.rad(90), 0, 0))
	if raiz then
		raiz.Anchored = true
	end
	modelo.Parent = escena
end

local monitorGui = escena:WaitForChild("Monitor"):WaitForChild("Pantalla")

local function actualizarMonitorMundo(v)
	local function poner(nombre, texto)
		local l = monitorGui:FindFirstChild(nombre, true)
		if l then
			l.Text = texto
		end
	end
	if not v then
		poner("FC", "--")
		poner("PA", "--/--")
		poner("SpO2", "--")
		poner("FR", "--")
		return
	end
	poner("FC", tostring(v.fc))
	poner("PA", v.pas .. "/" .. v.pad)
	poner("SpO2", tostring(v.spo2))
	poner("FR", tostring(v.fr))
end

--------------------------------------------------------------------------------
-- Sesiones
--------------------------------------------------------------------------------
local sesiones = {} -- [Player] = sesión

local function enviar(player, paquete)
	Actualizar:FireClient(player, paquete)
end

local function aviso(player, texto, nivel)
	enviar(player, { tipo = "aviso", texto = texto, nivel = nivel or "info" })
end

local function signosVisibles(s)
	local v = s.signos
	local function ruido(x, r)
		return x + (math.random() * 2 - 1) * r
	end
	return {
		fc = math.floor(ruido(v.fc, 1.5) + 0.5),
		pas = math.floor(ruido(v.pas, 1) + 0.5),
		pad = math.floor(ruido(v.pad, 1) + 0.5),
		pam = math.floor(pam(v) + 0.5),
		spo2 = math.clamp(math.floor(ruido(v.spo2, 0.5) + 0.5), 0, 100),
		fr = math.floor(ruido(v.fr, 0.6) + 0.5),
		temp = math.floor(v.temp * 10 + 0.5) / 10,
	}
end

local function marcarEvento(s, clave)
	if s.eventos[clave] == nil then
		s.eventos[clave] = s.t
	end
end

local function registrar(s, texto)
	table.insert(s.bitacora, { t = s.t, texto = texto })
end

local function iniciar(player, casoId)
	local caso = Casos[casoId]
	if not caso then
		return
	end
	local s = {
		caso = caso,
		t = 0,
		acumulado = 0,
		desdeEnvio = 0,
		velocidad = 1,
		activo = true,
		signos = copiar(caso.signos),
		efectos = {},
		flags = {},
		vars = {},
		eventos = {},
		dosis = {},
		anamnesis = {},
		penalizaciones = {},
		pendientes = {},
		bitacora = {},
		diagnostico = nil,
	}
	sesiones[player] = s
	crearPaciente(caso)
	enviar(player, { tipo = "inicio", caso = casoPublico(caso), signos = signosVisibles(s) })
	registrar(s, "Llegada del paciente a urgencias")
end

local function penalizar(s, texto, puntos, grave)
	table.insert(s.penalizaciones, { t = s.t, texto = texto, puntos = puntos, grave = grave })
end

local function preguntar(player, s, texto)
	texto = string.sub(tostring(texto), 1, 200)
	local q = normalizar(texto)
	local mejor, mejorPuntaje = nil, 0
	for _, entrada in ipairs(s.caso.dialogo) do
		local puntaje = 0
		for _, clave in ipairs(entrada.claves) do
			if string.find(q, clave, 1, true) then
				puntaje += #clave -- las claves más específicas pesan más
			end
		end
		if puntaje > mejorPuntaje then
			mejor, mejorPuntaje = entrada, puntaje
		end
	end
	local respuesta = mejor and mejor.respuesta or s.caso.respuestaPorDefecto
	if mejor then
		if not s.anamnesis[mejor.id] then
			s.anamnesis[mejor.id] = s.t
			marcarEvento(s, "anamnesis:" .. mejor.id)
		end
	end
	enviar(player, { tipo = "dialogo", texto = respuesta, categoria = mejor and mejor.categoria or nil, t = s.t })
end

local function explorar(player, s, id)
	local item = buscar(s.caso.exploracion, id)
	if not item then
		return
	end
	marcarEvento(s, "examen:" .. id)
	registrar(s, "Exploración: " .. item.nombre)
	enviar(player, { tipo = "examen", id = id, nombre = item.nombre, texto = item.hallazgo, t = s.t })
end

local function pedirPrueba(player, s, id)
	local item = buscar(s.caso.pruebas, id)
	if not item then
		return
	end
	if s.eventos["prueba:" .. id] then
		aviso(player, item.nombre .. " ya fue solicitada.", "info")
		return
	end
	marcarEvento(s, "prueba:" .. id)
	registrar(s, "Solicita: " .. item.nombre)
	table.insert(s.pendientes, { item = item, listo = s.t + item.tiempo })
	enviar(player, { tipo = "prueba_solicitada", id = id, nombre = item.nombre, listoEn = s.t + item.tiempo, t = s.t })
end

local function tratar(player, s, id)
	local tx = buscar(s.caso.tratamientos, id)
	if not tx then
		return
	end
	local dadas = s.dosis[id] or 0
	if dadas > 0 and not tx.repetible then
		aviso(player, tx.nombre .. " ya fue indicado.", "info")
		return
	end
	if tx.maxDosis and dadas >= tx.maxDosis then
		aviso(player, "Dosis máxima de este escenario alcanzada para: " .. tx.nombre, "alerta")
		return
	end
	s.dosis[id] = dadas + 1
	marcarEvento(s, "tx:" .. id)
	registrar(s, "Indica: " .. tx.nombre)

	-- Errores de prescripción
	local razon = tx.contraindicacion and tx.contraindicacion(s)
	if razon then
		penalizar(s, tx.nombre .. " — " .. razon, CONFIG.PENAL_CONTRAINDICADO, true)
		aviso(player, "⚠ " .. razon, "error")
	else
		local motivo = tx.innecesario and tx.innecesario(s)
		if motivo and dadas == 0 then
			penalizar(s, tx.nombre .. " — " .. motivo, CONFIG.PENAL_INNECESARIO, false)
			aviso(player, "Nota: " .. motivo, "alerta")
		end
	end

	if tx.alAplicar then
		tx.alAplicar(s, function(nombre)
			marcarEvento(s, "meta:" .. nombre)
		end)
	end
	if tx.flag then
		s.flags[tx.flag] = true
		marcarEvento(s, "flag:" .. tx.flag)
	end
	if tx.efectos and next(tx.efectos) then
		table.insert(s.efectos, {
			deltas = tx.efectos,
			inicio = s.t + (tx.retraso or 0),
			duracion = math.max(1, tx.duracion or 60),
			aplicado = 0,
		})
	end
	enviar(player, { tipo = "tratamiento", id = id, nombre = tx.nombre, dosis = s.dosis[id], t = s.t })
end

--------------------------------------------------------------------------------
-- Informe final
--------------------------------------------------------------------------------
local function construirInforme(s, motivoParo)
	local caso = s.caso
	local puntos, maximo = 0, 0
	local objetivos = {}

	for _, obj in ipairs(caso.objetivos) do
		maximo += obj.puntos
		local cuando = nil
		for clave in string.gmatch(obj.evento, "[^|]+") do
			local t = s.eventos[clave]
			if t and (cuando == nil or t < cuando) then
				cuando = t
			end
		end
		local cumplido = cuando ~= nil and (obj.limite == nil or cuando <= obj.limite)
		if cumplido then
			puntos += obj.puntos
		end
		table.insert(objetivos, {
			texto = obj.texto,
			cumplido = cumplido,
			tiempo = cuando,
			limite = obj.limite,
			tarde = cuando ~= nil and not cumplido,
			fuente = obj.fuente,
		})
	end

	-- Anamnesis
	local total, hechas, faltantes = #caso.dialogo, 0, {}
	for _, e in ipairs(caso.dialogo) do
		if s.anamnesis[e.id] then
			hechas += 1
		else
			table.insert(faltantes, e.categoria)
		end
	end
	local ptsAnam = math.floor(CONFIG.PUNTOS_ANAMNESIS * hechas / math.max(1, total) + 0.5)
	puntos += ptsAnam
	maximo += CONFIG.PUNTOS_ANAMNESIS

	-- Diagnóstico
	local elegido = s.diagnostico and buscar(caso.diagnosticos, s.diagnostico)
	local correcto = elegido and elegido.correcto or false
	if correcto then
		puntos += CONFIG.PUNTOS_DIAGNOSTICO
	end
	maximo += CONFIG.PUNTOS_DIAGNOSTICO
	local bueno
	for _, d in ipairs(caso.diagnosticos) do
		if d.correcto then
			bueno = d.nombre
		end
	end

	-- Penalizaciones
	local errores = {}
	for _, p in ipairs(s.penalizaciones) do
		puntos -= p.puntos
		table.insert(errores, { texto = p.texto, puntos = p.puntos, grave = p.grave, t = p.t })
	end
	if motivoParo then
		puntos -= 25
	end

	return {
		titulo = caso.titulo,
		paciente = caso.paciente.nombre,
		duracion = s.t,
		resultado = motivoParo and ("PARO CARDIORRESPIRATORIO: " .. motivoParo) or "Paciente vivo al final del escenario",
		paro = motivoParo ~= nil,
		puntos = math.max(0, puntos),
		maximo = maximo,
		objetivos = objetivos,
		anamnesis = { hechas = hechas, total = total, faltantes = faltantes, puntos = ptsAnam },
		diagnostico = {
			elegido = elegido and elegido.nombre or "(no registrado)",
			correcto = correcto,
			esperado = bueno,
			explicacion = caso.explicacionDiagnostico,
		},
		errores = errores,
		docencia = caso.docencia,
		referencias = caso.referencias,
		bitacora = s.bitacora,
	}
end

local function finalizar(player, s, motivoParo)
	if not s.activo then
		return
	end
	s.activo = false
	registrar(s, motivoParo and ("Paro: " .. motivoParo) or "Fin del escenario")
	enviar(player, { tipo = "fin", informe = construirInforme(s, motivoParo) })
	actualizarMonitorMundo(nil)
end

--------------------------------------------------------------------------------
-- Entrada del cliente
--------------------------------------------------------------------------------
Accion.OnServerEvent:Connect(function(player, tipo, dato)
	if type(tipo) ~= "string" then
		return
	end
	if tipo == "iniciar" then
		if type(dato) == "string" then
			iniciar(player, dato)
		end
		return
	end
	local s = sesiones[player]
	if not s or not s.activo then
		return
	end
	if tipo == "preguntar" and type(dato) == "string" then
		preguntar(player, s, dato)
	elseif tipo == "explorar" and type(dato) == "string" then
		explorar(player, s, dato)
	elseif tipo == "prueba" and type(dato) == "string" then
		pedirPrueba(player, s, dato)
	elseif tipo == "tratar" and type(dato) == "string" then
		tratar(player, s, dato)
	elseif tipo == "diagnostico" and type(dato) == "string" then
		if buscar(s.caso.diagnosticos, dato) then
			s.diagnostico = dato
			registrar(s, "Diagnóstico registrado")
			aviso(player, "Diagnóstico registrado.", "ok")
		end
	elseif tipo == "velocidad" and type(dato) == "number" then
		if table.find(CONFIG.VELOCIDADES, dato) then
			s.velocidad = dato
		end
	elseif tipo == "finalizar" then
		finalizar(player, s, nil)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	sesiones[player] = nil
end)

--------------------------------------------------------------------------------
-- Bucle fisiológico
--------------------------------------------------------------------------------
local function paso(player, s, dtSim)
	s.t += dtSim
	local v = s.signos

	-- Efectos de tratamientos: se aplican de forma gradual entre inicio e inicio+duración.
	for i = #s.efectos, 1, -1 do
		local e = s.efectos[i]
		if s.t >= e.inicio then
			local fraccion = math.clamp((s.t - e.inicio) / e.duracion, 0, 1)
			local incremento = fraccion - e.aplicado
			for k, d in pairs(e.deltas) do
				if v[k] then
					v[k] += d * incremento
				end
			end
			e.aplicado = fraccion
			if fraccion >= 1 then
				table.remove(s.efectos, i)
			end
		end
	end

	-- Evolución natural del caso
	local motivo = s.caso.deriva and s.caso.deriva(s, dtSim / 60)

	-- Límites fisiológicos
	v.spo2 = math.clamp(v.spo2, 50, 100)
	v.fc = math.clamp(v.fc, 20, 220)
	v.pas = math.clamp(v.pas, 40, 220)
	v.pad = math.clamp(v.pad, 20, math.max(21, v.pas - 10))
	v.fr = math.clamp(v.fr, 4, 50)
	v.temp = math.clamp(v.temp, 34, 42)

	-- Resultados que ya están listos
	for i = #s.pendientes, 1, -1 do
		local p = s.pendientes[i]
		if s.t >= p.listo then
			table.remove(s.pendientes, i)
			registrar(s, "Resultado: " .. p.item.nombre)
			enviar(player, { tipo = "prueba_resultado", id = p.item.id, nombre = p.item.nombre, texto = p.item.resultado, t = s.t })
		end
	end

	-- Paro
	local P = CONFIG.PARO
	if not motivo then
		if v.spo2 < P.spo2 then
			motivo = "Hipoxemia grave"
		elseif v.pas < P.pas then
			motivo = "Hipotensión extrema / choque"
		elseif v.fc < P.fcMin then
			motivo = "Bradicardia extrema"
		elseif v.fc > P.fcMax then
			motivo = "Taquiarritmia"
		end
	end
	if motivo then
		finalizar(player, s, motivo)
	end
end

RunService.Heartbeat:Connect(function(dt)
	for player, s in pairs(sesiones) do
		if s.activo then
			s.acumulado += dt
			s.desdeEnvio += dt
			if s.acumulado >= CONFIG.PASO_REAL then
				paso(player, s, s.acumulado * CONFIG.ESCALA_TIEMPO * s.velocidad)
				s.acumulado = 0
			end
			if s.activo and s.desdeEnvio >= 1 then
				s.desdeEnvio = 0
				local vis = signosVisibles(s)
				enviar(player, { tipo = "signos", t = s.t, v = vis })
				actualizarMonitorMundo(vis)
			end
		end
	end
end)

print("[SimUrgencias] Servidor listo con " .. #Casos.ORDEN .. " casos.")
