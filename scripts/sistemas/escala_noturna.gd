class_name EscalaNoturnaPlex
extends RefCounted

var inicio:=0
var noites:=0
var entrada:=1320
var saida:=360
var guarda:=-1
var numero:=0
var carimbada:=false
var rondas:Dictionary={}
var presencas:Dictionary={}
func agendar(dia:int,n:int,de:int,ate:int,ator:int=-1) -> bool:
	if n<1 or n>8 or de<0 or de>=1440 or ate<0 or ate>=1440 or de==ate:return false
	inicio=maxi(0,dia);noites=n;entrada=de;saida=ate;guarda=ator;numero+=1;carimbada=true;rondas.clear();presencas.clear();return true
func noite_atual(dia:int,minuto:float) -> int:
	if not carimbada:return -1
	var data:=dia
	if saida<entrada and minuto<saida:data-=1
	var dentro:bool=(minuto>=entrada or minuto<saida) if saida<entrada else (minuto>=entrada and minuto<saida)
	var indice:=data-inicio
	return indice if dentro and indice>=0 and indice<noites else -1
func atribuido(a:PersonagemPlex) -> bool:return a.funcao=="seguranca" and (guarda<0 or guarda==a.identificador)
func ativo(a:PersonagemPlex,dia:int,minuto:float) -> bool:return atribuido(a) and noite_atual(dia,minuto)>=0
func gravar() -> Dictionary:return {"inicio":inicio,"noites":noites,"entrada":entrada,"saida":saida,"guarda":guarda,"numero":numero,"carimbada":carimbada,"rondas":rondas,"presencas":presencas}
func restaurar(d:Dictionary) -> void:
	inicio=maxi(0,int(d.get("inicio",0)));noites=clampi(int(d.get("noites",0)),0,8);entrada=clampi(int(d.get("entrada",1320)),0,1439);saida=clampi(int(d.get("saida",360)),0,1439);guarda=int(d.get("guarda",-1));numero=int(d.get("numero",0));carimbada=bool(d.get("carimbada",false)) and noites>0 and entrada!=saida;rondas=d.get("rondas",{}).duplicate();presencas=d.get("presencas",{}).duplicate()

func vigente(dia:int,minuto:float) -> bool:
	if not carimbada or noites<=0:return false
	var fim:=(inicio+noites-1+(1 if saida<entrada else 0))*1440+saida
	return dia*1440+minuto<float(fim)
