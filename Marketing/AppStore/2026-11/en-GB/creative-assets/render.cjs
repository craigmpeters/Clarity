// NODE_PATH=/tmp/clarity-marketing-render/node_modules node render.cjs
const fs = require('node:fs');
const path = require('node:path');
const sharp = require('sharp');
const { Resvg } = require('@resvg/resvg-js');
const root = __dirname;
for (const dir of ['upload', 'editable', 'previews']) fs.mkdirSync(path.join(root, dir), {recursive:true});
const image = name => 'data:image/png;base64,' + fs.readFileSync(path.join(root,'..','raw',name)).toString('base64');
const shots = {tasks:image('01-tasks.png'), habits:image('02-habits.png'), focus:image('03-focus.png')};
const text = (x,y,s,size,fill='#FFFFFF',weight=700,extra='') => `<text x="${x}" y="${y}" font-size="${size}" font-weight="${weight}" fill="${fill}" ${extra}>${s}</text>`;
let id = 0;
function panel(shot,x,y,w,h,view,angle=0) {
    const key = 'clip'+id++;
    return `<g transform="rotate(${angle} ${x+w/2} ${y+h/2})"><rect x="${x-10}" y="${y-10}" width="${w+20}" height="${h+20}" rx="55" fill="#FFFFFF" fill-opacity=".16"/><rect x="${x}" y="${y+18}" width="${w}" height="${h}" rx="48" fill="#10206A" opacity=".15"/><clipPath id="${key}"><rect x="${x}" y="${y}" width="${w}" height="${h}" rx="48"/></clipPath><g clip-path="url(#${key})"><svg x="${x}" y="${y}" width="${w}" height="${h}" viewBox="${view}" preserveAspectRatio="xMidYMin slice"><image href="${shots[shot]}" width="1320" height="2868"/></svg></g></g>`;
}
function bg(w,h,mint=false) {
    const base = mint?'#BEF0D5':'#254CE5';
    return `<rect width="${w}" height="${h}" fill="${base}"/><circle cx="${w*.15}" cy="${h*1.03}" r="${w*.26}" fill="none" stroke="${mint?'#71CCA8':'#5174F0'}" stroke-width="${w*.10}"/><circle cx="${w*.93}" cy="${h*.1}" r="${w*.31}" fill="none" stroke="${mint?'#DFF8EB':'#355CDE'}" stroke-width="${w*.11}"/><path d="M${w*-.1} ${h*.8} C${w*.28} ${h*-.55},${w*.78} ${h*1.65},${w*1.08} ${h*.16}" fill="none" stroke="${mint?'#94DDBB':'#4568E9'}" stroke-width="${w*.045}"/>`;
}
function brand(x,y,color,size=76) {
    const tile = size * 1.45;
    return `<rect x="${x}" y="${y-tile*.87}" width="${tile}" height="${tile}" rx="${tile*.24}" fill="#FFFFFF"/><svg x="${x+tile*.08}" y="${y-tile*.79}" width="${tile*.84}" height="${tile*.84}" viewBox="180 160 680 680"><image href="${image('clarity-logo.png')}" width="1024" height="1024"/></svg>`+text(x+tile+25,y,'clarity',size,color,700,'letter-spacing="-3"');
}
const assets = [
    {name:'clarity-header-3840x1646',w:3840,h:1646,safe:[1097,493,1646,661],kind:'header'},
    {name:'clarity-search-results-3840x2560',w:3840,h:2560,safe:[836,765,2168,1030],kind:'search'},
    {name:'clarity-universal-5244x2950',w:5244,h:2950,safe:[1921,660,1402,962],kind:'universal'},
];
async function main(){
    const previews=[];
    for(const a of assets){
        id=0; const mint=a.kind==='search'; const ink=mint?'#113A32':'#FFFFFF';
        let art=bg(a.w,a.h,mint);
        if(a.kind==='header'){
            art+=brand(1170,624,ink,77);
            art+=text(1165,798,'Make room.',112,ink,700,'letter-spacing="-4"');
            art+=text(1165,927,'Find focus.',112,ink,700,'letter-spacing="-4"');
            art+=text(1170,1040,'Tasks. Habits. A calmer day.',43,'#DCE5FF',400);
            art+=panel('tasks',2000,625,690,430,'45 455 1230 766',-3);
            // Secondary UI details add texture outside the main focal area.
            art+=panel('habits',255,1010,730,620,'50 450 1220 1040',-9);
            art+=panel('focus',2990,-155,650,800,'140 515 1040 1280',9);
        }else if(a.kind==='search'){
            art+=brand(960,955,ink,92);
            art+=text(950,1160,'Tasks. Habits.',119,ink,700,'letter-spacing="-4"');
            art+=text(950,1303,'Room to focus.',119,ink,700,'letter-spacing="-4"');
            art+=text(960,1440,'Make space for what matters.',48,'#365F52',400);
            art+=panel('tasks',2090,900,800,665,'45 455 1230 1022',4);
            art+=panel('habits',1125,1630,1160,420,'50 445 1220 442',-4);
            art+=panel('focus',-230,370,700,900,'140 515 1040 1337',-10);
        }else{
            art+=brand(1970,815,ink,77);
            art+=text(1960,1013,'Make room.',95,ink,700,'letter-spacing="-3"');
            art+=text(1960,1125,'Find focus.',95,ink,700,'letter-spacing="-3"');
            art+=text(1970,1248,'Tasks. Habits. Clarity.',38,'#DCE5FF',400);
            art+=panel('tasks',2685,830,575,480,'45 455 1230 1027',3);
            art+=panel('habits',2050,1460,1120,410,'50 445 1220 447',-4);
            art+=panel('focus',700,1390,780,1020,'140 515 1040 1360',-10);
            art+=panel('tasks',3840,500,820,1100,'45 455 1230 1650',10);
        }
        const wrap=content=>`<svg xmlns="http://www.w3.org/2000/svg" width="${a.w}" height="${a.h}" viewBox="0 0 ${a.w} ${a.h}"><g font-family="Helvetica Neue, Helvetica, Arial, sans-serif">${content}</g></svg>`;
        const svg=wrap(art);
        fs.writeFileSync(path.join(root,'editable',a.name+'.svg'),svg);
        const out=path.join(root,'upload',a.name+'.png');
        await sharp(new Resvg(svg,{font:{loadSystemFonts:true}}).render().asPng()).flatten({background:mint?'#BEF0D5':'#254CE5'}).removeAlpha().withIccProfile('srgb').png().toFile(out);
        const [x,y,w,h]=a.safe;
        const overlay=wrap(`<rect width="${a.w}" height="${a.h}" fill="#101522" fill-opacity=".4"/><rect x="${x}" y="${y}" width="${w}" height="${h}" fill="none" stroke="#FFFFFF" stroke-width="6" stroke-dasharray="24 18"/>`);
        const checked = await sharp(out).composite([{input:Buffer.from(overlay)}]).png().toBuffer();
        await sharp(checked).resize({width:1200}).png().toFile(path.join(root,'previews',a.kind+'-safe-area.png'));
        await sharp(out).extract({left:x,top:y,width:w,height:h}).resize({width:1000}).png().toFile(path.join(root,'previews',a.kind+'-focal-area.png'));
        previews.push(await sharp(out).resize(1200,800,{fit:'contain',background:'#F3F0EB'}).png().toBuffer());
    }
    await sharp({create:{width:1200,height:2400,channels:3,background:'#F3F0EB'}}).composite(previews.map((input,i)=>({input,left:0,top:i*800}))).png().toFile(path.join(root,'preview.png'));
}
main().catch(e=>{console.error(e);process.exitCode=1});
