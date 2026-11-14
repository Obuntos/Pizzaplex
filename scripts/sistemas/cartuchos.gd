class_name CartuchosPlex
extends RefCounted

const AVISO:="Libere os lados do animatrônico."
const TEMPO_GRAVAR:=3.0
const TEMPO_INSTALAR:=2.5
var jogo:Node
var pedidos:Array=[]

func _init(cena:Node) -> void:jogo=cena

func funcionario() -> PersonagemPlex:
	var m:PersonagemPlex=jogo.sistemas.mecanico.mecanico()
	if is_instance_valid(m) and not m.visita.has("mec") and not levando(m):return m
	var adm:PersonagemPlex=jogo.controle.administrador()
	if is_instance_valid(adm) and not levando(adm):return adm
	return null

func lados(r:PersonagemPlex) -> Array[Vector2i]:
	var rot:=0
	for i in 4:
		if GradePlex.direcao_suporte(i)==r.direcao:rot=i
	var f:=GradePlex.frente(rot)
	var lado:=Vector2i(-f.y,f.x)
	var lista:Array[Vector2i]=[r.celula-f,r.celula+f,r.celula+lado,r.celula-lado]
	return lista

func ponto(r:PersonagemPlex,a:PersonagemPlex) -> Vector2i:
	for c in lados(r):
		if c==a.celula or not jogo.rotas.caminho(a.origem_rota(),c).is_empty():return c
	return Vector2i(-1,-1)

func levando(a:PersonagemPlex) -> bool:return pedidos.any(func(p):return int(p.funcionario)==a.identificador)
func pendente(r:PersonagemPlex) -> bool:return pedidos.any(func(p):return int(p.robo)==r.identificador)

func pedir(r:PersonagemPlex,musica:String,animacao:String,terminal:int) -> String:
	if not is_instance_valid(r):return "Selecione um animatrônico."
	if pendente(r):return "Já existe um cartucho a caminho deste animatrônico."
	var a:=funcionario()
	if a==null:return "Nenhum funcionário disponível para levar o cartucho."
	if ponto(r,a).x<0:return AVISO
	a.movimento.cancelar();a.andar(jogo.rotas.aproximar(a.origem_rota(),terminal))
	pedidos.append({"robo":r.identificador,"funcionario":a.identificador,"musica":musica,"animacao":animacao,"terminal":terminal,"etapa":"ibm","t":0.0,"alvo":Vector2i(-1,-1)})
	jogo.sistemas.baloes.exibir(a,"Vou gravar o cartucho no IBM.",3)
	return ""

func encerrar(p:Dictionary) -> void:pedidos.erase(p)

func atualizar(delta:float) -> void:
	for p in pedidos.duplicate():
		var r:PersonagemPlex=jogo.clientes.ator(int(p.robo))
		var a:PersonagemPlex=jogo.clientes.ator(int(p.funcionario))
		if not is_instance_valid(r) or not is_instance_valid(a) or a.visita.get("morto",false):encerrar(p);continue
		if a.ocupado():continue
		match str(p.etapa):
			"ibm":
				if jogo.planta.objetos.has(int(p.terminal)):jogo.tarefas.orientar(a,Vector2(jogo.planta.objetos[int(p.terminal)].celula))
				p.t=float(p.t)+delta
				if float(p.t)<TEMPO_GRAVAR:continue
				p.alvo=ponto(r,a)
				if Vector2i(p.alvo).x<0:
					jogo.terminal_ui.mensagem(AVISO);jogo.painel.mensagem(AVISO);encerrar(p);continue
				p.etapa="levar";p.t=0.0
				if a.celula!=Vector2i(p.alvo):a.andar(jogo.rotas.caminho(a.origem_rota(),Vector2i(p.alvo)))
			"levar":
				if a.celula==Vector2i(p.alvo):p.etapa="instalar";p.t=0.0;continue
				p.alvo=ponto(r,a)
				if Vector2i(p.alvo).x<0:jogo.terminal_ui.mensagem(AVISO);jogo.painel.mensagem(AVISO);encerrar(p);continue
				a.andar(jogo.rotas.caminho(a.origem_rota(),Vector2i(p.alvo)))
			"instalar":
				jogo.tarefas.orientar(a,r.local)
				p.t=float(p.t)+delta
				if float(p.t)<TEMPO_INSTALAR:continue
				r.robotica.musica_show=str(p.musica)
				r.robotica.clipe_show=str(p.animacao)
				r.robotica.erase("pose_dia");r.relogio=0.0
				jogo.painel.mensagem("Cartucho instalado em "+IdentidadesPlex.completo(r)+".")
				encerrar(p)

