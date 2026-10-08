"""Generates Documentation/images/architecture.svg (the diagram embedded in the root README).

Usage:  python3 Documentation/images/generate_architecture.py

Logos are downloaded from Simple Icons (CDN) at run time and embedded as vector paths,
so the resulting SVG is self-contained and renders on GitHub. Needs network access.
Edit the layout section at the bottom to change boxes and arrows.
"""
import re
import urllib.request
from pathlib import Path

OUT = Path(__file__).with_name("architecture.svg")
SOURCES = {
    "tf": "https://cdn.simpleicons.org/terraform",
    "dbt": "https://cdn.jsdelivr.net/npm/simple-icons/icons/dbt.svg",
    "gcp": "https://cdn.simpleicons.org/googlecloud",
    "bq": "https://cdn.simpleicons.org/googlebigquery",
    "gcs": "https://cdn.simpleicons.org/googlecloudstorage",
    "looker": "https://cdn.simpleicons.org/looker",
    "sheets": "https://cdn.simpleicons.org/googlesheets",
}

def icon(url):
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})  # CDN returns 403 to the default Python UA
    svg = urllib.request.urlopen(req, timeout=20).read().decode()
    return " ".join(re.findall(r'<path d="([^"]+)"', svg))

P = {k: icon(u) for k, u in SOURCES.items()}
C={'tf':'#844FBA','dbt':'#FF694B','gcp':'#4285F4','bq':'#669DF6','gcs':'#4285F4','looker':'#4285F4','sheets':'#34A853'}
def logo(k,x,y,size):
    sc=size/24
    return f'<g transform="translate({x},{y}) scale({sc})" fill="{C[k]}"><path d="{P[k]}"/></g>'
def box(x,y,w,h,title,sub,dashed=False,stroke='#CBD5E1'):
    d=' stroke-dasharray="6 5"' if dashed else ''
    return (f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="12" fill="#FFFFFF" stroke="{stroke}" stroke-width="1.6"{d}/>'
            f'<text x="{x+w/2}" y="{y+h-34}" text-anchor="middle" class="t">{title}</text>'
            f'<text x="{x+w/2}" y="{y+h-16}" text-anchor="middle" class="s">{sub}</text>')
def table_icon(x,y,col='#669DF6'):
    return (f'<g transform="translate({x},{y})" fill="none" stroke="{col}" stroke-width="2.2"><rect x="0" y="0" width="34" height="28" rx="3"/>'
            '<path d="M0 9.5H34M0 19H34M11.5 0V28"/></g>')
def view_icon(x,y,col='#669DF6'):
    return (f'<g transform="translate({x},{y})" fill="none" stroke="{col}" stroke-width="2.2"><path d="M0 14C6 4 28 4 34 14C28 24 6 24 0 14Z"/>'
            f'<circle cx="17" cy="14" r="5" fill="{col}"/></g>')
def csv_icon(x,y):
    return (f'<g transform="translate({x},{y})"><path d="M0 3a3 3 0 0 1 3-3h16l9 9v22a3 3 0 0 1-3 3H3a3 3 0 0 1-3-3z" fill="#E2E8F0" stroke="#94A3B8" stroke-width="1.6"/>'
            '<path d="M19 0v9h9" fill="none" stroke="#94A3B8" stroke-width="1.6"/><text x="14" y="26" text-anchor="middle" font-size="9" font-weight="700" fill="#475569" font-family="Helvetica,Arial,sans-serif">CSV</text></g>')
def bars_icon(x,y,col='#94A3B8'):
    return (f'<g transform="translate({x},{y})" fill="{col}"><rect x="0" y="14" width="8" height="14" rx="1.5"/><rect x="13" y="6" width="8" height="22" rx="1.5"/><rect x="26" y="0" width="8" height="28" rx="1.5"/></g>')
