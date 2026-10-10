from pathlib import Path
import cv2, numpy as np, subprocess, json, re
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'reference/d2-approved.png'
img=cv2.bilateralFilter(np.array(Image.open(SOURCE).convert('RGB')),9,28,12)
NODE='/Users/tc/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node'
SHARP='/Users/tc/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp'
# Hand-defined silhouettes preserve the approved raster's proportions; interior colors are vector traced.
shapes={
'searching':{
 'tail':'M133 587 C92 594 78 557 81 520 C82 489 93 464 87 446 C80 431 64 436 65 420 C66 399 87 398 101 410 C129 432 126 457 118 485 C104 524 111 548 140 558 Z',
 'body':'M205 377 C219 412 194 441 170 466 C139 498 120 538 120 577 Q120 601 142 608 L279 609 Q299 609 289 595 L281 590 Q284 569 288 548 L283 433 L276 382 Z',
 'head':'M190 339 L204 270 L231 302 Q254 295 267 302 L282 270 L286 307 Q303 319 301 344 Q311 362 300 376 Q283 391 251 396 Q223 400 205 385 Q185 368 190 339 Z',
 'paw':'M284 446 C291 417 325 400 343 380 C359 362 360 341 348 323 Q330 300 303 302 Q278 300 271 311 Q266 322 278 325 Q289 329 302 321 Q319 313 328 334 C339 357 316 369 298 382 Q277 395 284 446 Z'},
'location-not-found':{
 'tail':'M653 578 C683 562 704 536 709 505 C712 485 706 466 706 450 C708 429 724 425 736 438 C750 454 746 477 740 496 C730 542 705 577 669 593 Z',
 'body':'M574 388 C572 429 541 457 521 485 C495 522 495 565 506 591 Q514 608 544 610 L640 610 Q658 610 658 600 L655 532 Q655 474 639 421 L624 384 Z',
 'head':'M554 350 L511 338 L545 371 Q550 401 581 414 Q610 422 638 397 Q657 376 645 344 Q635 321 610 313 L589 276 L578 312 Q559 322 554 350 Z'}
}

def mask_for(d):
 s=f'<svg xmlns="http://www.w3.org/2000/svg" width="1942" height="809"><path d="{d}" fill="white"/></svg>'
 tmp=ROOT/'tools/mask.svg'; tmp.write_text(s)
 subprocess.run([NODE,'-e',f"require('{SHARP}')(process.argv[1]).png().toFile(process.argv[2])",str(tmp),str(ROOT/'tools/mask.png')],check=True)
 return np.array(Image.open(ROOT/'tools/mask.png').convert('RGBA'))[:,:,3]>100

def curve(contour):
 pts=cv2.approxPolyDP(contour,0.9,True).reshape(-1,2)
 if len(pts)<3:return ''
 mids=(pts+np.roll(pts,-1,axis=0))/2
 d=f'M{mids[-1,0]:.1f},{mids[-1,1]:.1f}'
 for p,m in zip(pts,mids):d+=f'Q{p[0]},{p[1]} {m[0]:.1f},{m[1]:.1f}'
 return d+'Z'

def trace(d,gid):
 mask=mask_for(d); pixels=img[mask].astype(np.float32)
 cv2.setRNGSeed(42)
 _,labels,centers=cv2.kmeans(pixels,8,None,(cv2.TERM_CRITERIA_EPS+cv2.TERM_CRITERIA_MAX_ITER,60,.25),3,cv2.KMEANS_PP_CENTERS)
 labelmap=np.full(mask.shape,-1,np.int16);labelmap[mask]=labels.flatten()
 out=[f'<g id="{gid}"><path d="{d}" fill="#493d39"/>']
 for i,color in enumerate(centers):
  cm=(labelmap==i).astype(np.uint8)*255
  contours,_=cv2.findContours(cm,cv2.RETR_LIST,cv2.CHAIN_APPROX_SIMPLE)
  ds=''.join(curve(c) for c in contours if cv2.contourArea(c)>9)
  if ds:
   hx='#'+''.join(f'{int(v):02x}' for v in color)
   out.append(f'<path fill="{hx}" stroke="{hx}" stroke-width="0.65" fill-rule="evenodd" d="{ds}"/>')
 out.append('</g>');return ''.join(out)

