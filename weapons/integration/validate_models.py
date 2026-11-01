from pathlib import Path
import json, math
root=Path(__file__).parent
files=list(root.glob('*_Prototype.json'))
assert len(files)==10
allowed={'Model','Part','WedgePart','Motor6D','Attachment','WeldConstraint'}
report=[]
for file in files:
    rows=json.loads(file.read_text())
    ids={r['id'] for r in rows}
    assert len(ids)==len(rows)
    for row in rows:
        assert row['class'] in allowed
        for prop in row['properties']:
            value=prop['value']
            if isinstance(value,list): assert all(math.isfinite(v) for v in value)
            if prop['name']=='Size': assert all(v>0 for v in value)
            if prop['kind']=='Ref' and value!='null': assert value in ids
    report.append({'model':file.stem,'instances':len(rows),'passed':True})
(root/'validation.json').write_text(json.dumps(report,indent=2))
print('Validated',len(report),'models')
