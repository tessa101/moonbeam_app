import math, sys
# Authored in reference-panel px, mapped into the 400x520 viewBox.
S=1.992; CX_REF=372; CY0_REF=95; VB_X=200; VB_Y=107
XF=f'translate({VB_X} {VB_Y}) scale({1/S:.5f}) translate({-CX_REF} {-CY0_REF})'
def vb(px,py): return (VB_X+(px-CX_REF)/S, VB_Y+(py-CY0_REF)/S)

# ---- moon (reference px) ----
MC=(352,287); MR=192           # full disc
CC=(446,258); CR=188           # cutout circle
def crescent(mirror=False):
    (x1,y1),r1=MC,MR; (x2,y2),r2=CC,CR
    d=math.hypot(x2-x1,y2-y1); a=(r1*r1-r2*r2+d*d)/(2*d); h=math.sqrt(r1*r1-a*a)
    xm=x1+a*(x2-x1)/d; ym=y1+a*(y2-y1)/d
    p1=(xm+h*(y2-y1)/d, ym-h*(x2-x1)/d); p2=(xm-h*(y2-y1)/d, ym+h*(x2-x1)/d)
    top,bot=(p1,p2) if p1[1]<p2[1] else (p2,p1)
    return f'M{top[0]:.1f} {top[1]:.1f} A{r1} {r1} 0 1 0 {bot[0]:.1f} {bot[1]:.1f} A{r2} {r2} 0 0 1 {top[0]:.1f} {top[1]:.1f}Z'

DEFS='''<defs>
<radialGradient id="halo" gradientUnits="userSpaceOnUse" cx="%d" cy="%d" r="%d"><stop offset="0" stop-color="#EDBA69" stop-opacity=".30"/><stop offset=".45" stop-color="#EDBA69" stop-opacity=".22"/><stop offset=".72" stop-color="#EDBA69" stop-opacity=".08"/><stop offset="1" stop-color="#EDBA69" stop-opacity="0"/></radialGradient>
<linearGradient id="disc" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#F6E3B4"/><stop offset=".55" stop-color="#F7E8C2"/><stop offset="1" stop-color="#E7CB94"/></linearGradient>
<linearGradient id="cream" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#E9DCC3"/><stop offset=".30" stop-color="#DACAAB"/><stop offset=".70" stop-color="#BFAC8C"/><stop offset="1" stop-color="#8E7C64"/></linearGradient>
<linearGradient id="dark" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#52454A"/><stop offset=".25" stop-color="#33292C"/><stop offset=".75" stop-color="#241C1F"/><stop offset="1" stop-color="#171113"/></linearGradient>
<linearGradient id="amber" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#F7CE86"/><stop offset=".6" stop-color="#E5A24F"/><stop offset="1" stop-color="#B9772E"/></linearGradient>
<radialGradient id="lens" cx=".62" cy=".45" r=".7"><stop offset="0" stop-color="#FFD790"/><stop offset=".55" stop-color="#EDAA55"/><stop offset="1" stop-color="#B9772E"/></radialGradient>
<linearGradient id="leg" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#EBDDC0"/><stop offset=".5" stop-color="#D8C7A6"/><stop offset="1" stop-color="#B5A284"/></linearGradient>
<radialGradient id="ground" cx=".5" cy=".5" r=".5"><stop offset="0" stop-color="#EDBA69" stop-opacity=".30"/><stop offset=".6" stop-color="#EDBA69" stop-opacity=".08"/><stop offset="1" stop-color="#EDBA69" stop-opacity="0"/></radialGradient>
<radialGradient id="glintg" cx=".55" cy=".4" r=".6"><stop offset="0" stop-color="#FFE9B8" stop-opacity=".95"/><stop offset=".5" stop-color="#FFD590" stop-opacity=".45"/><stop offset="1" stop-color="#FFD590" stop-opacity="0"/></radialGradient>
</defs>''' % (MC[0]-70,MC[1]+10,MR*1.25)

