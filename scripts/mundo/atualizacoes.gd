class_name AtualizacoesMundoPlex
extends RefCounted

var pendentes: Dictionary={}
var ordem: Array[String]=[]

func agendar(nome: String, tarefa: Callable) -> void:
	if not pendentes.has(nome): ordem.append(nome)
	pendentes[nome]=tarefa

func processar(orcamento_us: int = 3000, limite: int = 2, desempenho: DesempenhoPlex = null) -> int:
	var inicio:=Time.get_ticks_usec()
	var quantidade:=0
	while not ordem.is_empty() and quantidade<limite:
		var nome: String=ordem.pop_front()
		var tarefa: Callable=pendentes[nome]
		pendentes.erase(nome)
		if tarefa.is_valid():
			var inicio_tarefa:=Time.get_ticks_usec()
			tarefa.call()
			if desempenho!=null: desempenho.medir("Reconstrução: "+nome,inicio_tarefa)
		quantidade+=1
		if Time.get_ticks_usec()-inicio>=orcamento_us: break
	return quantidade

func limpar() -> void:
	pendentes.clear();ordem.clear()
