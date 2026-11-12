class_name CriacaoPartidaPlex
extends Control

signal confirmada(dados: Dictionary)
signal cancelada
const T=preload("res://scripts/interface/tema_hud.gd")
var janela:=SuperficieVintagePlex.new("moldura",16)
var restaurante:=LineEdit.new()
var nome:=LineEdit.new()
var sexo:=0
var uniforme_indice:=0
var cabelo_indice:=0
var cabelos:Array=[]
var cor_escolhida:="marrom_escuro"
var pele_escolhida:=PelePlex.PADRAO
var peles:Dictionary={}
var material_pele:=ShaderMaterial.new()
var sexos:Array[Button]=[]
var cores:Dictionary={}
var cabelo_nome:=Label.new()
var erro:=Label.new()
var quadro:=Control.new()
var ator:PersonagemPlex
const NOMES_OLHOS=["Padrão","Cansado","Fox eye","Doe eye"]
const NOMES_FACIAIS=["Nenhum","Bochechas","Nariz rosado","Sardas","Pintas"]
const ITENS_FACIAIS=["","bochechas","nariz","sardas","pintas"]
var olhos_indice:=0
var olhos_nome:=Label.new()
var faciais_indices:Array[int]=[0,0]
var faciais_nomes:Array[Label]=[]
var direcao:=0
var tempo:=0.0
var pronto:=false
var posicao_previa:=Vector2.ZERO
var criar_botao:Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme=T.criar()
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	var fundo:=ColorRect.new()
	fundo.color=Color(.045,.022,.012,.78)
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fundo)
	add_child(janela)
	var madeira:=SuperficieVintagePlex.new("madeira",20)
	janela.add_child(madeira)
	var coluna:=VBoxContainer.new()
	coluna.add_theme_constant_override("separation",16)
	madeira.add_child(coluna)
	var topo:=HBoxContainer.new()
	coluna.add_child(topo)
	var faixa:=SuperficieVintagePlex.new("faixa",14)
	faixa.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	topo.add_child(faixa)
	var titulo:=T.texto(faixa,"UM NOVO COMEÇO",28,VintagePlex.OURO)
	titulo.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var fechar_botao:=VintagePlex.botao(topo,"",cancelar,VintagePlex.VERMELHO)
	fechar_botao.icon=VintagePlex.icone("x")
	var linha:=HBoxContainer.new()
	linha.add_theme_constant_override("separation",28)
	coluna.add_child(linha)
	var formulario:=VBoxContainer.new()
	formulario.custom_minimum_size.x=324
	formulario.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	formulario.add_theme_constant_override("separation",8)
	linha.add_child(formulario)
	for spec in [["Nome do restaurante",restaurante],["Nome do administrador",nome]]:
		T.texto(formulario,spec[0],16,T.PAPEL)
		var campo:LineEdit=spec[1]
		campo.custom_minimum_size.y=40
		campo.max_length=40
		formulario.add_child(campo)
	restaurante.text="Pizzaplex"
	nome.text="Alex"
	var personagens:=HBoxContainer.new()
	personagens.add_theme_constant_override("separation",12)
	formulario.add_child(personagens)
	T.texto(personagens,"Personagem",16).size_flags_horizontal=Control.SIZE_EXPAND_FILL
	for i in 2:
		var b:=VintagePlex.botao(personagens,"",definir_sexo.bind(i))
		b.custom_minimum_size=Vector2(52,48)
		b.toggle_mode=true
		b.icon=VintagePlex.icone("masc" if i==0 else "fem",Color("8ab5dc") if i==0 else Color("df8da8"))
		b.expand_icon=true
		b.add_theme_constant_override("icon_max_width",30)
		sexos.append(b)
	var uniformes:=HBoxContainer.new()
	formulario.add_child(uniformes)
	VintagePlex.botao(uniformes,"‹",trocar_uniforme.bind(-1))
	var uniforme_nome:=T.texto(uniformes,"Uniforme",18)
	uniforme_nome.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	uniforme_nome.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	uniforme_nome.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	VintagePlex.botao(uniformes,"›",trocar_uniforme.bind(1))
	T.texto(formulario,"Cabelo",16)
	AparenciaPlex.carregar()
	cabelos=[{"id":"nenhum","nome":"Sem cabelo"}]
	for item in AparenciaPlex.dados.cabelos:
		cabelos.append(item)
		if str(item.id)=="curto": cabelo_indice=cabelos.size()-1
	var linha_cabelo:=HBoxContainer.new()
	formulario.add_child(linha_cabelo)
	VintagePlex.botao(linha_cabelo,"‹",trocar_cabelo.bind(-1))
	cabelo_nome.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	cabelo_nome.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	cabelo_nome.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	cabelo_nome.add_theme_font_size_override("font_size",15)
	linha_cabelo.add_child(cabelo_nome)
	VintagePlex.botao(linha_cabelo,"›",trocar_cabelo.bind(1))
	T.texto(formulario,"Cor do cabelo",16)
	CoresCabeloPlex.carregar()
	var paleta:=HBoxContainer.new()
	paleta.add_theme_constant_override("separation",12)
	formulario.add_child(paleta)
	for cor in CoresCabeloPlex.opcoes:
		var id:=str(cor.id)
		var b:=Button.new()
		b.custom_minimum_size=Vector2(42,40)
		b.toggle_mode=true
		b.pressed.connect(definir_cor.bind(id))
		paleta.add_child(b)
		cores[id]=b
	T.texto(formulario,"Cor da pele",16)
	var paleta_pele:=HBoxContainer.new()
	paleta_pele.add_theme_constant_override("separation",12)
	formulario.add_child(paleta_pele)
	for tom in PelePlex.opcoes():
		var id_pele:=str(tom.id)
		var bp:=Button.new()
		bp.custom_minimum_size=Vector2(42,40)
		bp.toggle_mode=true
		bp.tooltip_text=str(tom.nome)
		bp.pressed.connect(definir_pele.bind(id_pele))
		paleta_pele.add_child(bp)
		peles[id_pele]=bp
	T.texto(formulario,"Olhos",16)
	criar_seletor(formulario,olhos_nome,trocar_olhos)
	olhos_nome.text=NOMES_OLHOS[olhos_indice]
	for i in 2:
		T.texto(formulario,"Item facial "+str(i+1),16)
		var rotulo:=Label.new();rotulo.text=NOMES_FACIAIS[faciais_indices[i]];faciais_nomes.append(rotulo)
		criar_seletor(formulario,rotulo,trocar_item_facial.bind(i))
	var previa:=SuperficieVintagePlex.new("papel",18)
	previa.custom_minimum_size.x=250
	linha.add_child(previa)
	var visual:=VBoxContainer.new()
	previa.add_child(visual)
	quadro.custom_minimum_size=Vector2(214,302)
	quadro.mouse_filter=Control.MOUSE_FILTER_IGNORE
	visual.add_child(quadro)
	quadro.resized.connect(centralizar)
	var giros:=HBoxContainer.new()
	giros.alignment=BoxContainer.ALIGNMENT_CENTER
	giros.add_theme_constant_override("separation",20)
	visual.add_child(giros)
	VintagePlex.botao(giros,"‹",girar.bind(-1))
	VintagePlex.botao(giros,"›",girar.bind(1))
	var acoes:=HBoxContainer.new()
	acoes.add_theme_constant_override("separation",18)
	coluna.add_child(acoes)
	VintagePlex.botao(acoes,"VOLTAR",cancelar).custom_minimum_size.x=130
	criar_botao=VintagePlex.botao(acoes,"CRIAR PARTIDA",confirmar,Color("e8a237"),true)
	criar_botao.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	coluna.add_child(erro)
	erro.add_theme_color_override("font_color",Color("eea28a"))
	erro.hide()
	get_viewport().size_changed.connect(redimensionar)
	pronto=true
	atualizar_controles()
	hide()

