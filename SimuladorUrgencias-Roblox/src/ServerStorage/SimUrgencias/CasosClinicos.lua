--[[
	CasosClinicos (ModuleScript)  ->  ServerStorage/SimUrgencias/CasosClinicos

	Base de datos de casos del simulador. Todo el contenido clínico vive aquí para
	que un docente pueda revisarlo y ajustarlo a la guía institucional vigente
	sin tocar la lógica del juego.

	UNIDADES
	  Tiempos en SEGUNDOS SIMULADOS (el servidor acelera el reloj, ver CONFIG).
	  fc lpm · pas/pad mmHg · spo2 % · fr rpm · temp °C · glucosa mg/dL

	ESTRUCTURA DE UN CASO
	  paciente            datos demográficos y aspecto del avatar
	  signos              signos vitales iniciales
	  dialogo             entradas {id, categoria, claves = {...}, respuesta}
	                      (claves en minúsculas y SIN acentos)
	  exploracion         {id, grupo, nombre, hallazgo}  (semiología)
	  pruebas             {id, grupo, nombre, tiempo, resultado}
	  tratamientos        {id, grupo, nombre, efectos, retraso, duracion,
	                       flag, repetible, maxDosis,
	                       contraindicacion(s) -> razón|nil,
	                       innecesario(s)      -> razón|nil,
	                       alAplicar(s, marcar)}
	  deriva(s, dtMin)    evolución natural; devuelve un texto si el paciente
	                      entra en paro
	  objetivos           {texto, evento, limite, puntos, fuente}
	  diagnosticos        opciones; `correcto = true` en la buena
	  docencia, referencias

	Los "eventos" que se pueden usar en objetivos:
	  "prueba:<id>"   cuando se SOLICITA la prueba
	  "tx:<id>"       cuando se administra el tratamiento
	  "examen:<id>"   cuando se explora
	  "meta:<nombre>" marcado por código propio con marcar("<nombre>")
	  Varios separados por "|" = basta cualquiera de ellos.
]]

local Casos = {}

