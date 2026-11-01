"""Download a pinned official Luau CLI for offline tests; no Studio changes."""
from pathlib import Path
import urllib.request, json, hashlib, io, zipfile
root=Path(__file__).resolve().parent/'luau-0.745'
url='https://api.github.com/repos/luau-lang/luau/releases/tags/0.745'
request=urllib.request.Request(url,headers={'User-Agent':'OITC-local-tests'})
release=json.load(urllib.request.urlopen(request,timeout=30))
asset=next(a for a in release['assets'] if a['name']=='luau-windows.zip')
data=urllib.request.urlopen(asset['browser_download_url'],timeout=60).read()
digest='sha256:'+hashlib.sha256(data).hexdigest()
if asset.get('digest'): assert digest==asset['digest'], 'release digest mismatch'
root.mkdir(parents=True,exist_ok=True)
with zipfile.ZipFile(io.BytesIO(data)) as archive:
    for info in archive.infolist():
        if info.filename in {'luau.exe','luau-analyze.exe','luau-compile.exe'}:
            (root/info.filename).write_bytes(archive.read(info))
(root/'SOURCE.json').write_text(json.dumps({'release':release['html_url'],'asset':asset['browser_download_url'],'digest':digest},indent=2))
assert (root/'luau.exe').exists()
print('Verified pinned Luau 0.745:',digest)