def moon(prefix,cx,cy,r,kind):
 defs=f'''<radialGradient id="{prefix}-halo"><stop offset="0" stop-color="#EDBA69" stop-opacity=".27"/><stop offset=".48" stop-color="#EDBA69" stop-opacity=".17"/><stop offset=".75" stop-color="#EDBA69" stop-opacity=".045"/><stop offset="1" stop-color="#EDBA69" stop-opacity="0"/></radialGradient><radialGradient id="{prefix}-disc" cx="42%" cy="36%" r="72%"><stop stop-color="#F7E7BD"/><stop offset="1" stop-color="#E9CC94"/></radialGradient>'''
 if kind=='ring':
  return defs,f'<g id="moon"><circle id="moon-disc" cx="{cx}" cy="{cy}" r="{r}" fill="#3B3030" opacity=".2"/><circle id="moon-ring" cx="{cx}" cy="{cy}" r="{r}" fill="none" stroke="#C59B61" stroke-width="1.8" stroke-dasharray="6 8" opacity=".72"/></g>'
 glow=f'<circle id="moon-halo" cx="{cx}" cy="{cy}" r="{r*1.65}" fill="url(#{prefix}-halo)"/>'
 if kind=='full':disc=f'<circle id="moon-disc" cx="{cx}" cy="{cy}" r="{r}" fill="url(#{prefix}-disc)"/>'
 else:
  # Two arcs form a true transparent crescent, without a background-colored occluder or SVG filters.
  disc=f'<path id="moon-disc" d="M{cx+8} {cy-r} A{r} {r} 0 1 0 {cx+8} {cy+r} C{cx-r*.98} {cy+r*.63} {cx-r*.98} {cy-r*.65} {cx+8} {cy-r}Z" fill="url(#{prefix}-disc)"/>'
 return defs,f'<g id="moon">{glow}{disc}</g>'

assets={}
for state,parts in shapes.items():
 groups={k:trace(v,k) for k,v in parts.items()}
 x=15 if state=='searching' else 430
 cx=230 if state=='searching' else 603
 defs,m=moon(state,cx,332,135 if state=='searching' else 116,'full' if state=='searching' else 'ring')
 # Head and raised paw move together; tails remain independent.
 fg=groups['tail']+groups['body']+'<g id="look">'+groups['head']+groups.get('paw','')+'</g>'
 if state!='searching':
  fg+='<g id="question"><path d="M677 292 C678 279 696 280 697 291 C698 300 685 301 685 310" fill="none" stroke="#D6AA6D" stroke-width="5" stroke-linecap="round"/><circle cx="685" cy="320" r="3" fill="#D6AA6D"/></g>'
 assets[state]=(x,defs,m,fg)