func redimensionar() -> void:
	if not is_inside_tree(): return
	var tela:=get_viewport_rect().size
	janela.scale=Vector2.ONE
	janela.size=Vector2(900,janela.get_combined_minimum_size().y)
	var escala:=minf(1.0,minf(tela.x/(janela.size.x+48),tela.y/(janela.size.y+48)))
	janela.scale=Vector2.ONE*escala
	janela.position=((tela-janela.size*escala)*.5).round()

func dados() -> Dictionary:
	return {"restaurante":restaurante.text.strip_edges(),"nome":nome.text.strip_edges(),"modelo":"humano" if sexo==0 else "humana","uniforme":"administrador_"+("masculino" if sexo==0 else "feminino")+"_"+str(uniforme_indice+1),"cabelo":str(cabelos[cabelo_indice].id),"cor_cabelo":CoresCabeloPlex.validar(cor_escolhida),"pele":PelePlex.validar(pele_escolhida),"olhos":RostoPlex.OLHOS[olhos_indice],"itens_faciais":RostoPlex.itens(faciais_indices.map(func(i):return ITENS_FACIAIS[i]))}

func criar_seletor(pai:Control,rotulo:Label,acao:Callable) -> void:
	var linha:=HBoxContainer.new();pai.add_child(linha)
	VintagePlex.botao(linha,"‹",acao.bind(-1)).custom_minimum_size=Vector2(42,40)
	rotulo.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;rotulo.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;rotulo.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	rotulo.add_theme_font_size_override("font_size",15);linha.add_child(rotulo)
	VintagePlex.botao(linha,"›",acao.bind(1)).custom_minimum_size=Vector2(42,40)