HEAD=(380,540)  # mount head centre (ref px)
ANG=-26         # tube angle
def tube():
    # local coords: x along axis from eyepiece (0) to objective; y across
    segs=[ # x0,x1,h0,h1,fill
      (22,128,31,38,'url(#dark)'),
      (118,222,43,54,'url(#cream)'),
      (214,276,60,62,'url(#dark)'),
      (268,398,63,68,'url(#cream)'),
      (392,462,73,79,'url(#dark)'),
    ]
    o=[]
    # eyepiece amber ring
    o.append('<path d="M-4 -26 L30 -30 L30 30 L-4 26 Q-16 0 -4 -26Z" fill="url(#amber)"/>')
    o.append('<ellipse cx="-4" cy="0" rx="9" ry="26" fill="#2A2124" stroke="#E9B567" stroke-width="3"/>')
    for x0,x1,h0,h1,f in segs:
        o.append(f'<path d="M{x0} {-h0} L{x1} {-h1} L{x1} {h1} L{x0} {h0}Z" fill="{f}"/>')
    # soft highlight streak on the long cream body
    o.append('<path d="M280 -50 L392 -54" stroke="#F6EBD3" stroke-width="5" stroke-linecap="round" opacity=".4"/>')
    o.append('<path d="M128 -34 L212 -42" stroke="#FFF7E3" stroke-width="4" stroke-linecap="round" opacity=".45"/>')
    # objective rim + lens
    o.append('<ellipse cx="462" cy="0" rx="34" ry="84" fill="url(#cream)" stroke="#EADBBE" stroke-width="3"/>')
    o.append('<ellipse cx="468" cy="0" rx="26" ry="68" fill="url(#lens)"/>')
    o.append('<ellipse cx="476" cy="-10" rx="10" ry="34" fill="#FFE2A8" opacity=".35"/>')
    return f'<g transform="translate({HEAD[0]} {HEAD[1]}) rotate({ANG}) translate(-205 -92)">'+''.join(o)+'</g>'

def stand():
    hx,hy=HEAD
    o=[]
    o.append(f'<ellipse cx="{hx}" cy="830" rx="230" ry="14" fill="url(#ground)"/>')
    # legs (behind head)
    o.append(f'<path d="M{hx-14} {hy+40} L{hx-188} 828 L{hx-156} 828 L{hx+4} {hy+60}Z" fill="url(#leg)"/>')
    o.append(f'<path d="M{hx+14} {hy+40} L{hx+188} 828 L{hx+156} 828 L{hx-4} {hy+60}Z" fill="url(#leg)"/>')
    o.append(f'<path d="M{hx-17} {hy+44} L{hx-17} 830 L{hx+17} 830 L{hx+17} {hy+44}Z" fill="url(#leg)"/>')
    # bracket + head
    o.append(f'<path d="M{hx-30} {hy+30} L{hx-20} {hy+86} L{hx+20} {hy+86} L{hx+30} {hy+30}Z" fill="url(#dark)"/>')
    o.append(f'<circle cx="{hx}" cy="{hy}" r="50" fill="url(#dark)"/>')
    o.append(f'<circle cx="{hx}" cy="{hy}" r="32" fill="url(#cream)"/>')
    o.append(f'<circle cx="{hx-2}" cy="{hy-2}" r="5" fill="#9B7F5A"/>')
    return ''.join(o)

def glint():
    return (f'<g transform="translate({HEAD[0]} {HEAD[1]}) rotate({ANG}) translate(-205 -92)">'
            '<ellipse cx="470" cy="-6" rx="30" ry="76" fill="url(#glintg)"/>'
            '<path d="M479 -44 Q492 -22 484 -4" stroke="#FFF3D2" stroke-width="5" stroke-linecap="round" fill="none"/></g>')
def moon_halo(): return f'<circle cx="{MC[0]}" cy="{MC[1]}" r="{MR*1.6:.0f}" fill="url(#halo)"/>'
def moon_disc(): 
    return (f'<circle cx="{MC[0]}" cy="{MC[1]}" r="{MR}" fill="#2B2023" fill-opacity=".55" stroke="#EDBA69" stroke-opacity=".10" stroke-width="2"/>'
            f'<path d="{crescent()}" fill="url(#disc)"/>')

def layer_svg(name,mirror=False):
    body=f'<g transform="{XF}">{parts[name]}</g>'
    if mirror and name in ('moonHalo','moonDisc'): body=f'<g transform="translate(400 0) scale(-1 1)">{body}</g>'
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="400" height="520" viewBox="0 0 400 520">{DEFS}{body}</svg>'
def full_svg(mirror=False, glint_on=0):
    names=['moonHalo','moonDisc','stand','tube']+(['lensGlint'] if glint_on else [])
    inner=''
    for n in names:
        b=f'<g transform="{XF}">{parts[n]}</g>'
        if mirror and n in ('moonHalo','moonDisc'): b=f'<g transform="translate(400 0) scale(-1 1)">{b}</g>'
        inner+=b
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="400" height="520" viewBox="0 0 400 520">{DEFS}{inner}</svg>'

def moonG(mirror):  # moon layers mirrored about its own centre only
    return mirror
parts={'lensGlint':glint(),'moonHalo':moon_halo(),'moonDisc':moon_disc(),'stand':stand(),'tube':tube()}
if __name__=='__main__':
    open('A_full.svg','w').write(full_svg(False)); open('B_full.svg','w').write(full_svg(True))
    for n in parts:
        open(f'layerA_{n}.svg','w').write(layer_svg(n,False)); open(f'layerB_{n}.svg','w').write(layer_svg(n,True))
