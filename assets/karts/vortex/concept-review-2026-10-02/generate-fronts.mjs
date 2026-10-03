import fs from 'node:fs';
import {Client} from '/Users/zozo/.codex/tools/meshy/node_modules/@modelcontextprotocol/sdk/dist/esm/client/index.js';
import {StdioClientTransport} from '/Users/zozo/.codex/tools/meshy/node_modules/@modelcontextprotocol/sdk/dist/esm/client/stdio.js';
const root=new URL('./',import.meta.url);
const config=fs.readFileSync('/Users/zozo/.codex/config.toml','utf8');
const section=config.match(/\[mcp_servers\.meshy\.env\]([\s\S]*?)(?=\n\[|$)/)?.[1];
const key=JSON.parse(section.match(/^MESHY_API_KEY\s*=\s*(".*")/m)[1]);
const client=new Client({name:'vortex-concept-pilot',version:'1.0'});
await client.connect(new StdioClientTransport({command:'/opt/homebrew/bin/node',args:['/Users/zozo/.codex/tools/meshy/node_modules/@meshy-ai/meshy-mcp-server/dist/index.js'],env:{...process.env,MESHY_API_KEY:key},stderr:'pipe'}));
const prompts=JSON.parse(fs.readFileSync(new URL('prompts.json',root)));
const tools=await client.listTools();
fs.writeFileSync(new URL('available-tools.json',root),JSON.stringify(tools.tools.map(t=>({name:t.name,inputSchema:t.inputSchema})),null,2));
for (const [label,file] of [['A','IMG_7203.jpeg'],['B','IMG_7202.jpeg']]) {
 const output=new URL(label+'-submission.json',root);
 if(fs.existsSync(output)) {console.log(label+' already submitted; skipped');continue;}
 const args={ai_model:'nano-banana-pro',prompt:prompts[label].front_three_quarter,reference_file_paths:['/Users/zozo/Desktop/'+file],generate_multi_view:false,response_format:'json'};
 const result=await client.callTool({name:'meshy_image_to_image',arguments:args});
 fs.writeFileSync(output,JSON.stringify(result,null,2));
 console.log(label+': '+JSON.stringify(result).replaceAll(key,'[REDACTED]'));
 if(result.isError) break;
}
await client.close();