func trocar_olhos(passo:int) -> void:
	olhos_indice=posmod(olhos_indice+passo,RostoPlex.OLHOS.size())
	olhos_nome.text=NOMES_OLHOS[olhos_indice]
	atualizar_previa()

func trocar_item_facial(passo:int,slot:int) -> void:
	if slot<0 or slot>=faciais_indices.size() or passo==0:return
	var proximo:=faciais_indices[slot]
	for _i in ITENS_FACIAIS.size():
		proximo=posmod(proximo+(1 if passo>0 else -1),ITENS_FACIAIS.size())
		if proximo==0 or proximo!=faciais_indices[1-slot]:break
	faciais_indices[slot]=proximo
	faciais_nomes[slot].text=NOMES_FACIAIS[proximo]
	atualizar_previa()

func definir_sexo(indice:int) -> void:
	sexo=clampi(indice,0,1)
	atualizar_controles()
	atualizar_previa()

func trocar_uniforme(passo:int) -> void:
	uniforme_indice=posmod(uniforme_indice+passo,2)
	atualizar_previa()

func definir_cor(id:String) -> void:
	if str(cabelos[cabelo_indice].id)=="nenhum": return
	cor_escolhida=CoresCabeloPlex.validar(id)
	atualizar_controles()
	atualizar_previa()

func definir_pele(id:String) -> void:
	pele_escolhida=PelePlex.validar(id)
	atualizar_controles()
	atualizar_previa()