# Telescope: faithful geometry traced as a separate tube and stand.
tube='M864 429 L1038 324 Q1054 314 1068 328 Q1086 349 1088 376 Q1088 390 1075 396 L916 465 Q905 473 898 461 L872 471 Q863 473 857 462 Q850 448 855 441 Z'
stand='M946 456 L949 443 Q963 434 978 447 Q992 459 982 475 L1012 604 L1004 605 L970 489 L964 607 L954 607 L955 488 L909 606 L900 605 L947 475 Z'
defs,m=moon('permission-off',960,342,105,'crescent')
stand_svg='<g id="stand"><path d="M958 469 L900 605 L908 605 L965 480 L1006 605 L1013 605 L974 469Z" fill="#BCA78B"/><path d="M958 473 L955 606 L965 606 L969 473Z" fill="#8F7D68"/><path d="M960 429 L958 455 L974 455 L971 429Z" fill="#A28C70"/><circle cx="965" cy="465" r="17" fill="#56473D"/><circle cx="965" cy="465" r="10" fill="#C6AE8C"/></g>'
tube_svg='<g id="tube"><g transform="rotate(-28 966 403)"><path d="M857 387 H889 V420 H857 Q846 404 857 387Z" fill="#8B7154"/><ellipse cx="857" cy="404" rx="8" ry="16" fill="#3A3030" stroke="#CEAA74" stroke-width="2"/><path d="M880 379 H1070 V432 H880Z" fill="#C7B79C"/><path d="M894 379 H907 V432 H894Z M988 379 H1006 V432 H988Z" fill="#423635"/><path d="M1048 375 H1072 Q1090 402 1072 435 H1048Z" fill="#4C3D36"/><ellipse cx="1072" cy="405" rx="15" ry="30" fill="#B89465" stroke="#C9B391" stroke-width="2"/><ellipse cx="1075" cy="405" rx="9" ry="24" fill="#5A4738"/><path d="M909 380 H986" stroke="#D9C5A5" stroke-width="1.4" opacity=".6"/></g></g>'
assets['permission-off']=(810,defs,m,stand_svg+tube_svg)
for state,x in [('services-off',1180),('restricted',1570)]:
 # Match the three folded panels and warm route from D2 with clean editable paths.
 left=x+13; top=345; mid=x+92; fold=x+173; right=x+316
 mapshape=f'<g id="map"><path d="M{left} 381 L{mid} {top} L{fold} 401 L{right} 369 L{right} 561 L{fold} 601 L{mid} 565 L{left} 599Z" fill="#4D403A" stroke="#AA9272" stroke-width="3" stroke-linejoin="round"/><path d="M{mid} {top} L{fold} 401 L{fold} 601 L{mid} 565Z" fill="#30282A"/><path d="M{mid} {top} V565 M{fold} 401 V601" fill="none" stroke="#8A7660" stroke-width="1.7"/><g id="route"><path d="M{left+5} 479 C{left+75} 407 {mid+12} 465 {mid+49} 499 S{fold+69} 474 {right-43} 470 Q{right-18} 478 {right-3} 515" fill="none" stroke="#D2A264" stroke-width="4.2" stroke-dasharray="10 9"/><circle cx="{left+38}" cy="454" r="10" fill="#DFB173"/><circle cx="{mid+49}" cy="503" r="10" fill="#DFB173"/><circle cx="{right-43}" cy="470" r="10" fill="#DFB173"/></g>'
 if state=='restricted':
  lx=x+147
  mapshape+=f'<g id="lock"><path d="M{lx-8} 443 V433 A8 8 0 0 1 {lx+8} 433 V443" fill="none" stroke="#D9AD70" stroke-width="4"/><rect x="{lx-15}" y="441" width="30" height="26" rx="3" fill="#D9AD70"/><path d="M{lx} 451 V459" stroke="#493C32" stroke-width="3" stroke-linecap="round"/><circle cx="{lx}" cy="451" r="3" fill="#493C32"/></g>'
 mapshape+='</g>'
 defs,m=moon(state,x+172,342,105,'crescent')
 assets[state]=(x-28,defs,m,mapshape)

for state,(x,defs,m,fg) in assets.items():
 svg=f'''<svg xmlns="http://www.w3.org/2000/svg" width="400" height="520" viewBox="0 0 400 520" role="img" aria-labelledby="title"><title id="title">D2 luminous calico — {state.replace('-',' ')}</title><desc>Transparent vector reconstruction of the approved D2 illustration. Separate moon and foreground groups. Static, without embedded raster images.</desc><defs>{defs}</defs><g transform="translate({-x} -130)">{m}<g id="foreground">{fg}</g></g></svg>'''
 (ROOT/'stills'/f'd2-{state}.svg').write_text(svg)
(ROOT/'tools/mask.svg').unlink(missing_ok=True);(ROOT/'tools/mask.png').unlink(missing_ok=True)
print('Wrote',len(assets),'standalone SVGs')