--------------------------------------------------------------------------------
-- CASO 1 · SCACEST inferior con extensión a ventrículo derecho
--------------------------------------------------------------------------------
Casos.scacest_inferior = {
	id = "scacest_inferior",
	titulo = "Dolor torácico",
	resumen = "Hombre de 58 años, dolor torácico opresivo de 1 hora de evolución.",
	dificultad = "Intermedio",
	area = "Cardiología / Urgencias",

	paciente = {
		nombre = "Ricardo Fuentes",
		edad = 58,
		sexo = "Masculino",
		peso = 82,
		colorPiel = Color3.fromRGB(198, 140, 100),
	},

	signos = { fc = 52, pas = 96, pad = 60, spo2 = 95, fr = 20, temp = 36.6, glucosa = 214 },

	preguntasSugeridas = {
		"¿Qué le trae por aquí?",
		"¿Cuándo empezó el dolor?",
		"¿Cómo es el dolor?",
		"¿El dolor se va hacia algún lado?",
		"¿Qué enfermedades padece?",
		"¿Toma algún medicamento?",
	},

	dialogo = {
		{ id = "saludo", categoria = "Presentación",
			claves = { "hola", "buenos dias", "buenas", "soy el doctor", "soy la doctora", "me llamo", "mi nombre" },
			respuesta = "Hola, doctor... ayúdeme por favor, me duele mucho el pecho." },
		{ id = "motivo", categoria = "Motivo de consulta",
			claves = { "que le pasa", "que le trae", "motivo", "por que vino", "que tiene", "que siente", "en que le ayudo", "que sucede" },
			respuesta = "Tengo un dolor muy fuerte en el pecho, aquí en medio. Siento que me aprietan." },
		{ id = "inicio", categoria = "Inicio / tiempo",
			claves = { "cuando", "desde", "hace cuanto", "empezo", "inicio", "comenzo", "cuanto tiempo" },
			respuesta = "Empezó hace como una hora, subiendo las escaleras del metro. Me senté pero no se me quitó." },
		{ id = "caracter", categoria = "Carácter",
			claves = { "como es", "tipo de dolor", "opresivo", "punzante", "ardor", "describa", "caracteristic", "quemante", "como siente el dolor" },
			respuesta = "Es una opresión, como si tuviera algo muy pesado sentado en el pecho." },
		{ id = "irradiacion", categoria = "Irradiación",
			claves = { "irradia", "se corre", "se va", "brazo", "mandibula", "cuello", "espalda", "hacia donde" },
			respuesta = "Se me va a la quijada y al brazo izquierdo." },
		{ id = "intensidad", categoria = "Intensidad",
			claves = { "intensidad", "escala", "del 1", "del uno", "que tan fuerte", "cuanto duele", "del 0", "del cero" },
			respuesta = "Un 9 de 10, es el peor dolor que he sentido." },
		{ id = "modificadores", categoria = "Atenuantes / agravantes",
			claves = { "mejora", "empeora", "alivia", "posicion", "respirar", "agrava", "calma" },
			respuesta = "No cambia con la respiración ni si me muevo. Sentado o acostado es igual." },
		{ id = "acompanantes", categoria = "Síntomas acompañantes",
			claves = { "sudor", "nausea", "vomit", "falta de aire", "disnea", "mareo", "acompana", "otros sintomas", "algo mas", "desmay" },
			respuesta = "Estoy sudando frío, tengo náuseas y me siento mareado. Siento que me voy a desmayar." },
		{ id = "antecedentes", categoria = "Antecedentes personales patológicos",
			claves = { "enfermedad", "antecedente", "diabet", "presion alta", "hipertens", "colesterol", "padece", "cronic" },
			respuesta = "Tengo diabetes desde hace 10 años y presión alta desde hace 5. El colesterol también me salió alto, pero no me lo trato." },
		{ id = "toxicomanias", categoria = "Toxicomanías",
			claves = { "fuma", "tabaco", "cigarr", "alcohol", "drogas", "cocaina", "toma bebidas" },
			respuesta = "Fumo una cajetilla diaria desde los 20 años. Alcohol solo en fiestas. Drogas nunca." },
		{ id = "medicamentos", categoria = "Medicamentos",
			claves = { "medicamento", "toma algo", "pastilla", "viagra", "sildenafil", "tadalafil", "tratamiento actual", "medicina" },
			respuesta = "Metformina 850 dos veces al día y losartán 50 en la mañana. Nada para la erección, no." },
		{ id = "alergias", categoria = "Alergias",
			claves = { "alergi" },
			respuesta = "No soy alérgico a nada, que yo sepa." },
		{ id = "familiares", categoria = "Antecedentes heredofamiliares",
			claves = { "familia", "padre", "papa", "madre", "mama", "herman", "heredo" },
			respuesta = "Mi papá murió de un infarto a los 60 años." },
		{ id = "previo", categoria = "Episodios previos",
			claves = { "antes", "previo", "alguna vez", "episodio", "le habia pasado", "otras veces" },
			respuesta = "El último mes sentía una molestia leve al subir escaleras, pero se me quitaba al descansar unos minutos." },
	},
	respuestaPorDefecto = "Perdón, doctor, no le entendí... me duele mucho el pecho.",

	exploracion = {
		{ id = "general", grupo = "General", nombre = "Inspección general",
			hallazgo = "Paciente diaforético, pálido e inquieto, con facies de dolor. Se lleva el puño cerrado al centro del pecho (signo de Levine)." },
		{ id = "cuello", grupo = "Cuello", nombre = "Pulso venoso yugular",
			hallazgo = "Ingurgitación yugular a 45°. La columna venosa aumenta en inspiración (signo de Kussmaul positivo)." },
		{ id = "precordio", grupo = "Tórax", nombre = "Palpación precordial",
			hallazgo = "Choque de punta en 5.º espacio intercostal izquierdo, línea medioclavicular, no desplazado. El dolor NO se reproduce a la palpación." },
		{ id = "cardiaca", grupo = "Tórax", nombre = "Auscultación cardiaca",
			hallazgo = "Ruidos cardiacos rítmicos, bradicárdicos. Se ausculta un 4.º ruido (galope auricular). Sin soplos ni frote." },
		{ id = "pulmonar", grupo = "Tórax", nombre = "Auscultación pulmonar",
			hallazgo = "Murmullo vesicular conservado en ambos campos, sin estertores ni sibilancias. Pulmones limpios (Killip-Kimball I)." },
		{ id = "pulsos", grupo = "Extremidades", nombre = "Pulsos y perfusión",
			hallazgo = "Pulsos radiales y pedios simétricos pero débiles. Llenado capilar de 3 segundos. Piel fría y húmeda." },
		{ id = "abdomen", grupo = "Abdomen", nombre = "Exploración abdominal",
			hallazgo = "Abdomen blando, depresible, no doloroso. Peristalsis presente." },
		{ id = "neuro", grupo = "Neurológico", nombre = "Estado neurológico",
			hallazgo = "Alerta y orientado. Glasgow 15. Sin déficit focal." },
	},

	pruebas = {
		{ id = "ecg12", grupo = "Electrocardiografía", nombre = "ECG de 12 derivaciones", tiempo = 120,
			resultado = "Ritmo sinusal a 52 lpm. Elevación del ST de 3 mm en II, III y aVF (mayor en III que en II). Descenso recíproco del ST en I y aVL. PR 0.18 s, QRS estrecho." },
		{ id = "ecg_derechas", grupo = "Electrocardiografía", nombre = "Derivaciones derechas (V3R-V4R)", tiempo = 120,
			resultado = "Elevación del ST de 1.5 mm en V4R. Compatible con extensión del infarto al ventrículo derecho." },
		{ id = "glucemia", grupo = "Cabecera", nombre = "Glucemia capilar", tiempo = 60,
			resultado = "Glucemia capilar: 214 mg/dL." },
		{ id = "pocus", grupo = "Imagen", nombre = "Ecocardiograma a pie de cama (POCUS)", tiempo = 600,
			resultado = "Hipocinesia de la pared inferior del VI. Ventrículo derecho dilatado e hipocinético. FEVI estimada de 50 %. Sin derrame pericárdico." },
		{ id = "troponina", grupo = "Laboratorio", nombre = "Troponina I de alta sensibilidad", tiempo = 3600,
			resultado = "Troponina I-hs: 145 ng/L (percentil 99 < 26 ng/L). Recuerda: en un SCACEST NO se espera la troponina para reperfundir." },
		{ id = "bh", grupo = "Laboratorio", nombre = "Biometría hemática", tiempo = 2400,
			resultado = "Hb 14.8 g/dL, leucocitos 11,200/µL, plaquetas 245,000/µL." },
		{ id = "quimica", grupo = "Laboratorio", nombre = "Química sanguínea y electrolitos", tiempo = 2400,
			resultado = "Glucosa 210 mg/dL, creatinina 1.0 mg/dL, BUN 18 mg/dL, Na 138, K 4.2, Mg 2.0 mEq/L." },
		{ id = "coagulacion", grupo = "Laboratorio", nombre = "Tiempos de coagulación", tiempo = 2400,
			resultado = "TP 12.1 s, INR 1.0, TTPa 29 s." },
		{ id = "rx_torax", grupo = "Imagen", nombre = "Radiografía de tórax portátil", tiempo = 1200,
			resultado = "Silueta cardiaca de tamaño normal. Sin congestión venocapilar ni derrame. Mediastino no ensanchado." },
	},

	tratamientos = {
		{ id = "monitor", grupo = "Medidas generales", nombre = "Monitorización continua + 2 accesos venosos + desfibrilador cerca",
			efectos = {} },
		{ id = "oxigeno", grupo = "Medidas generales", nombre = "Oxígeno por puntas nasales 2-4 L/min",
			efectos = { spo2 = 3 }, retraso = 30, duracion = 120,
			innecesario = function(s)
				if s.signos.spo2 >= 90 then
					return "Con SpO₂ ≥ 90 % el oxígeno rutinario no está indicado en el SCA."
				end
			end },
		{ id = "aas", grupo = "Antiagregantes", nombre = "Ácido acetilsalicílico 300 mg VO masticado",
			efectos = {} },
		{ id = "ticagrelor", grupo = "Antiagregantes", nombre = "Ticagrelor 180 mg VO (carga)",
			efectos = {}, flag = "p2y12" },
		{ id = "clopidogrel", grupo = "Antiagregantes", nombre = "Clopidogrel 600 mg VO (carga)",
			efectos = {}, flag = "p2y12" },
		{ id = "prasugrel", grupo = "Antiagregantes", nombre = "Prasugrel 60 mg VO (carga)",
			efectos = {}, flag = "p2y12" },
		{ id = "hnf", grupo = "Anticoagulación", nombre = "Heparina no fraccionada 70-100 UI/kg IV en bolo",
			efectos = {} },
		{ id = "nitroglicerina", grupo = "Analgesia / antiisquémicos", nombre = "Nitroglicerina 0.4 mg sublingual",
			efectos = { pas = -28, pad = -15, fc = 6 }, retraso = 60, duracion = 180,
			contraindicacion = function(s)
				return "Contraindicada: infarto de ventrículo derecho (precarga-dependiente) e hipotensión. Puede provocar colapso hemodinámico."
			end },
		{ id = "morfina", grupo = "Analgesia / antiisquémicos", nombre = "Morfina 2-4 mg IV",
			efectos = { pas = -10, pad = -5, fr = -2 }, retraso = 60, duracion = 300,
			innecesario = function(s)
				return "Usar con cautela: produce hipotensión (aquí hay infarto de VD) y retrasa la absorción de los inhibidores P2Y12 orales."
			end },
		{ id = "metoprolol", grupo = "Analgesia / antiisquémicos", nombre = "Metoprolol 5 mg IV",
			efectos = { fc = -14, pas = -15, pad = -8 }, retraso = 60, duracion = 240,
			contraindicacion = function(s)
				return "Contraindicado: bradicardia, hipotensión y signos de bajo gasto."
			end },
		{ id = "cristaloide", grupo = "Hemodinamia", nombre = "Bolo de cristaloide 250 mL IV (vigilar respuesta)",
			efectos = { pas = 8, pad = 4, fc = 2 }, retraso = 120, duracion = 600, repetible = true, maxDosis = 4, flag = "volumen",
			innecesario = function(s)
				if s.signos.pas >= 110 then
					return "Ya no hay hipotensión: más volumen no está indicado."
				end
			end },
		{ id = "atropina", grupo = "Hemodinamia", nombre = "Atropina 1 mg IV",
			efectos = { fc = 22, pas = 6 }, retraso = 30, duracion = 120, repetible = true, maxDosis = 3,
			innecesario = function(s)
				if s.signos.fc >= 50 and s.signos.pas >= 90 then
					return "Bradicardia sin compromiso hemodinámico grave: la atropina no es prioritaria."
				end
			end },
		{ id = "icp", grupo = "Reperfusión", nombre = "Activar código infarto: ICP primaria (hemodinamia)",
			efectos = {}, flag = "reperfusion" },
		{ id = "tenecteplasa", grupo = "Reperfusión", nombre = "Fibrinólisis con tenecteplasa IV",
			efectos = {}, flag = "reperfusion",
			innecesario = function(s)
				return "Este hospital tiene hemodinamia disponible en < 120 min: la ICP primaria es la estrategia de elección."
			end },
	},

	deriva = function(s, dtMin)
		local v = s.signos
		if not s.flags.reperfusion then
			if not s.flags.volumen then
				v.pas -= 0.30 * dtMin
				v.pad -= 0.15 * dtMin
			end
			v.fc -= 0.10 * dtMin
			-- Isquemia prolongada sin reperfusión: riesgo de fibrilación ventricular.
			if s.t > 100 * 60 then
				return "Fibrilación ventricular por isquemia prolongada sin reperfusión."
			end
		else
			-- Tras reperfundir, el paciente se estabiliza poco a poco.
			v.pas += 0.20 * dtMin
			v.fc += 0.15 * dtMin
		end
	end,

	objetivos = {
		{ texto = "ECG de 12 derivaciones en los primeros 10 minutos", evento = "prueba:ecg12", limite = 600, puntos = 15,
			fuente = "AHA/ACC 2025 y ESC 2023: ECG en ≤ 10 min desde el primer contacto." },
		{ texto = "Derivaciones derechas (V4R) en infarto inferior", evento = "prueba:ecg_derechas", puntos = 8,
			fuente = "ESC 2023: registrar V3R-V4R en el SCACEST inferior." },
		{ texto = "Monitorización y acceso venoso", evento = "tx:monitor", limite = 600, puntos = 5 },
		{ texto = "Ácido acetilsalicílico (dosis de carga)", evento = "tx:aas", limite = 1800, puntos = 10 },
		{ texto = "Inhibidor P2Y12 (dosis de carga)", evento = "tx:ticagrelor|tx:clopidogrel|tx:prasugrel", puntos = 8 },
		{ texto = "Anticoagulación parenteral", evento = "tx:hnf", puntos = 8 },
		{ texto = "Activar ICP primaria (simulador: ≤ 30 min; meta real primer contacto-dispositivo ≤ 90 min)", evento = "tx:icp", limite = 1800, puntos = 20,
			fuente = "AHA/ACC 2025: primer contacto médico a dispositivo ≤ 90 min (≤ 120 min si hay traslado)." },
		{ texto = "Corregir la hipotensión con volumen (infarto de VD)", evento = "tx:cristaloide", puntos = 8 },
	},

	diagnosticos = {
		{ id = "scacest_vd", nombre = "SCACEST inferior con extensión a ventrículo derecho", correcto = true },
		{ id = "scacest_ant", nombre = "SCACEST anterior extenso" },
		{ id = "scasest", nombre = "SCA sin elevación del ST" },
		{ id = "diseccion", nombre = "Disección aórtica aguda" },
		{ id = "tep", nombre = "Tromboembolia pulmonar" },
		{ id = "pericarditis", nombre = "Pericarditis aguda" },
	},
	explicacionDiagnostico = "Dolor torácico típico + elevación del ST en II, III y aVF con imagen recíproca en I/aVL = SCACEST inferior. La tríada hipotensión + ingurgitación yugular + pulmones limpios, el signo de Kussmaul y la elevación del ST en V4R indican extensión al ventrículo derecho.",

	docencia = {
		"El ECG debe obtenerse e interpretarse en ≤ 10 minutos. No se espera la troponina para decidir reperfusión en un SCACEST.",
		"En todo infarto inferior registra derivaciones derechas: el infarto de VD cambia el tratamiento.",
		"El VD infartado depende de la precarga: evita nitratos, diuréticos y dosis altas de opioides; trata la hipotensión con volumen cuidadoso.",
		"Oxígeno solo si SpO₂ < 90 %.",
		"Si la ICP primaria no puede hacerse en ≤ 120 min desde el diagnóstico, se indica fibrinólisis (idealmente ≤ 10 min tras el diagnóstico) si no hay contraindicaciones.",
	},
	referencias = {
		"Rao SV, et al. 2025 ACC/AHA/ACEP/NAEMSP/SCAI Guideline for the Management of Patients With Acute Coronary Syndromes. Circulation. 2025.",
		"Byrne RA, et al. 2023 ESC Guidelines for the management of acute coronary syndromes. Eur Heart J. 2023;44:3720-3826.",
		"Argente HA, Álvarez ME. Semiología Médica: fisiopatología, semiotecnia y propedéutica. Ed. Médica Panamericana (capítulos de dolor torácico, pulso venoso yugular y auscultación cardiaca).",
	},
}

