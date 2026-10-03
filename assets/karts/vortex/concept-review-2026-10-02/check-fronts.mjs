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
for(const label of ['A','B']) {
 const sub=JSON.parse(fs.readFileSync(new URL(label+'-submission.json',root)));
 const id=sub.structuredContent.task_id;
 const result=await client.callTool({name:'meshy_get_task_status',arguments:{task_id:id,task_type:'image-to-image',wait:true,timeout_seconds:50,response_format:'json'}});
 fs.writeFileSync(new URL(label+'-status.json',root),JSON.stringify(result,null,2));
 console.log(label+': '+JSON.stringify(result).replaceAll(key,'[REDACTED]'));
}
await client.close();
