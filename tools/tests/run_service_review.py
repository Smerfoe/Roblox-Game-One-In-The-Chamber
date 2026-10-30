"""Run real DataService/InventoryService code with the deterministic mocked engine."""
from pathlib import Path
import subprocess,sys,tempfile
ROOT=Path(__file__).resolve().parents[2]
modules={p.stem:p for p in (ROOT/'src/ServerScriptService/Data').glob('*.luau') if p.stem!='DataTests'}
for name,path in {'DataService':'ServerScriptService/Services/DataService.luau','InventoryService':'ServerScriptService/Services/InventoryService.luau','PlayerState':'ReplicatedStorage/Shared/PlayerState.luau','SkinAppearance':'ReplicatedStorage/Shared/SkinAppearance.luau','SkinCatalog':'ReplicatedStorage/Shared/Config/SkinCatalog.luau'}.items():modules[name]=ROOT/'src'/path
bindings='local script = {Parent={Schema="Schema", DataService="DataService", Config={SkinCatalog="SkinCatalog"}}}\n'
baseline = next((arg.split('=',1)[1] for arg in sys.argv if arg.startswith('--baseline=')), None)
factories=[]
for name,p in modules.items():
 source = subprocess.check_output(['git','show','3df8955:'+str(p.relative_to(ROOT))],text=True) if baseline==name else p.read_text()
 factories.append(f'factories.{name}=function()\n{bindings}{source}\nend')
body=(ROOT/'tools/tests/service_review.luau').read_text().replace('-- MODULES_INSERTED_HERE','\n'.join(factories))
with tempfile.TemporaryDirectory(prefix='oitc-service-review-') as d:
 path=Path(d)/'services.luau';path.write_text(body)
 subprocess.run([sys.argv[1] if len(sys.argv)>1 and not sys.argv[1].startswith('--') else '/tmp/oitc-luau/luau',str(path)],check=True)
