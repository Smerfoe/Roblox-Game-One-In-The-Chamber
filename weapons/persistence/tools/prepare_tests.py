"""Copy existing save modules for the official CLI; rewrite imports, not logic.

MemoryStore's task.wait is replaced by an injectable scheduler hook because the
standalone CLI has no Roblox task scheduler. No Studio/game files are modified.
"""
from pathlib import Path
import re, hashlib, json
root=Path(__file__).resolve().parents[1]
workspace=root.parents[1]
out=root/'tests'/'generated'
out.mkdir(parents=True,exist_ok=True)
manifest=[]
for name in ('ProfileStore','MemoryStore','DataConfig','DataTests'):
    source=workspace/'ServerScriptService'/'Data'/(name+'.luau')
    text=source.read_text(encoding='utf8')
    text=re.sub(r'require\(script.Parent\.(\w+)\)',r'require("./\1")',text)
    if name=='MemoryStore':
        text=text.replace('task.wait() -- real calls always yield','if self.onWait then self.onWait() end -- injected CLI scheduling hook')
    (out/(name+'.luau')).write_text(text,encoding='utf8')
    manifest.append({'source':str(source.relative_to(workspace)),'sha256':hashlib.sha256(source.read_bytes()).hexdigest()})
(out/'Schema.luau').write_text((root/'Schema.luau').read_text(encoding='utf8'),encoding='utf8')
(out/'sources.json').write_text(json.dumps(manifest,indent=2))
print('Prepared existing persistence tests with candidate schema; original files untouched')
