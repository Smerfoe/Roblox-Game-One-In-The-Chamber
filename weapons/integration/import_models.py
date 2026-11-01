"""Convert reviewed native XML models into bounded Studio creation batches."""
from pathlib import Path
import xml.etree.ElementTree as E
import json
root=Path(__file__).parent
allowed={'Model','Part','WedgePart','Motor6D','Attachment','WeldConstraint'}
for path in (root/'models').glob('*.rbxmx'):
    tree=E.parse(path); rows=[]
    def visit(item,parent=None):
        cls=item.attrib['class']; assert cls in allowed,cls
        props=[]
        for p in item.find('Properties'):
            name=p.attrib['name']; kind=p.tag
            if kind in ('Vector3','Color3','CoordinateFrame'): value=[float(x.text) for x in p]
            elif kind=='bool': value=p.text=='true'
            elif kind in ('float','double','int','token'): value=float(p.text)
            elif kind in ('string','Ref'): value=p.text or ''
            else: raise ValueError((kind,name))
            props.append({'name':{'size':'Size','shape':'Shape'}.get(name,name),'kind':kind,'value':value})
        ref=item.attrib['referent'];rows.append({'id':ref,'class':cls,'parent':parent,'properties':props})
        for child in item.findall('Item'):visit(child,ref)
    for item in tree.getroot().findall('Item'):visit(item)
    (root/(path.stem+'.json')).write_text(json.dumps(rows),encoding='utf8')
    ids={row['id']:i+1 for i,row in enumerate(rows)}
    lines=['local a={}']
    refs=[]
    for i,row in enumerate(rows,1):
        lines.append(f'a[{i}]=Instance.new("{row["class"]}")')
        for p in row['properties']:
            value=p['value']; kind=p['kind']; target=f'a[{i}][{json.dumps(p["name"])}]'
            if kind=='Ref':
                if value in ids: refs.append(f'{target}=a[{ids[value]}]')
                continue
            if kind in ('Vector3','Color3','CoordinateFrame'):
                ctor={'Vector3':'Vector3.new','Color3':'Color3.new','CoordinateFrame':'CFrame.new'}[kind]
                expr=ctor+'('+','.join(str(x) for x in value)+')'
            else: expr=json.dumps(value)
            lines.append(target+'='+expr)
        if row['parent']: lines.append(f'a[{i}].Parent=a[{ids[row["parent"]]}]')
        if i%50==0: lines.append('task.wait()')
    lines+=refs
    lines+=['assert(not game.ServerStorage.WeaponExpansionStaging:FindFirstChild(a[1].Name),"Already imported")','a[1].Parent=game.ServerStorage.WeaponExpansionStaging','return {name=a[1].Name,instances=#a}']
    (root/(path.stem+'.import.luau')).write_text('\n'.join(lines),encoding='utf8')
    print(path.stem,len(rows))
