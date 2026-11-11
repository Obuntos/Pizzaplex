class_name UILivroPlex
extends CanvasLayer
const T=preload("res://scripts/interface/fichario_estilo.gd")
var jogo: Node
var raiz:=Control.new()
var janela:=PanelContainer.new()
var grade:=HBoxContainer.new()
var folha:=PanelContainer.new()
var moedas:=Label.new()
var titulo:=Label.new()
var categoria:=3
var pagina:=0
var abas: Array[Button]=[]
var assinatura:=-1

func configurar(cena: Node) -> void:
	jogo=cena;layer=46
	raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);raiz.mouse_filter=Control.MOUSE_FILTER_STOP;add_child(raiz)
	raiz.theme=T.tema();raiz.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	var escuro:=ColorRect.new();escuro.color=Color(.03,.04,.10,.72);escuro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);raiz.add_child(escuro)
	raiz.add_child(janela);janela.add_theme_stylebox_override("panel",T.caixa(Color("14306e")))
	var coluna:=VBoxContainer.new();coluna.add_theme_constant_override("separation",8);janela.add_child(coluna)
	var cabecalho:=HBoxContainer.new();coluna.add_child(cabecalho)
	T.texto(cabecalho,"ATRAÇÕES · CONJUNTO VI",24).size_flags_horizontal=Control.SIZE_EXPAND_FILL
	cabecalho.add_child(moedas);moedas.add_theme_font_size_override("font_size",24);moedas.add_theme_color_override("font_color",Color("f6d56a"))
	T.botao(cabecalho,"X",fechar,Color("d09a2c")).custom_minimum_size=Vector2(36,36)
	var linha:=HBoxContainer.new();coluna.add_child(linha)
	for i in 4: abas.append(T.botao(linha,LivroAtracoesPlex.CATEGORIAS[i].to_upper(),func(): mudar(i),[Color("9f91d5"),Color("d9892b"),Color("2e8fd0"),Color("d8879b")][i]))
	for i in 3:
		abas[i].disabled=true
		abas[i].modulate=Color("747b93")
		abas[i].text="  "+abas[i].text;abas[i].custom_minimum_size.x=150
		var trava:=Trava.new();trava.position=Vector2(8,10);trava.scale=Vector2(.5,.5);abas[i].add_child(trava)
	folha.name="Folha";folha.custom_minimum_size=Vector2(744,390);folha.size_flags_vertical=Control.SIZE_EXPAND_FILL;coluna.add_child(folha)
	var papel:=StyleBoxTexture.new();papel.texture=load("res://assets/interface/fichario_pixel/2.png")
	papel.content_margin_left=22;papel.content_margin_right=22;papel.content_margin_top=20;papel.content_margin_bottom=14;folha.add_theme_stylebox_override("panel",papel)
	var corpo:=VBoxContainer.new();corpo.add_theme_constant_override("separation",10);folha.add_child(corpo)
	corpo.add_child(titulo);titulo.add_theme_font_size_override("font_size",24);titulo.add_theme_color_override("font_color",Color("d4e6ff"))
	grade.add_theme_constant_override("separation",16);grade.size_flags_vertical=Control.SIZE_EXPAND_FILL;corpo.add_child(grade)
	var rodape:=HBoxContainer.new();coluna.add_child(rodape)
	rodape.alignment=BoxContainer.ALIGNMENT_END
	T.botao(rodape,"<",func(): pagina=maxi(0,pagina-1);assinatura=-1;atualizar())
	T.botao(rodape,">",func(): pagina+=1;assinatura=-1;atualizar())
	jogo.livro.alterado.connect(recarregar);get_viewport().size_changed.connect(centralizar);raiz.hide()

func mudar(valor: int) -> void:
	if valor!=3: return
	categoria=valor;pagina=0;assinatura=-1;atualizar()
func aberto() -> bool: return raiz.visible and is_inside_tree()
func fechar() -> void: raiz.hide()
func abrir() -> void:
	if not jogo.livro.disponivel(): return
	raiz.show();assinatura=-1;atualizar();centralizar.call_deferred()
