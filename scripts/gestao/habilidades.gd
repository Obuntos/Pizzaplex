class_name HabilidadesEquipePlex
extends RefCounted

static func estrelas(a:PersonagemPlex,funcao:String="") -> int:
 return clampi(int(a.visita.get("habilidades",{}).get(a.funcao if funcao.is_empty() else funcao,3)),1,5)
static func fator(a:PersonagemPlex,funcao:String="") -> float:
 if a.robo or a.cargo!="funcionario" or a.visita.get("morto",false):return 1.0
 return (.7+float(estrelas(a,funcao)-1)*.15)*lerpf(.70,1.0,smoothstep(15.0,55.0,a.energia))
static func multiplicador(nota:int) -> float:
 return [.6,.8,1.0,1.25,1.5][clampi(nota,1,5)-1]
static func salario(a:PersonagemPlex) -> int:
 return roundi(FolhaPagamentoPlex.salario(a.funcao)*multiplicador(estrelas(a)))
static func texto(nota:int) -> String:
 return "★".repeat(clampi(nota,1,5))+"☆".repeat(5-clampi(nota,1,5))
