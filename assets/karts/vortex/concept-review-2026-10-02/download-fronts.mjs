import fs from 'node:fs';
const root=new URL('./',import.meta.url);
for(const label of ['A','B']) {
 const file=new URL(label+'-status.json',root);if(!fs.existsSync(file))continue;
 const s=JSON.parse(fs.readFileSync(file)).structuredContent;
 if(s?.status!=='SUCCEEDED')continue;
 const response=await fetch(s.image_urls[0]);if(!response.ok)throw Error('Image download failed');
 fs.writeFileSync(new URL(label+'-front.png',root),Buffer.from(await response.arrayBuffer()));
 console.log(label+' image saved; '+s.consumed_credits+' credits');
}
