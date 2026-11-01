// Rebuild: npm install --prefix /tmp/clarity-marketing-render @resvg/resvg-js sharp
// NODE_PATH=/tmp/clarity-marketing-render/node_modules node render.cjs
const fs = require('node:fs');
const path = require('node:path');
const { Resvg } = require('@resvg/resvg-js');
const sharp = require('sharp');
const root = __dirname;
const slides = [
    { name: '01-make-room', bg: '#254CE5', ink: '#FFFFFF', muted: '#DCE5FF', label: 'YOUR DAY, WITH CLARITY', title: ['Make room for', 'what matters.'], body: ['Bring your tasks, habits and focus', 'together in one calm place.'], shot: '01-tasks.png' },
    { name: '02-small-steps', bg: '#BEF0D5', ink: '#113A32', muted: '#365F52', label: 'BUILD YOUR ROUTINE', title: ['Small steps.', 'Stronger habits.'], body: ['Set daily goals. Log your progress.', 'See your last seven days at a glance.'], shot: '02-habits.png' },
    { name: '03-find-focus', bg: '#FFB38B', ink: '#4C251D', muted: '#6E4033', label: 'ONE TASK AT A TIME', title: ['Find your focus.', 'Keep it simple.'], body: ['Start a Pomodoro from any task', 'and give it your full attention.'], shot: '03-focus.png' },
    { name: '04-see-progress', bg: '#D5C8FA', ink: '#322449', muted: '#5B4978', label: 'NOTICE YOUR PROGRESS', title: ['See how far', 'you’ve come.'], body: ['Explore completed tasks, focus time', 'and your productivity patterns.'], shot: '04-statistics.png' },
    { name: '05-your-priorities', bg: '#F6DF76', ink: '#403412', muted: '#6A5825', label: 'SPACE FOR EVERY PRIORITY', title: ['Your life.', 'Your categories.'], body: ['Colour-code what matters to you', 'and set your own weekly targets.'], shot: '05-categories.png' },
    { name: '06-free-functionality', bg: '#35204F', ink: '#FFF5E3', muted: '#DCCCDF', label: 'FREE TO GET THINGS DONE', title: ['All functionality.', 'Free.'], body: ['Premium is purely cosmetic', 'and entirely optional.'], shot: '01-tasks.png', premium: true },
];
const esc = s => s.replaceAll('&', '&amp;').replaceAll('<', '&lt;');
const data = name => 'data:image/png;base64,' + fs.readFileSync(path.join(root, 'raw', name)).toString('base64');
function text(x,y,s,size,fill,weight=400, extra='') { return `<text x="${x}" y="${y}" font-size="${size}" font-weight="${weight}" fill="${fill}" ${extra}>${esc(s)}</text>`; }
function phone(s,x,y,w) {
    const h = w * 2868/1320;
    return `<rect x="${x-17}" y="${y-17}" width="${w+34}" height="${h+34}" rx="${w*.115}" fill="#10141C" stroke="#FFFFFF" stroke-opacity=".22" stroke-width="4"/>
    <clipPath id="screen"><rect x="${x}" y="${y}" width="${w}" height="${h}" rx="${w*.098}"/></clipPath>
    <image href="${data(s.shot)}" x="${x}" y="${y}" width="${w}" height="${h}" clip-path="url(#screen)"/>`;
}
async function main() {
    const thumbs = [];
    for (const [i,s] of slides.entries()) {
        let svg = `<svg xmlns="http://www.w3.org/2000/svg" width="1320" height="2868" viewBox="0 0 1320 2868"><rect width="1320" height="2868" fill="${s.bg}"/><g font-family="Helvetica Neue, Helvetica, Arial, sans-serif">`;
        svg += `<circle cx="1100" cy="1990" r="790" fill="none" stroke="${s.ink}" stroke-opacity=".07" stroke-width="180"/>`;
        svg += `<rect x="96" y="65" width="104" height="104" rx="25" fill="#FFFFFF"/><svg x="104" y="73" width="88" height="88" viewBox="180 160 680 680"><image href="${data('clarity-logo.png')}" width="1024" height="1024"/></svg>`;
        svg += text(220,137,'clarity',54,s.ink,700);
        svg += text(1208,129,`${String(i+1).padStart(2,'0')} / 06`,30,s.muted,500,'text-anchor="end"');
        svg += text(96,239,s.label,29,s.muted,700,'letter-spacing="3"');
        s.title.forEach((line,j) => svg += text(88,378+j*123,line,112,s.ink,700,'letter-spacing="-4"'));
        s.body.forEach((line,j) => svg += text(96,602+j*56,line,43,s.muted,400));
        if (!s.premium) {
            svg += phone(s,218,818,884);
        } else {
            svg += `<rect x="96" y="720" width="1128" height="110" rx="55" fill="${s.ink}" fill-opacity=".10"/>`;
            svg += text(660,790,'Tasks • Habits • Focus • Statistics',37,s.ink,500,'text-anchor="middle"');
            svg += phone(s,109,963,718);
            svg += `<clipPath id="icon"><rect x="921" y="1062" width="246" height="246" rx="55"/></clipPath><image href="${data('premium-icon.png')}" x="921" y="1062" width="246" height="246" clip-path="url(#icon)"/>`;
            svg += text(1044,1390,'PREMIUM',27,s.muted,700,'text-anchor="middle" letter-spacing="2"');
            for (const [j,line] of ['A little style.','A little support.'].entries()) svg += text(1044,1460+j*50,line,34,s.ink,500,'text-anchor="middle"');
            svg += `<path d="M962 1635 L1018 1691 L1133 1576" fill="none" stroke="#C5F4D9" stroke-width="17" stroke-linecap="round" stroke-linejoin="round"/>`;
            for (const [j,line] of ['Every feature','is available','for free.'].entries()) svg += text(1044,1790+j*52,line,37,s.ink,700,'text-anchor="middle"');
            svg += text(660,2685,'Personalise your icon. Support Clarity.',38,s.muted,400,'text-anchor="middle"');
        }
        svg += `</g></svg>`;
        fs.writeFileSync(path.join(root,'editable',s.name+'.svg'),svg);
        const png = new Resvg(svg,{font:{loadSystemFonts:true}}).render().asPng();
        // RGB PNGs: App Store Connect does not accept alpha channels.
        const out = path.join(root,'upload',s.name+'.png');
        await sharp(png).flatten({background:s.bg}).removeAlpha().png().toFile(out);
        thumbs.push(await sharp(out).resize(330,717).toBuffer());
    }
    await sharp({create:{width:1022,height:1466,channels:3,background:'#F2F0EC'}}).composite(thumbs.map((input,i)=>({input,left:8+(i%3)*338,top:8+Math.floor(i/3)*733}))).png().toFile(path.join(root,'contact-sheet.png'));
    fs.writeFileSync(path.join(root,'copy.json'),JSON.stringify(slides,null,2)+'\n');
}
main().catch(e => { console.error(e); process.exitCode=1; });
