from pathlib import Path
from PIL import Image
import numpy as np,json,re,time,os
root=Path(__file__).resolve().parents[1]
meta=json.loads((root/'dados/personagens.json').read_text())
pals=json.loads((root/'dados/paletas_iluminacao.json').read_text())
human=pals['humano']
def salvar(imagem,destino):
 temporario=destino.with_suffix('.pending')
 imagem.save(temporario,format='PNG',optimize=True)
 os.replace(temporario,destino)
def rgb(s):return [int(s[i:i+2],16) for i in [1,3,5]]
start=time.time();total=0
for path in sorted((root/'assets/personagens').rglob('*.png')):
 model=path.relative_to(root/'assets/personagens').parts[0];m=meta[model];w,h=m['width'],m['height']
 image=np.array(Image.open(path).convert('RGBA'));H,W=image.shape[:2];alpha=image[:,:,3]>0
 yy,xx=np.indices((h,w));cx=m['pivot'][0]
 head_only=any(t in path.stem for t in ['cabeca','olhos','boca']);body_only='corpo' in path.stem
 robot=model in ['endo','coelho','ovelha','raposa']
 head_y=35.5 if robot else 16;head_rx=12.5 if robot else 11.5;head_ry=13 if robot else 12
 X=np.tile(xx,(H//h,W//w)).astype(np.float32);Y=np.tile(yy,(H//h,W//w)).astype(np.float32)
 row_index=np.arange(W)[None,:]
 left=np.maximum.accumulate(np.where(~alpha,row_index,-1),axis=1)+1
 right=np.minimum.accumulate(np.where(~alpha,row_index,W)[:,::-1],axis=1)[:,::-1]-1
 center=(left+right)*.5;radius=np.maximum(1,(right-left+1)*.5)
 nx=np.clip((np.arange(W)[None,:]-center)/(radius+.5),-.85,.85)*.7
 ny=np.zeros_like(nx);nz=np.sqrt(np.maximum(.1,1-nx*nx))
 if not body_only:
  head=(Y<(49 if robot else 29))&(Y>(21 if robot else 2))
  u=(X+.5-cx)/head_rx;v=(Y+.5-head_y)/head_ry;radius2=np.sqrt(u*u+v*v);factor=np.minimum(1,.9/np.maximum(.001,radius2))
  u*=factor;v*=factor;nx=np.where(head,u*.7,nx);ny=np.where(head,-v*.7,ny);nz=np.where(head,np.sqrt(np.maximum(.1,1-(u*u+v*v)*.49)),nz)
  if head_only:
   nx=u*.7;ny=-v*.7;nz=np.sqrt(np.maximum(.1,1-(u*u+v*v)*.49))
 torso=(Y>=(49 if robot else 29))&(Y<(68 if robot else 41))&(np.abs(X+.5-cx)<(8 if robot else 4.6))
 if not head_only:
  u=np.clip((X+.5-cx)/(8.5 if robot else 5),-.9,.9)*.7
  v=np.clip((Y-(58 if robot else 35))/(13 if robot else 8),-.9,.9)*.25
  nx=np.where(torso,u,nx);ny=np.where(torso,-v,ny);nz=np.where(torso,np.sqrt(np.maximum(.1,1-u*u-v*v)),nz)
 norm=np.stack([nx,ny,nz],axis=2);norm/=np.maximum(.001,np.linalg.norm(norm,axis=2))[:,:,None]
 output=np.zeros_like(image);output[:,:,:3]=np.rint((norm*.5+.5)*255).astype(np.uint8);output[:,:,3]=image[:,:,3]
 palette={**pals.get(model.replace('fantasia_',''),human),'eye_dummy':human['eye']}
 materials=np.zeros_like(image);materials[:,:,0]=230;materials[:,:,1]=15;materials[:,:,3]=image[:,:,3]
 if model=='endo':materials[:,:,0]=217;materials[:,:,1]=204
 protected=np.zeros(alpha.shape,bool)
 colors=image[:,:,:3].astype(np.int32)
 for key,response,spec,feature in [('eye_dummy',.55,.1,1),('line',.45,0,1),('dark',.45,0,1),('eye',.55,.1,1),('iris',.55,.1,1),('lens',.6,.3,1),('vest',.82,.04,0),('vestShade',.82,.04,0),('cream',.9,.14,0),('creamShade',.9,.14,0),('bow',.7,.3,0)]:
  if key not in palette:continue
  distance=np.sum((colors-np.array(rgb(palette[key]),np.int16))**2,dtype=np.int32,axis=2)
  selected=(distance<180)&alpha&~protected
  for channel,value in enumerate([response,spec,feature]):materials[:,:,channel][selected]=round(value*255)
  if feature:protected|=selected
 dest=root/'assets/iluminacao/personagens'/path.relative_to(root/'assets/personagens');dest.parent.mkdir(parents=True,exist_ok=True)
 salvar(Image.fromarray(output),dest);salvar(Image.fromarray(materials),dest.with_name(dest.stem+'_material.png'))
 total+=1
 if total%50==0:print(total,round(time.time()-start,1),flush=True)
print('Mapped sprite sheets:',total,'seconds',round(time.time()-start,1),flush=True)
(root/'dados/iluminacao.json').write_text(json.dumps({'ambient':.55,'ambientIndoorReduction':.13,'contrast':.6,'tint':.25,'normalStrength':1.35,'projection':'isometric 2:1','normalMaps':'Approximate smooth head, torso and limb surfaces, aligned to the existing atlas frames','materials':'R=response, G=specular, B=feature protection; alpha matches the source sheet','lights':{'luz_teto':{'height':140,'radius':270,'direction':'down'},'luz_parede':{'height':72,'radius':220,'direction':'wall normal, down','autoOrient':True,'cone':-.35,'cutawayMarker':True},'luz_chao':{'height':2,'radius':150,'direction':'up','energyMultiplier':1.6,'walkable':True}},'capacity':32,'occlusion':{'mode':'tile traversal','wallHeight':160,'cutawayIndependent':True,'channels':'R=barrier height, G=room ambient, B=structural ambient'},'wallSurfaces':{'normals':'cached per face','cutawayLighting':'neutral','cornerMounts':True,'ambient':'continuous room ambient across ends and junctions'},'doorSurfaces':{'normals':'cached per face, independent of neighbouring sprites','occlusion':'frame, header and leaf volumes','rotations':4,'ambient':'inherits adjoining room, including the floor footprint'}},indent=2))