func atualizar_controles() -> void:
	for i in sexos.size():
		sexos[i].set_pressed_no_signal(sexo==i)
		for estado in ["normal","pressed","hover_pressed"]: sexos[i].add_theme_stylebox_override(estado,VintagePlex.caixa(Color("68402a") if sexo==i else T.FUNDO,Color("bc8b55") if sexo==i else Color("50301f"),8))
	cabelo_nome.text=str(cabelos[cabelo_indice].nome)
	var sem_cabelo:=str(cabelos[cabelo_indice].id)=="nenhum"
	for cor in CoresCabeloPlex.opcoes:
		var id:=str(cor.id)
		var b:Button=cores[id]
		b.disabled=sem_cabelo
		b.set_pressed_no_signal(id==cor_escolhida)
		for estado in ["normal","hover","pressed","hover_pressed","disabled"]:
			var tinta:=Color(str(cor.cor))
			if estado=="hover": tinta=tinta.lightened(.2)
			if estado=="disabled": tinta=tinta.darkened(.4)
			b.add_theme_stylebox_override(estado,VintagePlex.caixa(tinta,VintagePlex.CREME if id==cor_escolhida else Color("28160d"),4))
		b.add_theme_stylebox_override("focus",VintagePlex.caixa(Color.TRANSPARENT,Color("c98a4b"),0))
	for tom in PelePlex.opcoes():
		var id_pele:=str(tom.id)
		var bp:Button=peles[id_pele]
		bp.set_pressed_no_signal(id_pele==pele_escolhida)
		for estado in ["normal","hover","pressed","hover_pressed"]:
			var tinta_pele:=Color(str(tom.cor))
			if estado=="hover": tinta_pele=tinta_pele.lightened(.2)
			bp.add_theme_stylebox_override(estado,VintagePlex.caixa(tinta_pele,VintagePlex.CREME if id_pele==pele_escolhida else Color("28160d"),4))
		bp.add_theme_stylebox_override("focus",VintagePlex.caixa(Color.TRANSPARENT,Color("c98a4b"),0))

func abrir() -> void:
	erro.text=""
	erro.hide()
	show()
	redimensionar()
	atualizar_previa()

func atualizar_previa() -> void:
	if not pronto or not visible: return
	var valor:=dados()
	var novo_modelo:=str(valor.modelo)
	if not is_instance_valid(ator) or ator.modelo!=novo_modelo:
		if is_instance_valid(ator):
			quadro.remove_child(ator)
			ator.queue_free()
		ator=load("res://cenas/personagens/personagem.tscn").instantiate()
		ator.configurar(-1,novo_modelo,Vector2i.ZERO,false)
		ator.planta_visual=PlantaPlex.new()
		ator.scale=Vector2.ONE*3.0
		material_pele.shader=preload("res://shaders/pele.gdshader")
		ator.material=material_pele
		ator.visual.use_parent_material=true
		ator.animacao.use_parent_material=true
		quadro.add_child(ator)
	ator.funcao="administrador"
	ator.visita.administrador=true
	ator.uniforme=valor.uniforme
	ator.cabelo=valor.cabelo
	ator.visita.cor_cabelo=valor.cor_cabelo
	ator.visita.pele=valor.pele
	PelePlex.aplicar(material_pele,str(valor.pele))
	ator.visita.olhos=valor.olhos;ator.visita.itens_faciais=valor.itens_faciais
	ator.direcao=direcao
	ator.atualizar_visual(false)
	centralizar()
	ator.identificacao.hide()

func centralizar() -> void:
	if not is_instance_valid(ator): return
	var definicao:Dictionary=ator.animacao.definicao
	if definicao.is_empty(): return
	var tamanho:=Vector2(definicao.width,definicao.height)
	var pivo:=Vector2(definicao.pivot[0],definicao.pivot[1])
	var centro:Vector2=(tamanho*.5-pivo)*ator.animacao.scale
	posicao_previa=(quadro.size*.5-centro*ator.scale).round()
	ator.position=posicao_previa

func confirmar() -> void:
	var valor:=dados()
	if valor.restaurante.is_empty() or valor.nome.is_empty():
		erro.text="Preencha os dois nomes."
		erro.show()
		return
	hide()
	confirmada.emit(valor)

func cancelar() -> void:
	hide()
	cancelada.emit()

func _process(delta:float) -> void:
	if not visible: return
	redimensionar()
	if not is_instance_valid(ator): return
	tempo+=delta
	if tempo<.08: return
	ator.relogio+=tempo
	tempo=0.0
	ator.atualizar_visual(false)
	ator.position=posicao_previa
	ator.identificacao.hide()

func girar(passo:int) -> void:
	direcao=posmod(direcao+passo,8)
	atualizar_previa()

func trocar_cabelo(passo:int) -> void:
	if cabelos.is_empty(): return
	cabelo_indice=posmod(cabelo_indice+passo,cabelos.size())
	atualizar_controles()
	atualizar_previa()
