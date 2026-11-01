// NODE_PATH=/tmp/clarity-marketing-render/node_modules node render-devices.cjs
const fs = require('node:fs');
const path = require('node:path');
const sharp = require('sharp');
const {Resvg} = require('@resvg/resvg-js');
const root=__dirname;
const png=p=>'data:image/png;base64,'+fs.readFileSync(p).toString('base64');
const logo=png(path.join(root,'raw/clarity-logo.png'));
const text=(x,y,s,size,fill,weight=700)=>`<text x="${x}" y="${y}" font-size="${size}" font-weight="${weight}" fill="${fill}">${s}</text>`;
function brand(x,y,size,ink){return `<rect x="${x}" y="${y}" width="${size}" height="${size}" rx="${size*.24}" fill="white"/><svg x="${x+size*.08}" y="${y+size*.08}" width="${size*.84}" height="${size*.84}" viewBox="180 160 680 680"><image href="${logo}" width="1024" height="1024"/></svg>`+text(x+size*1.2,y+size*.74,'clarity',size*.55,ink);}
async function save(folder,name,w,h,art){
 for(const d of ['upload','editable'])fs.mkdirSync(path.join(root,folder,d),{recursive:true});
 const svg=`<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}" viewBox="0 0 ${w} ${h}"><g font-family="Helvetica Neue, Helvetica, Arial, sans-serif">${art}</g></svg>`;
 fs.writeFileSync(path.join(root,folder,'editable',name+'.svg'),svg);
 await sharp(new Resvg(svg,{font:{loadSystemFonts:true}}).render().asPng()).flatten({background:'white'}).removeAlpha().withIccProfile('srgb').png().toFile(path.join(root,folder,'upload',name+'.png'));
}
async function main(){
 const watch=[{file:'01-tasks.png',name:'01-tasks-at-hand',title:'Tasks at hand.',bg:'#254CE5',ink:'white'},{file:'03-reading.png',name:'02-small-daily-steps',title:'Small daily steps.',bg:'#BEF0D5',ink:'#113A32'}];
 for(const s of watch){
  const shot=png(path.join(root,'watch/raw',s.file));
  const art=`<rect width="416" height="496" fill="${s.bg}"/><circle cx="390" cy="400" r="220" fill="none" stroke="${s.ink}" stroke-opacity=".08" stroke-width="50"/>`+brand(24,18,35,s.ink)+text(24,100,s.title,32,s.ink)+`<rect x="67" y="126" width="282" height="336" rx="48" fill="#11141B"/><clipPath id="watch-screen"><rect x="72" y="131" width="272" height="324.31" rx="44"/></clipPath><image href="${shot}" x="72" y="131" width="272" height="324.31" clip-path="url(#watch-screen)"/>`;
  await save('watch',s.name,416,496,art);
  fs.mkdirSync(path.join(root,'watch/plain'),{recursive:true});
  await sharp(path.join(root,'watch/raw',s.file)).flatten({background:'black'}).removeAlpha().withIccProfile('srgb').png().toFile(path.join(root,'watch/plain',s.name+'.png'));
 }
 const duo=[{file:'tasks',name:'01-make-room',title:'Make room for what matters.',body:'Your tasks, together in one calm place.',bg:'#254CE5',ink:'#FFFFFF'}, {file:'habits',name:'02-build-your-routine',title:'Small steps. Stronger habits.',body:'Set daily goals. See your progress.',bg:'#BEF0D5',ink:'#113A32'}, {file:'stats',name:'03-see-your-progress',title:'See how far you’ve come.',body:'Explore your focus time and completed tasks.',bg:'#D5C8FA',ink:'#322449'}];
 for(const display of ['outer','inner']){
  for(const s of duo){
   const source=path.join(root,'duo/raw',display+'-'+s.file+'.png');
   if(!fs.existsSync(source))continue;
   const m=await sharp(source).metadata();
   const w=display==='outer'?1398:2853,h=display==='outer'?2034:2007;
   const shot=png(source);let art=`<rect width="${w}" height="${h}" fill="${s.bg}"/><circle cx="${w*.91}" cy="${h*.8}" r="${w*.5}" fill="none" stroke="${s.ink}" stroke-opacity=".07" stroke-width="120"/>`;
   art+=brand(85,60,85,s.ink);
   if(display==='outer'){
    const lines=s.file==='tasks'?['Make room for','what matters.']:s.file==='habits'?['Small steps.','Stronger habits.']:['See how far','you’ve come.'];
    lines.forEach((line,i)=>art+=text(80,270+i*95,line,87,s.ink));
    art+=text(85,454,s.body,37,s.ink,400);
    art+=`<rect x="189" y="535" width="1020" height="1484" rx="68" fill="#10141C"/><clipPath id="duo-screen"><rect x="202" y="548" width="994" height="${994*m.height/m.width}" rx="53"/></clipPath><image href="${shot}" x="202" y="548" width="994" height="${994*m.height/m.width}" clip-path="url(#duo-screen)"/>`;
   }else{
    art+=text(85,280,s.title,112,s.ink);
    art+=text(85,370,s.body,53,s.ink,400);
    const sw=2070,sh=sw*m.height/m.width,x=(w-sw)/2,y=485;
    art+=`<rect x="${x-14}" y="${y-14}" width="${sw+28}" height="${sh+28}" rx="70" fill="#10141C"/><clipPath id="inner-screen"><rect x="${x}" y="${y}" width="${sw}" height="${sh}" rx="56"/></clipPath><image href="${shot}" x="${x}" y="${y}" width="${sw}" height="${sh}" clip-path="url(#inner-screen)"/>`;
   }
   await save('duo/'+display,s.name,w,h,art);
  }
 }
 for(const folder of ['watch','duo/outer','duo/inner']){
  const dir=path.join(root,folder,'upload');if(!fs.existsSync(dir))continue;
  const files=fs.readdirSync(dir).filter(f=>f.endsWith('.png'));if(!files.length)continue;
  const thumbs=await Promise.all(files.map(f=>sharp(path.join(dir,f)).resize(420,620,{fit:'contain',background:'#F3F0EB'}).png().toBuffer()));
  await sharp({create:{width:420*files.length,height:620,channels:3,background:'#F3F0EB'}}).composite(thumbs.map((input,i)=>({input,left:420*i,top:0}))).png().toFile(path.join(root,folder,'preview.png'));
 }
}
main().catch(e=>{console.error(e);process.exitCode=1});
