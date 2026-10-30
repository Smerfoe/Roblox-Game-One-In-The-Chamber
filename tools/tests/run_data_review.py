"""Bundle Roblox modules for the official Luau CLI; no text translation of Luau.
Mocks engine services for deterministic regression tests, NOT a Studio test.
"""
from pathlib import Path
import subprocess,sys,tempfile
ROOT=Path(__file__).resolve().parents[2]
modules={p.stem:p for p in (ROOT/'src/ServerScriptService/Data').glob('*.luau')}
header='''local task = { wait = function() end }
local factories, loaded = {}, {}
local require
require = function(name)
 if loaded[name] == nil then loaded[name] = factories[name]() end
 return loaded[name]
end
'''
body=header
for name,p in modules.items():
 source = subprocess.check_output(['git','show','3df8955:'+str(p.relative_to(ROOT))],text=True) if '--baseline' in sys.argv and name=='ProfileStore' else p.read_text()
 body+=f'factories.{name} = function()\nlocal script = {{Parent = {{Schema="Schema", ProfileStore="ProfileStore", MemoryStore="MemoryStore", DataConfig="DataConfig"}}}}\n{source}\nend\n'
body+='local report, ok = require("DataTests").Run()\nprint(report)\nassert(ok, "data regression failures")\n'
with tempfile.TemporaryDirectory(prefix='oitc-review-') as d:
 path=Path(d)/'data.luau';path.write_text(body)
 subprocess.run([sys.argv[1] if len(sys.argv)>1 and not sys.argv[1].startswith('--') else '/tmp/oitc-luau/luau',str(path)],check=True)