def star_icon(x,y,col='#669DF6'):
    # star schema: central fact square with four dimension squares
    return (f'<g transform="translate({x},{y})" fill="none" stroke="{col}" stroke-width="2"><rect x="12" y="9" width="10" height="10" rx="1.5" fill="{col}"/>'
            '<rect x="12" y="-1" width="10" height="6" rx="1"/><rect x="12" y="23" width="10" height="6" rx="1"/>'
            '<rect x="-2" y="11" width="8" height="6" rx="1"/><rect x="28" y="11" width="8" height="6" rx="1"/>'
            '<path d="M17 5V9M17 19V23M6 14H12M22 14H28"/></g>')
def hex_icon(x,y,col='#FF694B'):
    # semantic layer: a cube with a metric bar chart inside
    return (f'<g transform="translate({x},{y})" fill="none" stroke="{col}" stroke-width="2"><path d="M17 0L33 8V24L17 32L1 24V8Z"/>'
            f'<path d="M17 16V32M17 16L33 8M17 16L1 8"/></g>')
def terminal_icon(x,y,col='#334155'):
    return (f'<g transform="translate({x},{y})" fill="none" stroke="{col}" stroke-width="2.2"><rect x="0" y="0" width="34" height="28" rx="4"/>'
            '<path d="M7 9L14 14L7 19M18 20H27" stroke-linecap="round" stroke-linejoin="round"/></g>')
def api_icon(x,y,col='#334155'):
    return (f'<g transform="translate({x},{y})" fill="none" stroke="{col}" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round">'
            '<path d="M10 2C5 2 7 14 2 14C7 14 5 26 10 26M24 2C29 2 27 14 32 14C27 14 29 26 24 26"/>'
            f'<circle cx="17" cy="14" r="1.6" fill="{col}"/></g>')
def arrow(d,color='#475569',dashed=False,label=None,lx=0,ly=0):
    da=' stroke-dasharray="6 5"' if dashed else ''
    s=f'<path d="{d}" fill="none" stroke="{color}" stroke-width="2"{da} marker-end="url(#a{"d" if dashed else ""})"/>'
    if label: s+=f'<text x="{lx}" y="{ly}" text-anchor="middle" class="l">{label}</text>'
    return s

