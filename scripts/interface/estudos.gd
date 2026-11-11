class_name UIEstudosPlex
extends CanvasLayer

const T=preload("res://scripts/interface/tema_hud.gd")
var jogo:Node
var raiz:=Control.new()
var janela:=PanelContainer.new()
var pessoas:Array[Dictionary]=[]
var pessoa_indice:=0
var pessoa_nome:=Label.new()
var pessoa_anterior:Button
var pessoa_seguinte:Button
var horas:=8
var horas_texto:=Label.new()
var progresso:=ProgressBar.new()
var descricao:=Label.new()
var projeto:=Label.new()
var mesa:=-1
var projetos_botao:Button
var forcar_botao:Button
func configurar(cena:Node) -> void:
	jogo=cena;layer=75;add_child(raiz);raiz.theme=T.criar();raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var sombra:=ColorRect.new();sombra.color=Color(0,0,0,.65);sombra.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);raiz.add_child(sombra)
	raiz.add_child(janela);janela.add_theme_stylebox_override("panel",T.caixa(T.FUNDO,T.LINHA,22))
	var coluna:=VBoxContainer.new();coluna.add_theme_constant_override("separation",16);janela.add_child(coluna)
	T.texto(coluna,"ESTUDO / VI",26,T.AMBAR);coluna.add_child(projeto);projeto.add_theme_font_size_override("font_size",19)
	T.texto(coluna,"Pesquisador",14)
	var pesquisadores:=HBoxContainer.new();coluna.add_child(pesquisadores)
	pessoa_anterior=T.botao(pesquisadores,"‹",func():mudar_pessoa(-1))
	pesquisadores.add_child(pessoa_nome);pessoa_nome.size_flags_horizontal=Control.SIZE_EXPAND_FILL;pessoa_nome.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;pessoa_nome.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	pessoa_seguinte=T.botao(pesquisadores,"›",func():mudar_pessoa(1))
	T.texto(coluna,"Horas por dia",14)
	var horario:=HBoxContainer.new();coluna.add_child(horario)
	T.botao(horario,"‹",func():mudar_horas(-1))
	horario.add_child(horas_texto);horas_texto.size_flags_horizontal=Control.SIZE_EXPAND_FILL;horas_texto.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;horas_texto.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	T.botao(horario,"›",func():mudar_horas(1))
	progresso.custom_minimum_size.y=24;coluna.add_child(progresso);coluna.add_child(descricao)
	descricao.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;descricao.custom_minimum_size.x=420
	var botoes:=HBoxContainer.new();coluna.add_child(botoes)
	T.botao(botoes,"Estudar",iniciar,T.VERDE);T.botao(botoes,"Pausar",func(): jogo.estudos.pausar();atualizar());T.botao(botoes,"Fechar",fechar)
	forcar_botao=T.botao(coluna,"Forçar estudo",alternar_forcado,T.VERDE)
	projetos_botao=T.botao(coluna,"Animatrônicos",func():fechar();jogo.painel.hud.livro_ui.abrir())
	raiz.hide()
	if is_inside_tree():conectar_viewport()
	elif not ready.is_connected(conectar_viewport):ready.connect(conectar_viewport,CONNECT_ONE_SHOT)
func conectar_viewport() -> void:
	var viewport:=get_viewport()
	if viewport==null:return
	if not viewport.size_changed.is_connected(centralizar):viewport.size_changed.connect(centralizar)
	if aberto():centralizar()
func aberto() -> bool:return raiz.visible
func fechar() -> void:raiz.hide()
func centralizar() -> void:
	if not is_inside_tree() or get_viewport()==null:return
	janela.size=Vector2(490,0);JanelasMoveisPlex.centralizar(janela,get_viewport().get_visible_rect().size)
func abrir(id:int) -> void:
	mesa=id;pessoas.clear();pessoa_indice=0
	for a in jogo.personagens:
		if EstudosPlex.elegivel(a):
			pessoas.append({"nome":IdentidadesPlex.completo(a),"id":a.identificador})
			if a.identificador==jogo.estudos.pesquisador:pessoa_indice=pessoas.size()-1
	mudar_pessoa(0)
	horas=jogo.estudos.horas;horas_texto.text=str(horas)+" h";raiz.show();atualizar();centralizar.call_deferred()
func mudar_pessoa(passo:int) -> void:
	pessoa_anterior.disabled=pessoas.size()<2;pessoa_seguinte.disabled=pessoas.size()<2
	if pessoas.is_empty():pessoa_nome.text="Nenhum disponível";return
	pessoa_indice=posmod(pessoa_indice+passo,pessoas.size());pessoa_nome.text=str(pessoas[pessoa_indice].nome)
func pesquisador_id() -> int:return -1 if pessoas.is_empty() else int(pessoas[pessoa_indice].id)
func mudar_horas(delta:int) -> void:
	horas=clampi(horas+delta,1,12);horas_texto.text=str(horas)+" h"
func iniciar() -> void:
	if jogo.estudos.configurar(mesa,pesquisador_id(),horas):atualizar()
	else:descricao.text="Libere o pesquisador e um acesso à mesa."
func alternar_forcado() -> void:
	if jogo.estudos.forcado:jogo.estudos.pausar()
	elif not jogo.estudos.configurar(mesa,pesquisador_id(),horas,true):
		jogo.painel.mensagem("Libere o acesso à mesa e escolha um pesquisador presente no restaurante.")
	atualizar()
func atualizar() -> void:
	var e:EstudosPlex=jogo.estudos
	forcar_botao.text="Parar estudo" if e.forcado else "Forçar estudo"
	forcar_botao.disabled=not e.forcado and (pessoas.is_empty() or e.proximo().is_empty())
	projetos_botao.disabled=e.concluidos.is_empty()
	var id:=e.projeto if not e.projeto.is_empty() else e.proximo()
	projeto.text=CatalogoMontagemPlex.nome(id) if not id.is_empty() else "Estudo concluído"
	progresso.value=e.progresso/EstudosPlex.MINUTOS_PROJETO*100.0
	descricao.text="%.1f / 16 horas de estudo · %d horas por dia"%[e.progresso/60.0,e.horas] if not id.is_empty() else "Coelho estudado. Monte-o na bancada de montagem da oficina."
	if e.forcado:descricao.text="%.1f / 16 horas · Estudo contínuo até concluir ou escolher Parar estudo."%[e.progresso/60.0]
func _process(_delta:float) -> void:
	if aberto():atualizar();centralizar()
