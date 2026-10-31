"""Dependency-free, escaped static documentation with client-side full-text search."""
from pathlib import Path
import html, json, re
ROOT=Path(__file__).resolve().parents[1]
source=ROOT/'Documentation'; out=ROOT/'Releases/docs';out.mkdir(parents=True,exist_ok=True)
pages=sorted(source.glob('*.md')); index=[]
def inline(s):
    s=html.escape(s)
    s=re.sub(r'`([^`]+)`',r'<code>\1</code>',s)
    return re.sub(r'\[([^\]]+)\]\(([^)]+)\)',lambda m:'<a href="'+m[2].replace('.md','.html')+'">'+m[1]+'</a>' if not m[2].lower().startswith(('javascript:','data:')) else m[1],s)
def render(text):
    lines=[];code=False
    for line in text.splitlines():
        if line.startswith('```'):
            lines.append('</code></pre>' if code else '<pre><code>');code=not code
        elif code:lines.append(html.escape(line)+'\n')
        elif line.startswith('#'):
            level=min(6,len(line)-len(line.lstrip('#')));title=line[level:].strip();lines.append(f'<h{level} id="{re.sub("[^a-z0-9-]","",title.lower().replace(" ","-"))}">{inline(title)}</h{level}>')
        elif line.startswith('- '):lines.append('<p class="bullet">• '+inline(line[2:])+'</p>')
        elif line:lines.append('<p>'+inline(line)+'</p>')
    if code:lines.append('</code></pre>')
    return '\n'.join(lines)
nav=''.join('<a href="'+p.stem+'.html">'+html.escape(p.stem.replace('-',' ').title())+'</a>' for p in pages)
for p in pages:
    text=p.read_text(encoding='utf-8');title=next((x[2:] for x in text.splitlines()if x.startswith('# ')),p.stem)
    index.append(dict(title=title,url=p.stem+'.html',text=text))
    page='<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>'+html.escape(title)+'</title><style>body{font:17px system-ui;background:#151512;color:#d3cbaa;margin:0}nav{padding:1.5rem;display:flex;flex-wrap:wrap;gap:1rem;border-bottom:1px solid #686144}a{color:#e1ce88}main{max-width:1000px;margin:auto;padding:2rem}pre{overflow:auto;background:#080807;padding:1rem}code{font-size:.9em}input{padding:.6rem;width:90%;background:#222;color:inherit;border:1px solid #777}.bullet{margin-left:1rem}</style><nav>'+nav+'</nav><main><input id="search" placeholder="Search documentation" aria-label="Search documentation"><div id="results"></div>'+render(text)+'</main><script src="search.js"></script></html>'
    (out/(p.stem+'.html')).write_text(page,encoding='utf-8')
(out/'search-index.json').write_text(json.dumps(index),encoding='utf-8')
(out/'search.js').write_text("let docs=[];fetch('search-index.json').then(r=>r.json()).then(x=>docs=x);document.querySelector('#search').addEventListener('input',e=>{let q=e.target.value.toLowerCase(),r=document.querySelector('#results');r.replaceChildren();if(q.length<2)return;for(let d of docs.filter(d=>d.text.toLowerCase().includes(q)).slice(0,20)){let a=document.createElement('a');a.href=d.url;a.textContent=d.title;let p=document.createElement('p');p.append(a);r.append(p)}});",encoding='utf-8')
if(out/'index.html').exists():pass
elif(out/'home.html').exists():(out/'index.html').write_bytes((out/'home.html').read_bytes())
print(f'Built {len(pages)} searchable documentation pages')
