const fs=require('fs'),path=require('path'),sharp=require('sharp'),{Resvg}=require('@resvg/resvg-js');
const root=__dirname,base=path.dirname(root),copy=require('../copy.json');
const png=p=>'data:image/png;base64,'+fs.readFileSync(p).toString('base64');
const logo=png(path.join(base,'raw/clarity-logo.png'));
const esc=s=>s.replaceAll('&','&amp;');
const text=(x,y,s,size,fill,weight=700)=>`<text x="${x}" y="${y}" font-size="${size}" font-weight="${weight}" fill="${fill}">${esc(s)}</text>`;
function frame(file,x,y,w,h,id){return `<rect x="${x-16}" y="${y-16}" width="${w+32}" height="${h+32}" rx="64" fill="#121723"/><clipPath id="${id}"><rect x="${x}" y="${y}" width="${w}" height="${h}" rx="48"/></clipPath><image href="${png(file)}" x="${x}" y="${y}" width="${w}" height="${h}" clip-path="url(#${id})"/>`;}
(async()=>{
for(const d of ['upload','editable'])fs.mkdirSync(path.join(root,d),{recursive:true});
// Enlarge the real category sidebar as a detail, without reconstructing app UI.
await sharp(path.join(root,'raw/05-categories.png')).extract({left:0,top:370,width:640,height:1480}).png().toFile(path.join(root,'raw/categories-detail.png'));
for(const [i,s] of copy.entries()){
let art=`<rect width="2064" height="2752" fill="${s.bg}"/><circle cx="1940" cy="2370" r="1030" fill="none" stroke="${s.ink}" stroke-opacity=".06" stroke-width="180"/><rect x="100" y="65" width="110" height="110" rx="26" fill="white"/><svg x="109" y="74" width="92" height="92" viewBox="180 160 680 680"><image href="${logo}" width="1024" height="1024"/></svg>`;
art+=text(240,147,'clarity',68,s.ink)+text(100,245,s.label,28,s.muted);
s.title.forEach((t,j)=>art+=text(92,380+j*132,t,126,s.ink));
s.body.forEach((t,j)=>art+=text(100,595+j*53,t,43,s.muted,400));
if(i===4){
art+=frame(path.join(root,'raw/01-tasks.png'),100,780,1260,1680,'tasks');
art+=frame(path.join(root,'raw/categories-detail.png'),1190,880,750,1734.375,'categories');
// Keep the enlarged detail inside the canvas.

}else if(s.premium){
art+=frame(path.join(root,'raw/01-tasks.png'),100,800,1240,1653.333,'free');
art+=`<rect x="1450" y="920" width="370" height="370" rx="84" fill="white"/><image href="${png(path.join(base,'raw/premium-icon.png'))}" x="1475" y="945" width="320" height="320"/>`;
art+=text(1435,1400,'Optional style.',43,s.ink)+text(1435,1470,'A little support.',38,s.muted,400);
art+=text(100,2635,'Every feature is available for free.',54,s.ink);
}else art+=frame(path.join(root,'raw',s.shot),292,730,1480,1973.333,'screen');
const svg=`<svg xmlns="http://www.w3.org/2000/svg" width="2064" height="2752"><g font-family="Helvetica Neue, Helvetica, Arial, sans-serif">${art}</g></svg>`;
fs.writeFileSync(path.join(root,'editable',s.name+'.svg'),svg);
await sharp(new Resvg(svg,{font:{loadSystemFonts:true}}).render().asPng()).flatten({background:s.bg}).removeAlpha().withIccProfile('srgb').png().toFile(path.join(root,'upload',s.name+'.png'));
}
const files=fs.readdirSync(path.join(root,'upload')).filter(x=>x.endsWith('.png'));
const thumbs=await Promise.all(files.map(f=>sharp(path.join(root,'upload',f)).resize(516,688).png().toBuffer()));
await sharp({create:{width:1548,height:1376,channels:3,background:'white'}}).composite(thumbs.map((input,i)=>({input,left:i%3*516,top:Math.floor(i/3)*688}))).png().toFile(path.join(root,'preview.png'));
for(const f of files){const m=await sharp(path.join(root,'upload',f)).metadata(); console.log(f,m.width,m.height,m.channels,m.hasAlpha);}
})();
