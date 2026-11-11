class_name BairroCidadePlex
extends Node2D

var jogo: Node
var mapa: Dictionary = {}
var catalogo: Dictionary = {}
var lote := Rect2i(33,25,12,12)
var terreno := PisosCidadePlex.new()
var visuais: Array[ObjetoCidadePlex] = []
var ancoras_fumaca: Dictionary = {}
var tempo := 0.0
var espera := 0.0
var cobertura_neve := 0.0
var ativo := false
var assinatura := ""
var material_chao := ShaderMaterial.new()
var ids_mapa: Dictionary = {}

func configurar(cena: Node) -> void:
	jogo=cena
	CatalogoCidadePlex.carregar()
	catalogo=CatalogoCidadePlex.dados
	mapa=JSON.parse_string(FileAccess.get_file_as_string("res://dados/cidade/bairro_jardim.json"))
	ancoras_fumaca=JSON.parse_string(FileAccess.get_file_as_string("res://dados/cidade/ambiente.json")).chamines
	lote=Rect2i(mapa.restaurante[0],mapa.restaurante[1],mapa.restaurante[2],mapa.restaurante[3])
	terreno.bairro=self
	terreno.z_index=-6
	material_chao.shader=preload("res://shaders/piso_cidade.gdshader")
	terreno.material=material_chao
	jogo.iluminacao.vincular(material_chao)
	jogo.add_child(terreno)
	visible=false
	terreno.hide()

func chave(tipo: String, celula: Vector2i, rotacao: int) -> String:
	return str([tipo,celula,posmod(rotacao,4)])

func ativar(valor: bool, _restaurando: bool = false) -> void:
	ativo=valor
	visible=valor
	terreno.visible=valor
	var p: PlantaPlex=jogo.planta
	p.bairro_ativo=valor
	p.lote_restaurante=lote
	p.bairro_bloqueios.clear()
	for no in visuais: no.queue_free()
	visuais.clear();ids_mapa.clear()
	if not valor: return
	var bloqueado:=p.is_blocking_signals()
	p.set_block_signals(true)
	var existentes: Dictionary={}
	for objeto in p.objetos.values():
		if objeto.get("cidade",false) or objeto.get("cidade_fixo",false): existentes[chave(objeto.tipo,objeto.celula,objeto.rotacao)]=objeto.id
	for piso in mapa.pisos:
		var local:=Vector2i(piso[0],piso[1])
		if not lote.has_point(local) and not TerrenoPlex.contem(p,local): p.pisos[local]=str(piso[2])
	for i in mapa.objetos.size():
		var item: Array=mapa.objetos[i]
		var tipo:=str(item[0])
		if not catalogo.has(tipo) or CompraTerrenosPlex.substituido(p,tipo): continue
		var celula:=Vector2i(item[1],item[2])
		var r:=posmod(int(item[3]),4)
		var id:=int(existentes.get(chave(tipo,celula,r),-1))
		var extras: Dictionary={"cidade":true,"cidade_fixo":true,"cidade_mapa":true,"indice_mapa":i,"solto":not CatalogoCidadePlex.solido(tipo)}
		if id<0:
			id=p.registrar_cidade(tipo,celula,r,extras)
		else: p.objetos[id].merge(extras,true)
		if id<0: continue
		existentes[chave(tipo,celula,r)]=id
		ids_mapa[i]=id
		if tipo==CaminhosCidadePlex.CASA: p.objetos[id].casa_administrador=true
		if ancoras_fumaca.has(tipo):
			var efeito:=ObjetoCidadePlex.new()
			add_child(efeito);efeito.configurar(self,item,i);visuais.append(efeito)
	p.reindexar()
	p.set_block_signals(bloqueado)
	p.alterada.emit()
	assinatura="";terreno.assinatura=""
	atualizar(0.0)
	jogo.chao.queue_redraw()
	if jogo.populacao!=null: jogo.populacao.iniciado=false;jogo.populacao.locais.assinatura=-1

func ancora(item: Array) -> Vector2:
	var d: Dictionary=catalogo[str(item[0])]
	var tamanho:=Vector2(d.w,d.h)
	var r:=int(item[3])
	if r%2: tamanho=Vector2(tamanho.y,tamanho.x)
	var inicio:=Vector2(item[1],item[2])
	if not d.origemCelula: return inicio+(tamanho-Vector2.ONE)*.5
	return inicio+[Vector2.ZERO,Vector2(tamanho.x-1,0),tamanho-Vector2.ONE,Vector2(0,tamanho.y-1)][r]

func quadro(tipo: String, estado: String, direcao: int, camada: String = "sprites") -> Dictionary:
	return CatalogoCidadePlex.quadro(tipo,direcao,camada,estado)

func estado_objeto(item: Array, _indice: int) -> String:
	if str(item[0])=="cidade_semaforo":
		var fase:=fposmod(tempo+float(int(item[3])%2)*10.0,20.0)
		return "verde" if fase<7 else "amarelo" if fase<9 else "vermelho"
	return jogo.calendario.variacao()

func atualizar(delta: float) -> void:
	if not ativo: return
	tempo+=maxf(0.0,delta);espera+=delta
	var cal: CalendarioPlex=jogo.calendario
	var neve_nova:=clampf((cal.minutos-240.0)/240.0,0.0,1.0) if cal.previsao()=="Neve" else 0.0
	neve_nova=floorf(neve_nova*16.0)/16.0
	var nova:=str([GradePlex.visao,cal.variacao(),neve_nova])
	if nova!=assinatura:
		assinatura=nova;cobertura_neve=neve_nova
		CatalogoCidadePlex.ambiente(cal.variacao(),cobertura_neve)
		terreno.atualizar()
	if espera>=.15 or is_zero_approx(delta):
		espera=0.0
		jogo.vizinhanca.atualizar_animacoes(tempo)
		for efeito in visuais: efeito.atualizar()