W,H=1930,700
o=[]
o.append(f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" width="{W}" height="{H}" role="img" aria-label="Architecture diagram">')
o.append('''<defs>
<marker id="a" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="8" markerHeight="8" orient="auto-start-reverse"><path d="M0 0L10 5L0 10z" fill="#475569"/></marker>
<marker id="ad" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="8" markerHeight="8" orient="auto-start-reverse"><path d="M0 0L10 5L0 10z" fill="#94A3B8"/></marker>
<style>
text{font-family:Inter,"Helvetica Neue",Helvetica,Arial,sans-serif}
.t{font-size:15px;font-weight:600;fill:#0F172A}
.s{font-size:12px;fill:#64748B}
.h{font-size:16px;font-weight:700;fill:#0F172A}
.l{font-size:12px;fill:#475569;font-style:italic}
.title{font-size:20px;font-weight:700;fill:#0F172A}
</style></defs>''')
o.append(f'<rect width="{W}" height="{H}" rx="16" fill="#F8FAFC"/>')
o.append('<text x="30" y="40" class="title">Current architecture</text>')
# containers: GCP project > BigQuery
o.append('<rect x="215" y="70" width="1100" height="400" rx="16" fill="#EEF4FF" stroke="#4285F4" stroke-width="1.8"/>')
o.append(logo('gcp',233,84,34)); o.append('<text x="277" y="107" class="h">Google Cloud project: felix-technical-test</text>')
o.append('<rect x="430" y="130" width="860" height="320" rx="14" fill="#FFFFFF" stroke="#669DF6" stroke-width="1.6"/>')
o.append(logo('bq',448,142,30)); o.append('<text x="488" y="164" class="h">BigQuery</text>')
# left side: IaC and landing
o.append(box(30,250,150,110,'Raw CSV files','3 files, not versioned'))
o.append(csv_icon(88,268))
o.append(box(235,250,160,110,'Cloud Storage','landing_bucket_felix_test',stroke='#4285F4'))
o.append(logo('gcs',298,266,32))
o.append(box(30,90,150,110,'Terraform','IAC_google/',stroke='#844FBA'))
o.append(logo('tf',87,104,36))
# BigQuery layers
BY=250
o.append(box(450,BY,140,110,'External tables','felix_dataset (raw)',stroke='#669DF6'))
o.append(table_icon(503,BY+22))
o.append(box(620,BY,140,110,'Staging','stg_* views (3)',stroke='#669DF6'))
o.append(view_icon(673,BY+22))
o.append(box(790,BY,140,110,'Transformations','trf_* tables (3)',stroke='#669DF6'))
o.append(table_icon(843,BY+22,'#2563EB'))
o.append(box(960,BY,140,110,'Dims &amp; Facts','7 dims, 3 facts',stroke='#669DF6'))
o.append(star_icon(1013,BY+22))
o.append(box(1130,BY,140,110,'Marts','mart_* tables (7)',stroke='#669DF6'))
o.append(bars_icon(1183,BY+22,'#2563EB'))
# BI consumer
o.append(box(1345,BY,170,110,'Semantic layer','MetricFlow, 53 metrics',stroke='#FF694B'))
o.append(hex_icon(1413,BY+20))
# consumers of the semantic layer (x=1700)
CX,CW,CH=1700,190,100
def consumer(i,title,sub,dashed=True,stroke='#94A3B8'):
    return box(CX,80+i*115,CW,CH,title,sub,dashed=dashed,stroke=stroke)
o.append(consumer(0,'Looker','marts + dbt Cloud metrics',stroke='#4285F4'))
o.append(logo('looker',CX+CW/2-18,80+14,36))
o.append(consumer(1,'Google Sheets','dbt Cloud connector',stroke='#34A853'))
o.append(logo('sheets',CX+CW/2-18,195+14,36))
o.append(consumer(2,'BI tools','Tableau, Power BI, Hex'))
o.append(bars_icon(CX+CW/2-17,310+18))
o.append(consumer(3,'MetricFlow CLI','mf query, works today',dashed=False,stroke='#334155'))
o.append(terminal_icon(CX+CW/2-17,425+18))
o.append(consumer(4,'JDBC / GraphQL API','dbt Cloud Semantic Layer API'))
o.append(api_icon(CX+CW/2-17,540+18))
# dbt
o.append(box(640,490,620,95,'dbt','DBT/ - build and test: staging, transformations, dims, facts, marts, semantic',stroke='#FF694B'))
o.append(logo('dbt',934,500,32))
# data flow
o.append(arrow('M180 305H235',label='upload',lx=207,ly=294))
o.append(arrow('M395 305H450',label='external',lx=422,ly=294))
for a,b in [(590,620),(760,790),(930,960),(1100,1130)]:
    o.append(arrow(f'M{a} 305H{b}'))
# semantic layer reads facts and dims (not the marts)
o.append(arrow('M1075 360V412H1400V360',label='SQL on facts/dims',lx=1137,ly=404))
# semantic layer -> consumers
o.append('<path d="M1515 305H1610" fill="none" stroke="#475569" stroke-width="2"/>')
for i,yc in enumerate((130,245,360,475,590)):
    solid = i==3
    o.append(arrow(f'M1610 305V{yc}H1700',dashed=not solid,color='#475569' if solid else '#94A3B8'))
# Looker also reads the marts directly
o.append(arrow('M1245 250V100H1700',label='SQL on marts',lx=1470,ly=92))
# provisioning / build
o.append(arrow('M180 145H215',dashed=True,color='#94A3B8'))
for x in (690,860,1030,1200):
    o.append(arrow(f'M{x} 490V360',dashed=True,color='#94A3B8'))
o.append(arrow('M1260 537H1470V360',dashed=True,color='#94A3B8'))
o.append('<text x="30" y="660" class="s">Solid arrows: data flow. Dashed arrows: provisioning / build, or access that needs dbt Cloud. Dashed boxes: consumers outside this repo.</text>')
o.append('<text x="30" y="680" class="s">The semantic layer is queried today with the open-source MetricFlow CLI; the other consumers need the layer published through dbt Cloud.</text>')
o.append('</svg>')
OUT.write_text('\n'.join(o))