-- Marca el objetivo si los hemocultivos se pidieron antes del primer antibiótico.
local function cultivosPrevios(s, marcar)
	if s.eventos["prueba:hemocultivos"] and not s.flags.antibiotico then
		marcar("cultivos_previos")
	end
end

--------------------------------------------------------------------------------
-- CASO 2 · Choque séptico de origen urinario
--------------------------------------------------------------------------------
Casos.choque_septico = {
	id = "choque_septico",
	titulo = "Fiebre y confusión",
	resumen = "Mujer de 72 años con fiebre, disuria y confusión de 24 h de evolución.",
	dificultad = "Avanzado",
	area = "Medicina interna / Urgencias",

	paciente = {
		nombre = "Elena Morales",
		edad = 72,
		sexo = "Femenino",
		peso = 60,
		colorPiel = Color3.fromRGB(224, 172, 140),
	},

	signos = { fc = 118, pas = 82, pad = 46, spo2 = 93, fr = 26, temp = 39.2, glucosa = 145 },

	preguntasSugeridas = {
		"¿Qué le pasa?",
		"¿Desde cuándo tiene fiebre?",
		"¿Tiene ardor al orinar?",
		"¿Qué enfermedades padece?",
		"¿Es alérgica a algún medicamento?",
		"¿Sabe dónde está?",
	},

	dialogo = {
		{ id = "saludo", categoria = "Presentación",
			claves = { "hola", "buenos dias", "buenas", "soy el doctor", "soy la doctora", "me llamo" },
			respuesta = "Hola... ¿quién es usted? Me siento muy mal." },
		{ id = "motivo", categoria = "Motivo de consulta",
			claves = { "que le pasa", "que le trae", "motivo", "por que vino", "que tiene", "que siente", "que sucede" },
			respuesta = "Tengo mucha calentura y escalofríos... estoy muy cansada. Mi hija dice que estoy rara." },
		{ id = "orientacion", categoria = "Estado mental",
			claves = { "donde esta", "que dia", "fecha", "sabe donde", "como se llama", "orientad" },
			respuesta = "Estoy en... ¿en mi casa? No sé qué día es hoy. Me llamo Elena." },
		{ id = "inicio", categoria = "Inicio / tiempo",
			claves = { "cuando", "desde", "hace cuanto", "empezo", "inicio", "comenzo" },
			respuesta = "Desde ayer en la tarde empecé con fiebre. Hace tres días ya me ardía al orinar." },
		{ id = "urinario", categoria = "Síntomas urinarios",
			claves = { "orina", "orinar", "ardor", "pipi", "bano", "disuria", "vejiga" },
			respuesta = "Me arde mucho al orinar y voy a cada rato, pero sale poquito. Hoy casi no he orinado." },
		{ id = "lumbar", categoria = "Dolor lumbar",
			claves = { "espalda", "cintura", "rinon", "lumbar", "costado", "dolor" },
			respuesta = "Me duele aquí atrás, del lado derecho, en la cintura." },
		{ id = "gastro", categoria = "Síntomas digestivos",
			claves = { "vomit", "nausea", "diarrea", "comer", "apetito" },
			respuesta = "Vomité dos veces en la mañana. No he podido comer nada." },
		{ id = "respiratorio", categoria = "Síntomas respiratorios",
			claves = { "tos", "flema", "falta de aire", "respirar", "disnea", "pecho" },
			respuesta = "No tengo tos. Solo siento que respiro rápido." },
		{ id = "antecedentes", categoria = "Antecedentes personales patológicos",
			claves = { "enfermedad", "antecedente", "diabet", "presion", "hipertens", "padece", "cronic", "infeccion" },
			respuesta = "Soy diabética desde hace 15 años. Ya me han dado infecciones de orina antes." },
		{ id = "medicamentos", categoria = "Medicamentos",
			claves = { "medicamento", "toma algo", "pastilla", "medicina", "insulina", "tratamiento" },
			respuesta = "Me inyecto insulina glargina en la noche, 20 unidades. Y tomo metformina." },
		{ id = "antibioticos", categoria = "Antibióticos recientes / hospitalizaciones",
			claves = { "antibiotico", "hospital", "internad", "sonda" },
			respuesta = "No he tomado antibióticos en los últimos meses ni he estado internada. Nunca me han puesto sonda." },
		{ id = "alergias", categoria = "Alergias",
			claves = { "alergi" },
			respuesta = "Soy alérgica a la penicilina, me dio ronchas en todo el cuerpo." },
	},
	respuestaPorDefecto = "¿Cómo dice? No le entiendo bien... estoy muy cansada.",

	exploracion = {
		{ id = "general", grupo = "General", nombre = "Inspección general",
			hallazgo = "Paciente somnolienta, desorientada en tiempo y lugar, con aspecto de enfermedad grave. Taquipneica." },
		{ id = "piel", grupo = "Piel", nombre = "Piel y mucosas",
			hallazgo = "Mucosas secas. Piel caliente en tronco, con moteado (livideces) en ambas rodillas. Llenado capilar de 4 segundos." },
		{ id = "neuro", grupo = "Neurológico", nombre = "Estado neurológico",
			hallazgo = "Glasgow 13 (O3 V4 M6). Sin rigidez de nuca. Sin déficit focal." },
		{ id = "pulmonar", grupo = "Tórax", nombre = "Auscultación pulmonar",
			hallazgo = "Murmullo vesicular conservado, sin estertores. Sin datos de consolidación." },
		{ id = "cardiaca", grupo = "Tórax", nombre = "Auscultación cardiaca",
			hallazgo = "Taquicardia rítmica, sin soplos ni galope." },
		{ id = "abdomen", grupo = "Abdomen", nombre = "Exploración abdominal",
			hallazgo = "Dolor a la palpación en hipogastrio. Sin datos de irritación peritoneal." },
		{ id = "giordano", grupo = "Abdomen", nombre = "Puñopercusión lumbar (Giordano)",
			hallazgo = "Puñopercusión lumbar derecha POSITIVA (dolor intenso). Izquierda negativa." },
		{ id = "pulsos", grupo = "Extremidades", nombre = "Pulsos periféricos",
			hallazgo = "Pulsos rápidos y débiles (filiformes). Extremidades distales frías." },
	},

	pruebas = {
		{ id = "lactato", grupo = "Cabecera", nombre = "Lactato sérico", tiempo = 300,
			resultado = "Lactato: 4.8 mmol/L (normal < 2)." },
		{ id = "glucemia", grupo = "Cabecera", nombre = "Glucemia capilar", tiempo = 60,
			resultado = "Glucemia capilar: 145 mg/dL." },
		{ id = "hemocultivos", grupo = "Microbiología", nombre = "Hemocultivos (2 sets) antes del antibiótico", tiempo = 172800,
			resultado = "Hemocultivos 2/2: Escherichia coli sensible a ceftriaxona." },
		{ id = "urocultivo", grupo = "Microbiología", nombre = "Urocultivo", tiempo = 172800,
			resultado = "Urocultivo: > 100,000 UFC/mL de Escherichia coli." },
		{ id = "ego", grupo = "Laboratorio", nombre = "Examen general de orina", tiempo = 1200,
			resultado = "Nitritos positivos, esterasa leucocitaria +++, leucocitos incontables por campo, bacterias abundantes." },
		{ id = "bh", grupo = "Laboratorio", nombre = "Biometría hemática", tiempo = 2400,
			resultado = "Leucocitos 19,800/µL (neutrófilos 89 %, bandas 8 %), Hb 12.1 g/dL, plaquetas 110,000/µL." },
		{ id = "quimica", grupo = "Laboratorio", nombre = "Química sanguínea, electrolitos y función hepática", tiempo = 2400,
			resultado = "Creatinina 2.1 mg/dL (basal 0.9), BUN 42 mg/dL, Na 134, K 4.9 mEq/L. Bilirrubina total 1.4 mg/dL." },
		{ id = "gasometria", grupo = "Laboratorio", nombre = "Gasometría arterial", tiempo = 600,
			resultado = "pH 7.29, PaCO₂ 28 mmHg, HCO₃ 16 mEq/L, PaO₂ 68 mmHg, lactato 4.6 mmol/L. Acidosis metabólica con anion gap elevado y compensación respiratoria." },
		{ id = "pct", grupo = "Laboratorio", nombre = "Procalcitonina", tiempo = 3600,
			resultado = "Procalcitonina: 12 ng/mL." },
		{ id = "usg_renal", grupo = "Imagen", nombre = "Ultrasonido renal a pie de cama", tiempo = 900,
			resultado = "Riñón derecho aumentado de tamaño, sin hidronefrosis ni litos. Sin colecciones." },
		{ id = "rx_torax", grupo = "Imagen", nombre = "Radiografía de tórax", tiempo = 1200,
			resultado = "Sin consolidaciones ni derrame pleural." },
	},

	tratamientos = {
		{ id = "monitor", grupo = "Medidas generales", nombre = "Monitorización continua + 2 accesos venosos periféricos",
			efectos = {} },
		{ id = "oxigeno", grupo = "Medidas generales", nombre = "Oxígeno por puntas nasales (meta SpO₂ 92-96 %)",
			efectos = { spo2 = 3 }, retraso = 30, duracion = 120 },
		{ id = "sonda", grupo = "Medidas generales", nombre = "Sonda vesical para cuantificar diuresis",
			efectos = {} },
		{ id = "cristaloide", grupo = "Reanimación", nombre = "Bolo de cristaloide balanceado (Hartmann) 500 mL IV",
			efectos = { pas = 6, pad = 3, fc = -4 }, retraso = 300, duracion = 900, repetible = true, maxDosis = 8,
			alAplicar = function(s, marcar)
				s.vars.liquidos = (s.vars.liquidos or 0) + 500
				if s.vars.liquidos >= 1800 then
					marcar("liquidos30")
				end
			end },
		{ id = "ceftriaxona", grupo = "Antimicrobianos", nombre = "Ceftriaxona 2 g IV",
			efectos = {}, flag = "antibiotico",
			alAplicar = cultivosPrevios,
			innecesario = function(s)
				return "Alergia a penicilina tipo urticaria (no anafilaxia): el riesgo de reacción cruzada con cefalosporinas de 3.ª generación es bajo, pero debe registrarse y vigilarse."
			end },
		{ id = "carbapenem", grupo = "Antimicrobianos", nombre = "Meropenem 1 g IV",
			efectos = {}, flag = "antibiotico",
			alAplicar = cultivosPrevios,
			innecesario = function(s)
				return "Sin factores de riesgo de BLEE/multirresistencia (sin antibióticos ni hospitalización recientes): un carbapenémico es una cobertura más amplia de lo necesario; ajustar a epidemiología local."
			end },
		{ id = "amoxicilina", grupo = "Antimicrobianos", nombre = "Amoxicilina/clavulanato 1.2 g IV",
			efectos = {},
			contraindicacion = function(s)
				return "Contraindicada: alergia documentada a la penicilina."
			end },
		{ id = "norepinefrina", grupo = "Vasopresores", nombre = "Norepinefrina IV en infusión (meta PAM ≥ 65 mmHg)",
			efectos = { pas = 24, pad = 14, fc = 2 }, retraso = 120, duracion = 600, flag = "vasopresor",
			innecesario = function(s)
				local pam = (s.signos.pas + 2 * s.signos.pad) / 3
				if pam >= 70 then
					return "La PAM ya es ≥ 65 mmHg: el vasopresor no está indicado ahora."
				end
			end },
		{ id = "dopamina", grupo = "Vasopresores", nombre = "Dopamina IV en infusión",
			efectos = { pas = 18, pad = 8, fc = 18 }, retraso = 120, duracion = 600, flag = "vasopresor",
			innecesario = function(s)
				return "La norepinefrina es el vasopresor de primera línea; la dopamina se asocia a más arritmias."
			end },
		{ id = "hidrocortisona", grupo = "Otros", nombre = "Hidrocortisona 50 mg IV cada 6 h",
			efectos = {},
			innecesario = function(s)
				if not s.flags.vasopresor then
					return "Los corticoides se sugieren solo en choque con necesidad persistente de vasopresor (norepinefrina ≥ 0.25 µg/kg/min durante ≥ 4 h)."
				end
			end },
		{ id = "paracetamol", grupo = "Otros", nombre = "Paracetamol 1 g IV",
			efectos = { temp = -1.0, fc = -4 }, retraso = 900, duracion = 1800 },
		{ id = "bicarbonato", grupo = "Otros", nombre = "Bicarbonato de sodio IV",
			efectos = {},
			innecesario = function(s)
				return "No se recomienda bicarbonato para mejorar la hemodinamia con pH ≥ 7.2."
			end },
	},

	deriva = function(s, dtMin)
		local v = s.signos
		local abxEn = s.eventos["flag:antibiotico"]
		local controlado = abxEn and (s.t - abxEn) > 45 * 60
		if not controlado then
			v.pas -= 0.30 * dtMin
			v.pad -= 0.18 * dtMin
			v.fc += 0.15 * dtMin
			v.fr += 0.04 * dtMin
			v.temp = math.min(40.2, v.temp + 0.008 * dtMin)
		else
			v.temp = math.max(37.6, v.temp - 0.01 * dtMin)
			v.fr = math.max(18, v.fr - 0.05 * dtMin)
		end
		if s.t > 150 * 60 and not s.flags.antibiotico then
			return "Choque séptico refractario y falla orgánica múltiple sin tratamiento antimicrobiano."
		end
	end,

	objetivos = {
		{ texto = "Medir lactato", evento = "prueba:lactato", limite = 3600, puntos = 10,
			fuente = "SSC 2021: medir lactato en sospecha de sepsis." },
		{ texto = "Hemocultivos ANTES del antibiótico", evento = "meta:cultivos_previos", puntos = 10,
			fuente = "SSC 2021: tomar cultivos antes del antimicrobiano si no lo retrasa." },
		{ texto = "Antibiótico IV en la primera hora", evento = "flag:antibiotico", limite = 3600, puntos = 20,
			fuente = "SSC 2021: antimicrobiano en ≤ 1 h en posible choque séptico." },
		{ texto = "Cristaloide 30 mL/kg (≥ 1,800 mL) en las primeras 3 horas", evento = "meta:liquidos30", limite = 10800, puntos = 15,
			fuente = "SSC 2021: al menos 30 mL/kg de cristaloide IV en las primeras 3 h (sugerencia)." },
		{ texto = "Norepinefrina si persiste PAM < 65 mmHg", evento = "tx:norepinefrina", puntos = 12,
			fuente = "SSC 2021: norepinefrina de primera línea; PAM meta 65 mmHg." },
		{ texto = "Buscar el foco: examen general de orina / urocultivo", evento = "prueba:ego|prueba:urocultivo", puntos = 8 },
		{ texto = "Sonda vesical para medir diuresis", evento = "tx:sonda", puntos = 5 },
	},

	diagnosticos = {
		{ id = "choque_urinario", nombre = "Choque séptico por pielonefritis aguda derecha", correcto = true },
		{ id = "sepsis_sin_choque", nombre = "Sepsis sin choque" },
		{ id = "neumonia", nombre = "Neumonía adquirida en la comunidad" },
		{ id = "cad", nombre = "Cetoacidosis diabética" },
		{ id = "hipovolemico", nombre = "Choque hipovolémico por gastroenteritis" },
	},
	explicacionDiagnostico = "Infección probable (fiebre, disuria, Giordano derecho positivo, EGO patológico) + disfunción orgánica (alteración mental, creatinina elevada, plaquetopenia, lactato > 2) = sepsis. La hipotensión que requiere vasopresor para PAM ≥ 65 con lactato > 2 mmol/L tras la reanimación con volumen define choque séptico (Sepsis-3).",

	docencia = {
		"Sepsis-3: disfunción orgánica potencialmente mortal causada por una respuesta desregulada a la infección (aumento de SOFA ≥ 2).",
		"La SSC 2021 recomienda NO usar qSOFA como única herramienta de cribado.",
		"Cultivos antes del antibiótico, pero nunca retrasar el antibiótico por tomarlos.",
		"Prefiere cristaloides balanceados; reevalúa la respuesta a volumen tras cada bolo (llenado capilar, PAM, diuresis, lactato).",
		"Revisa SIEMPRE las alergias antes de elegir el antibiótico.",
	},
	referencias = {
		"Evans L, et al. Surviving Sepsis Campaign: International Guidelines for Management of Sepsis and Septic Shock 2021. Crit Care Med. 2021;49:e1063-e1143.",
		"Singer M, et al. The Third International Consensus Definitions for Sepsis and Septic Shock (Sepsis-3). JAMA. 2016;315:801-810.",
		"Argente HA, Álvarez ME. Semiología Médica. Ed. Médica Panamericana (síndrome febril, puñopercusión lumbar, estado de conciencia).",
	},
}

