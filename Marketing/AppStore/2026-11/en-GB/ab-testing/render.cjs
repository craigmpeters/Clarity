const fs=require('fs'),path=require('path'),sharp=require('sharp'),{Resvg}=require('@resvg/resvg-js');
const root=__dirname,base=path.dirname(root);for(const d of ['upload','editable','previews'])fs.mkdirSync(path.join(root,d),{recursive:true});
const png=n=>'data:image/png;base64,'+fs.readFileSync(path.join(base,'raw',n)).toString('base64');
const logo=png('clarity-logo.png');let id=0;
const text=(x,y,t,s,c,w=700)=>`<text x="${x}" y="${y}" font-size="${s}" fill="${c}" font-weight="${w}">${t}</text>`;
function brand(x,y,c,s=80){return `<rect x="${x}" y="${y}" width="${s}" height="${s}" rx="${s*.23}" fill="white"/><svg x="${x+s*.08}" y="${y+s*.08}" width="${s*.84}" height="${s*.84}" viewBox="180 160 680 680"><image href="${logo}" width="1024" height="1024"/></svg>`+text(x+s*1.22,y+s*.75,'clarity',s*.68,c);}
function card(file,x,y,w,h,view='0 0 1320 2868',angle=0){const key='c'+id++;return `<g transform="rotate(${angle} ${x+w/2} ${y+h/2})"><rect x="${x-12}" y="${y-12}" width="${w+24}" height="${h+24}" rx="50" fill="#171B30"/><clipPath id="${key}"><rect x="${x}" y="${y}" width="${w}" height="${h}" rx="38"/></clipPath><g clip-path="url(#${key})"><svg x="${x}" y="${y}" width="${w}" height="${h}" viewBox="${view}" preserveAspectRatio="xMidYMin slice"><image href="${png(file)}" width="1320" height="2868"/></svg></g></g>`;}
const variants=[{key:'A-calm-day',bg:'#F8EEDF',ink:'#173C34',accent:'#BCDCCB',lines:['Make space','for your day.'],sub:'Tasks. Habits. A calmer routine.',file:'01-tasks.png'}, {key:'B-full-focus',bg:'#211B59',ink:'#FFF5DB',accent:'#F6DB58',lines:['One task.','Full focus.'],sub:'Find your rhythm with Clarity.',file:'03-focus.png'}];
(async()=>{const tiles=[];
for(const v of variants)for(const kind of ['header','search','ppo-screenshot']){
const phone=kind==='ppo-screenshot',w=phone?1320:3840,h=phone?2868:kind==='header'?1646:2560;
let art=`<rect width="${w}" height="${h}" fill="${v.bg}"/>`;
if(v.key[0]==='A')art+=`<circle cx="${w*.92}" cy="${h*.75}" r="${w*.29}" fill="${v.accent}"/><path d="M-200 ${h*.85} Q${w*.2} ${h*.1} ${w*.55} ${h*1.3}" fill="none" stroke="#E8D6B8" stroke-width="130"/>`;
else art+=`<circle cx="${w*.83}" cy="${h*.69}" r="${w*.24}" fill="none" stroke="#7165C9" stroke-width="${w*.075}"/><path d="M${w*.8} 0 L${w*.64} ${h*.45} L${w*.82} ${h*.45} L${w*.63} ${h}" fill="none" stroke="${v.accent}" stroke-width="${w*.045}"/>`;
if(phone){art+=brand(84,80,v.ink,100);v.lines.forEach((t,i)=>art+=text(80,420+i*140,t,132,v.ink));art+=text(84,700,v.sub,45,v.ink,400);art+=card(v.file,205,850,910,1977.18);}
else{
const search=kind==='search',x=search?945:1165,y=search?835:535;
art+=brand(x,y,v.ink,search?110:90);
v.lines.forEach((t,i)=>art+=text(x,y+(search?285:215)+i*(search?142:125),t,search?128:116,v.ink));
art+=text(x,y+(search?590:515),v.sub,search?43:37,v.ink,400);
art+=card(v.file,search?2220:2050,y+85,search?625:590,search?750:490,v.key[0]==='A'?'45 455 1230 1250':'140 515 1040 1250',v.key[0]==='A'?-3:5);
art+=card(v.key[0]==='A'?'02-habits.png':'01-tasks.png',search?360:250,search?1900:1170,780,550,'45 455 1230 866',-9);
}
const name=v.key+'-'+kind,svg=`<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}"><g font-family="Helvetica Neue, Helvetica, Arial, sans-serif">${art}</g></svg>`;
fs.writeFileSync(path.join(root,'editable',name+'.svg'),svg);const out=path.join(root,'upload',name+'.png');
await sharp(new Resvg(svg,{font:{loadSystemFonts:true}}).render().asPng()).flatten({background:v.bg}).removeAlpha().withIccProfile('srgb').png().toFile(out);
if(!phone){const safe=kind==='header'?[1097,493,1646,661]:[836,765,2168,1030];await sharp(out).extract({left:safe[0],top:safe[1],width:safe[2],height:safe[3]}).resize(900,500,{fit:'contain',background:v.bg}).png().toFile(path.join(root,'previews',name+'-focal.png'));}
tiles.push(await sharp(out).resize(640,650,{fit:'contain',background:'#ECEAE6'}).png().toBuffer());console.log(name,w,h);
}
await sharp({create:{width:1920,height:1300,channels:3,background:'#ECEAE6'}}).composite(tiles.map((input,i)=>({input,left:i%3*640,top:Math.floor(i/3)*650}))).png().toFile(path.join(root,'preview.png'));
})();
