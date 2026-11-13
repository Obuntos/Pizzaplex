class_name LembrancasPlex
extends RefCounted

const PERSONAGENS={"novo_coelho_detalhes":"orelhitas","vi_patitas":"patitas","vi_toy_orelhitas":"toy_orelhitas","vi_toy_patitas":"toy_patitas"}
const BONECOS=["lem_boneco_pe","lem_boneco_sentado"]
const PRECO_MASCARA:=12

static func personagem(r:PersonagemPlex) -> String:
	return str(PERSONAGENS.get(str(ArmazemRobosPlex.INTEIRO.get(r.modelo,r.modelo)),""))

static func desenho_palco(jogo:Node) -> String:
	var nomes:Array[String]=[]
	for r in jogo.personagens:
		if not r.robo or r.pose<0 or CatalogoMontagemPlex.quebrado(r.modelo):continue
		var nome:=personagem(r)
		if not nome.is_empty() and not nomes.has(nome):nomes.append(nome)
	if nomes.is_empty():return ""
	var quem:=nomes[randi()%nomes.size()]
	var lista:Array=CatalogoPlex.objetos.keys().filter(func(t):return str(t).begins_with("lem_desenho_"+quem+"_"))
	return "" if lista.is_empty() else str(lista[randi()%lista.size()])

static func desenho(tipo:String) -> bool:return tipo.begins_with("festa_desenho") or tipo.begins_with("lem_desenho_")

static func opcoes(jogo:Node,menu:CanvasLayer,o:Dictionary) -> void:
	if not str(o.tipo) in BONECOS:return
	var atual:=str(o.get("estado","")) if o.has("variante") else ""
	var donos:Array[String]=[]
	for r in jogo.personagens:
		var nome:=personagem(r) if r.robo else ""
		if not nome.is_empty() and not donos.has(nome):donos.append(nome)
	for nome in donos:
		var estado:=nome.replace("_","-")
		if estado==atual:continue
		menu.adicionar("Máscara · %s · US$ %d"%[nome.replace("_"," ").capitalize(),PRECO_MASCARA],func():mascarar(jogo,o,estado))

static func mascarar(jogo:Node,o:Dictionary,estado:String) -> void:
	if not jogo.editor.cobrar(PRECO_MASCARA):return
	o.variante=str(o.tipo)+"_mascara";o.estado=estado
	jogo.planta.alterada.emit()
	jogo.painel.mensagem("Máscara colocada no boneco.")