--------------------------------------------------------------------------------
-- CASO 3 · Crisis asmática grave
--------------------------------------------------------------------------------
Casos.crisis_asmatica = {
	id = "crisis_asmatica",
	titulo = "Dificultad respiratoria",
	resumen = "Mujer de 24 años con disnea y sibilancias de inicio hace 6 horas.",
	dificultad = "Básico",
	area = "Neumología / Urgencias",

	paciente = {
		nombre = "Sofía Herrera",
		edad = 24,
		sexo = "Femenino",
		peso = 55,
		colorPiel = Color3.fromRGB(141, 85, 36),
	},

	signos = { fc = 126, pas = 128, pad = 78, spo2 = 89, fr = 32, temp = 36.9, glucosa = 102 },

	preguntasSugeridas = {
		"¿Qué le pasa?",
		"¿Desde cuándo?",
		"¿Es asmática?",
		"¿Qué inhaladores usa?",
		"¿La han intubado alguna vez?",
		"¿Qué desencadenó la crisis?",
	},

	dialogo = {
		{ id = "saludo", categoria = "Presentación",
			claves = { "hola", "buenos dias", "buenas", "soy el doctor", "soy la doctora", "me llamo" },
			respuesta = "Hola... (inspira) no... puedo... respirar." },
		{ id = "motivo", categoria = "Motivo de consulta",
			claves = { "que le pasa", "que le trae", "motivo", "por que vino", "que tiene", "que siente", "que sucede" },
			respuesta = "Me ahogo... (inspira) el pecho... me silba." },
		{ id = "inicio", categoria = "Inicio / tiempo",
			claves = { "cuando", "desde", "hace cuanto", "empezo", "inicio", "comenzo" },
			respuesta = "Desde... la mañana... (inspira) unas seis horas." },
		{ id = "asma", categoria = "Diagnóstico previo de asma",
			claves = { "asma", "asmatica", "diagnostic", "enfermedad", "padece", "antecedente" },
			respuesta = "Sí... asmática... desde niña." },
		{ id = "inhaladores", categoria = "Tratamiento de control",
			claves = { "inhalador", "medicamento", "salbutamol", "budesonida", "usa", "toma", "bomba", "spray" },
			respuesta = "Salbutamol... ya me eché... como 10 disparos... (inspira) no sirvió. El de mantenimiento... lo dejé hace meses." },
		{ id = "gravedad_previa", categoria = "Crisis graves previas",
			claves = { "intub", "terapia", "uci", "hospitaliz", "internad", "grave antes", "alguna vez" },
			respuesta = "Me internaron... hace dos años... (inspira) no me intubaron." },
		{ id = "desencadenante", categoria = "Desencadenante",
			claves = { "desencaden", "provoco", "gripa", "resfriado", "polvo", "gato", "humo", "que paso antes", "infeccion" },
			respuesta = "Tengo gripa... desde hace tres días." },
		{ id = "fiebre", categoria = "Fiebre / síntomas infecciosos",
			claves = { "fiebre", "calentura", "flema", "tos" },
			respuesta = "Tos seca... (inspira) sin fiebre." },
		{ id = "alergias", categoria = "Alergias",
			claves = { "alergi" },
			respuesta = "Al polvo... (inspira) a medicinas no." },
		{ id = "aines", categoria = "AINE / betabloqueadores",
			claves = { "aspirina", "ibuprofeno", "naproxeno", "aine", "betabloq", "propranolol" },
			respuesta = "No tomé... nada de eso." },
		{ id = "embarazo", categoria = "Posibilidad de embarazo",
			claves = { "embaraz", "regla", "menstruacion", "fum" },
			respuesta = "No... me bajó... hace una semana." },
	},
	respuestaPorDefecto = "(Respira con mucha dificultad y solo alcanza a negar con la cabeza.)",

	exploracion = {
		{ id = "general", grupo = "General", nombre = "Inspección general",
			hallazgo = "Sentada e inclinada hacia adelante, con apoyo en los brazos. Habla solo con palabras sueltas. Agitada, sin cianosis." },
		{ id = "musculos", grupo = "Tórax", nombre = "Mecánica ventilatoria",
			hallazgo = "Uso de músculos accesorios (esternocleidomastoideos), tiraje intercostal y supraclavicular. Tórax hiperinsuflado." },
		{ id = "percusion", grupo = "Tórax", nombre = "Percusión torácica",
			hallazgo = "Hipersonoridad generalizada a la percusión." },
		{ id = "pulmonar", grupo = "Tórax", nombre = "Auscultación pulmonar",
			hallazgo = "Sibilancias espiratorias e inspiratorias difusas, con espiración muy prolongada. Entra aire en ambos campos (aún NO hay tórax silencioso)." },
		{ id = "cardiaca", grupo = "Tórax", nombre = "Auscultación cardiaca",
			hallazgo = "Taquicardia rítmica, sin soplos." },
		{ id = "pulso_paradojico", grupo = "Cardiovascular", nombre = "Pulso paradójico",
			hallazgo = "Pulso paradójico de 18 mmHg (caída de la PAS en inspiración)." },
		{ id = "neuro", grupo = "Neurológico", nombre = "Estado neurológico",
			hallazgo = "Alerta, ansiosa, orientada. Sin somnolencia." },
	},

	pruebas = {
		{ id = "fem", grupo = "Cabecera", nombre = "Flujo espiratorio máximo (FEM)", tiempo = 120,
			resultado = "FEM: 140 L/min (≈ 30 % de su predicho de 460 L/min): crisis GRAVE." },
		{ id = "gasometria", grupo = "Laboratorio", nombre = "Gasometría arterial", tiempo = 600,
			resultado = "pH 7.46, PaCO₂ 32 mmHg, PaO₂ 58 mmHg, HCO₃ 22 mEq/L. Alcalosis respiratoria con hipoxemia. (Una PaCO₂ normal o alta sería signo de agotamiento.)" },
		{ id = "rx_torax", grupo = "Imagen", nombre = "Radiografía de tórax", tiempo = 1200,
			resultado = "Hiperinsuflación pulmonar. Sin neumotórax, neumomediastino ni consolidación." },
		{ id = "bh", grupo = "Laboratorio", nombre = "Biometría hemática", tiempo = 2400,
			resultado = "Leucocitos 9,800/µL, eosinófilos 6 %. Hb 13.4 g/dL." },
		{ id = "electrolitos", grupo = "Laboratorio", nombre = "Electrolitos séricos", tiempo = 2400,
			resultado = "Na 139, K 3.5 mEq/L (vigilar hipopotasemia por agonistas β2), Mg 1.9 mg/dL." },
		{ id = "ecg12", grupo = "Electrocardiografía", nombre = "ECG de 12 derivaciones", tiempo = 120,
			resultado = "Taquicardia sinusal a 126 lpm. Sin otras alteraciones." },
	},

	tratamientos = {
		{ id = "monitor", grupo = "Medidas generales", nombre = "Monitorización + acceso venoso + posición sentada",
			efectos = {} },
		{ id = "oxigeno", grupo = "Medidas generales", nombre = "Oxígeno titulado (meta SpO₂ 93-95 %)",
			efectos = { spo2 = 5 }, retraso = 30, duracion = 120 },
		{ id = "salbutamol", grupo = "Broncodilatadores", nombre = "Salbutamol 4-10 disparos con espaciador o 5 mg nebulizado (cada 20 min la 1.ª hora)",
			efectos = { spo2 = 3, fr = -4, fc = 4 }, retraso = 60, duracion = 600, repetible = true, maxDosis = 3, flag = "saba" },
		{ id = "ipratropio", grupo = "Broncodilatadores", nombre = "Bromuro de ipratropio 0.5 mg nebulizado",
			efectos = { spo2 = 2, fr = -2 }, retraso = 120, duracion = 900, repetible = true, maxDosis = 3, flag = "saba_ipra" },
		{ id = "prednisona", grupo = "Corticosteroides", nombre = "Prednisona 50 mg VO",
			efectos = { spo2 = 1, fr = -1 }, retraso = 3600, duracion = 3600, flag = "esteroide" },
		{ id = "hidrocortisona", grupo = "Corticosteroides", nombre = "Hidrocortisona 200 mg IV",
			efectos = { spo2 = 1, fr = -1 }, retraso = 3600, duracion = 3600, flag = "esteroide" },
		{ id = "magnesio", grupo = "Segunda línea", nombre = "Sulfato de magnesio 2 g IV en 20 min",
			efectos = { spo2 = 3, fr = -3, pas = -6, pad = -4 }, retraso = 600, duracion = 1200,
			innecesario = function(s)
				if not s.flags.saba then
					return "El sulfato de magnesio se reserva para crisis grave que no responde al tratamiento inicial con broncodilatadores."
				end
			end },
		{ id = "midazolam", grupo = "Otros", nombre = "Midazolam 2 mg IV (ansiedad)",
			efectos = { fr = -12, spo2 = -12 }, retraso = 60, duracion = 300,
			contraindicacion = function(s)
				return "Contraindicado: los sedantes en una crisis asmática fuera de la intubación pueden causar depresión respiratoria y paro."
			end },
		{ id = "antibiotico", grupo = "Otros", nombre = "Amoxicilina 1 g VO",
			efectos = {},
			innecesario = function(s)
				return "Sin datos de infección bacteriana (sin fiebre ni consolidación): los antibióticos no están indicados en la crisis asmática."
			end },
		{ id = "propranolol", grupo = "Otros", nombre = "Propranolol 10 mg VO (taquicardia)",
			efectos = { fc = -20, spo2 = -10, fr = 6 }, retraso = 300, duracion = 600,
			contraindicacion = function(s)
				return "Contraindicado: los betabloqueadores no selectivos provocan broncoespasmo. La taquicardia se debe a la crisis y a los agonistas β2."
			end },
	},

	deriva = function(s, dtMin)
		local v = s.signos
		if not s.flags.saba then
			v.spo2 -= 0.12 * dtMin
			v.fr += 0.06 * dtMin
			v.fc += 0.05 * dtMin
		elseif s.flags.esteroide then
			v.fr = math.max(18, v.fr - 0.03 * dtMin)
		end
	end,

	objetivos = {
		{ texto = "Agonista β2 de acción corta en los primeros 10 minutos", evento = "tx:salbutamol", limite = 600, puntos = 20,
			fuente = "GINA 2024: SABA inhalado repetido en la primera hora." },
		{ texto = "Oxígeno titulado a SpO₂ 93-95 %", evento = "tx:oxigeno", limite = 600, puntos = 10,
			fuente = "GINA 2024: SpO₂ objetivo 93-95 % en adultos." },
		{ texto = "Bromuro de ipratropio en crisis grave", evento = "tx:ipratropio", puntos = 10 },
		{ texto = "Corticosteroide sistémico en la primera hora", evento = "tx:prednisona|tx:hidrocortisona", limite = 3600, puntos = 15,
			fuente = "GINA 2024: corticosteroide sistémico en la primera hora." },
		{ texto = "Medir la gravedad objetivamente (FEM)", evento = "prueba:fem", puntos = 8 },
		{ texto = "Preguntar por crisis graves / intubación previas", evento = "anamnesis:gravedad_previa", puntos = 5 },
	},

	diagnosticos = {
		{ id = "crisis_grave", nombre = "Crisis asmática GRAVE", correcto = true },
		{ id = "crisis_leve", nombre = "Crisis asmática leve-moderada" },
		{ id = "vital", nombre = "Crisis asmática de riesgo vital (tórax silencioso)" },
		{ id = "anafilaxia", nombre = "Anafilaxia" },
		{ id = "neumotorax", nombre = "Neumotórax a tensión" },
	},
	explicacionDiagnostico = "Habla con palabras sueltas, se sienta inclinada hacia adelante, está agitada, FR > 30, FC > 120, SpO₂ < 90 % y FEM ≤ 50 % = crisis GRAVE (GINA). No hay somnolencia, confusión ni tórax silencioso, que definirían una crisis de riesgo vital.",

	docencia = {
		"Clasifica la gravedad por clínica (habla, posición, FR, FC, SpO₂) y por FEM.",
		"Tórax silencioso, cianosis, somnolencia, bradicardia o PaCO₂ normal/alta = riesgo vital: considera manejo avanzado de vía aérea.",
		"Nunca sedes a un paciente con crisis asmática fuera del contexto de la intubación.",
		"Al alta: inicia o reanuda el tratamiento de control con corticosteroide inhalado.",
	},
	referencias = {
		"Global Initiative for Asthma (GINA). Global Strategy for Asthma Management and Prevention, 2024 update.",
		"Argente HA, Álvarez ME. Semiología Médica. Ed. Médica Panamericana (inspección del tórax, percusión, ruidos agregados: sibilancias).",
	},
}

-- Orden en el menú
Casos.ORDEN = { "scacest_inferior", "choque_septico", "crisis_asmatica" }

return Casos