func centralizar() -> void:
	janela.size=Vector2(800,580);JanelasMoveisPlex.centralizar(janela,get_viewport().get_visible_rect().size)

func atualizar() -> void:
	var livro: LivroAtracoesPlex=jogo.livro
	moedas.text="ESTUDOS DO CIRCO"
	titulo.text=LivroAtracoesPlex.CATEGORIAS[categoria].to_upper()
	var chave:=hash([categoria,pagina,livro.moedas,livro.adquiridos,jogo.atracoes.fila,jogo.personagens.size()])
	var papel:=folha.get_theme_stylebox("panel") as StyleBoxTexture
	papel.texture=load("res://assets/interface/fichario_pixel/2.png")
	if chave==assinatura: return
	assinatura=chave
	for filho in grade.get_children(): grade.remove_child(filho);filho.queue_free()
	var lista: Array=livro.registros(categoria)
	pagina=clampi(pagina,0,maxi(0,ceili(lista.size()/3.0)-1))
	for r in lista.slice(pagina*3,pagina*3+3): criar_card(r)
	if lista.is_empty(): T.texto(grade,"SEM PROJETOS NESTA COLEÇÃO",12,Color("d6e9ec"))

func criar_card(r: Dictionary) -> void:
	var card:=VBoxContainer.new();card.custom_minimum_size=Vector2(216,320);card.size_flags_horizontal=Control.SIZE_EXPAND_FILL;card.add_theme_constant_override("separation",8);grade.add_child(card)
	var nome:=T.texto(card,str(r.nome).to_upper(),24);nome.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var grupo:=T.texto(card,LivroAtracoesPlex.CATEGORIAS[int(r.categoria)].to_upper(),12,Color("9fc4f2"));grupo.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var foto:=TextureRect.new();foto.custom_minimum_size=Vector2(200,176);foto.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;foto.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;card.add_child(foto)
	if not AtracoesCatalogoPlex.permitido(str(r.id)):
		var trava:=Trava.new();trava.position=Vector2(84,64);foto.add_child(trava)
		var bloqueado:=T.botao(card,"BLOQUEADO",func(): pass,Color("72788f"));bloqueado.disabled=true
		return
	var caminho: String=r.get("rosto","")
	if not caminho.is_empty():
		foto.texture=load(caminho)
	var possui: bool=jogo.livro.possui(r.id) and jogo.atracoes.pesquisado(str(r.id))
	if possui:
		var em_obra: bool=jogo.atracoes.ocupado(r.id)
		var seta: bool=jogo.atracoes.fila.any(func(o): return o.modelo==r.id and o.fase=="seta")
		var b:=T.botao(card,"POSICIONAR SETA" if seta else "EM MONTAGEM" if em_obra else "CONSTRUIR",func(): reservar(r.id),Color("8cbb81"));b.disabled=em_obra and not seta
	else:
		var b:=T.botao(card,"ESTUDAR NA MESA",func(): pass,Color("72788f"));b.disabled=true

func reservar(id: String) -> void:
	if not AtracoesCatalogoPlex.permitido(id) or not jogo.livro.possui(id): return
	if jogo.atracoes.retomar(id): fechar();return
	if jogo.atracoes.iniciar_disponivel(id):fechar()

func recarregar() -> void:
	assinatura=-1
	if aberto(): atualizar()

class Trava extends Control:
	func _init() -> void:
		mouse_filter=Control.MOUSE_FILTER_IGNORE
		custom_minimum_size=Vector2(32,32)
	func _draw() -> void:
		var cor:=Color("d9dce7")
		draw_rect(Rect2(7,1,18,4),cor)
		draw_rect(Rect2(3,5,4,12),cor)
		draw_rect(Rect2(25,5,4,12),cor)
		draw_rect(Rect2(0,14,32,18),cor)
		draw_rect(Rect2(14,20,4,8),Color("33456e"))
