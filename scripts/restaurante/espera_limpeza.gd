class_name EsperaLimpezaPlex
extends RefCounted

const INTERVALO=2.0
static func pode(s:ServicosPlex,item:Dictionary,prioridade:bool=false) -> bool:
	if prioridade:return true
	if not item.has("limpeza_liberar"):item.limpeza_liberar=s.tempo_servico+INTERVALO
	return s.tempo_servico>=float(item.limpeza_liberar)
