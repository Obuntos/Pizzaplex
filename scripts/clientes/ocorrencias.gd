class_name OcorrenciasClientesPlex
extends RefCounted

static func derramar(s: ServicosPlex, pedido: Dictionary, a: PersonagemPlex, bebida: bool) -> bool:
	if not is_instance_valid(a) or a.cargo!="crianca": return false
	var campo:="acidente_bebida_avaliado" if bebida else "acidente_comida_avaliado"
	if pedido.get(campo,false): return false
	pedido[campo]=true
	if posmod(hash([int(pedido.id),a.identificador,"bebida" if bebida else "comida"]),7 if bebida else 9)!=0: return false
	return criar_sujeira(s,a,"bebida_derramada" if bebida else "restos_mesa")

static func criar_sujeira(s: ServicosPlex, a: PersonagemPlex, tipo: String) -> bool:
	for d in GradePlex.VIZINHOS:
		var c: Vector2i=a.celula+d
		if not TerrenoPlex.contem(s.planta,c) or not s.planta.transitavel(c) or not s.planta.em(c).is_empty(): continue
		if s.planta.sobre(c).any(func(o): return LimpezaAmbientesPlex.eh(o)): continue
		var id:=s.inventario.criar(tipo,c)
		s.planta.objetos[id].solto=true
		s.planta.alterada.emit()
		a.emocao.exibir("exclamacao")
		return true
	return false
