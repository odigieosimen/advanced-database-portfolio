from docx import Document
from docx.shared import Inches, Pt, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.section import WD_SECTION
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.enum.style import WD_STYLE_TYPE
from pathlib import Path

ROOT=Path(__file__).parent
OUT=ROOT/'output'
OUT.mkdir(exist_ok=True)
doc=Document()
sec=doc.sections[0]
sec.top_margin=Inches(.54); sec.bottom_margin=Inches(.52); sec.left_margin=Inches(.68); sec.right_margin=Inches(.68)
sec.header_distance=Inches(.25); sec.footer_distance=Inches(.25)
styles=doc.styles
normal=styles['Normal']; normal.font.name='Calibri'; normal.font.size=Pt(9.25); normal.font.color.rgb=RGBColor(35,43,52)
normal.paragraph_format.space_after=Pt(4); normal.paragraph_format.line_spacing=1.02
for name,size in [('Title',21),('Heading 1',12.5),('Heading 2',10)]:
 s=styles[name]; s.font.name='Calibri'; s.font.size=Pt(size); s.font.bold=True; s.font.color.rgb=RGBColor(0,0,0); s.paragraph_format.space_before=Pt(5); s.paragraph_format.space_after=Pt(2); s.paragraph_format.keep_with_next=True
def shade(cell,fill):
 tcPr=cell._tc.get_or_add_tcPr(); shd=OxmlElement('w:shd'); shd.set(qn('w:fill'),fill); tcPr.append(shd)
def set_cell_margins(cell,top=75,start=110,bottom=75,end=110):
 tc=cell._tc; tcPr=tc.get_or_add_tcPr(); mar=OxmlElement('w:tcMar')
 for m,v in [('top',top),('start',start),('bottom',bottom),('end',end)]:
  e=OxmlElement('w:'+m); e.set(qn('w:w'),str(v)); e.set(qn('w:type'),'dxa'); mar.append(e)
 tcPr.append(mar)
def para(text='',boldlead=None):
 p=doc.add_paragraph()
 if boldlead and text.startswith(boldlead):
  p.add_run(boldlead).bold=True; p.add_run(text[len(boldlead):])
 else: p.add_run(text)
 p.paragraph_format.widow_control=True
 return p
def heading(t): doc.add_heading(t,level=1)
def figure(rel,caption,width=3.1):
 p=doc.add_paragraph(); p.alignment=WD_ALIGN_PARAGRAPH.CENTER; p.paragraph_format.space_before=Pt(1); p.paragraph_format.space_after=Pt(0); p.paragraph_format.keep_with_next=True
 p.add_run().add_picture(str(ROOT/rel),width=Inches(width))
 c=doc.add_paragraph(); c.alignment=WD_ALIGN_PARAGRAPH.CENTER; c.paragraph_format.space_after=Pt(3); c.paragraph_format.line_spacing=1
 r=c.add_run(caption); r.italic=True; r.font.size=Pt(8); r.font.color.rgb=RGBColor(75,85,96)
def evidence_row(left,right):
 t=doc.add_table(rows=1,cols=2); t.autofit=False; t.columns[0].width=Inches(3.45); t.columns[1].width=Inches(3.45)
 for cell,(rel,cap) in zip(t.rows[0].cells,[left,right]):
  set_cell_margins(cell,20,30,20,30)
  p=cell.paragraphs[0]; p.alignment=WD_ALIGN_PARAGRAPH.CENTER; p.paragraph_format.space_after=Pt(1); p.paragraph_format.keep_with_next=True
  p.add_run().add_picture(str(ROOT/rel),width=Inches(3.15))
  p2=cell.add_paragraph(); p2.alignment=WD_ALIGN_PARAGRAPH.CENTER; p2.paragraph_format.space_after=Pt(0)
  rr=p2.add_run(cap); rr.italic=True; rr.font.size=Pt(7.5); rr.font.color.rgb=RGBColor(75,85,96)
 for row in t.rows:
  for c in row.cells:
   tcPr=c._tc.get_or_add_tcPr(); borders=OxmlElement('w:tcBorders')
   for edge in ('top','left','bottom','right','insideH','insideV'):
    el=OxmlElement('w:'+edge); el.set(qn('w:val'),'nil'); borders.append(el)
   tcPr.append(borders)

# Header/footer
header=sec.header.paragraphs[0]; header.alignment=WD_ALIGN_PARAGRAPH.RIGHT
r=header.add_run('MIT 8103  |  ADVANCED DATABASE SYSTEMS'); r.font.name='Calibri'; r.font.size=Pt(8); r.font.bold=True; r.font.color.rgb=RGBColor(95,105,115)
footer=sec.footer.paragraphs[0]; footer.alignment=WD_ALIGN_PARAGRAPH.CENTER
r=footer.add_run('Osimen Odigie  •  301826111  •  2026/2027'); r.font.size=Pt(8); r.font.color.rgb=RGBColor(95,105,115)

p=doc.add_paragraph(style='Title'); p.paragraph_format.space_after=Pt(1); p.add_run('Advanced Database Systems Portfolio')
p=doc.add_paragraph(); p.paragraph_format.space_after=Pt(5)
r=p.add_run('Individual practical assessment summary'); r.font.size=Pt(11); r.font.color.rgb=RGBColor(65,75,85)
t=doc.add_table(rows=2,cols=2); t.autofit=False; t.columns[0].width=Inches(3.45); t.columns[1].width=Inches(3.45)
for row,vals in zip(t.rows,[('Student','Osimen Odigie'),('Student ID','301826111')]):
 for c,(label,val) in zip(row.cells,[(vals[0],vals[1]),('Course','MIT 8103 Advanced Database Systems')]):
  c.text=''; set_cell_margins(c,55,95,55,95); shade(c,'EAF0F5')
  pp=c.paragraphs[0]; pp.paragraph_format.space_after=Pt(0); rr=pp.add_run(label+'  '); rr.bold=True; rr.font.size=Pt(8); rr2=pp.add_run(val); rr2.font.size=Pt(8)

heading('Case study and scope')
para('I used a Brazilian online marketplace based on the public Olist e-commerce dataset. Customers place orders for products offered by sellers, make one or more payments, receive deliveries and leave reviews. The database supports order processing, stock changes, customer and seller lookups, sales reporting and order history. My portfolio follows this same case study through relational design, query tuning, transaction control, document modelling and cloud distribution.')

heading('Portfolio 1  Relational design and data quality')
para('I built a MySQL schema with nine related tables for customers, orders, items, payments, reviews, products, sellers, category translations and geolocation. Primary and foreign keys protect relationships, while constraints reject invalid values. I separated order items and payments because combining them in one flat table can multiply rows and overstate totals. The design reaches third normal form for most transactional tables. I documented specific exceptions where the supplied data prevented stricter normalization, including customer postcodes absent from the geolocation table. The loaded database contains about 99,441 orders and 1,000,163 geolocation rows. The ER model and row-count screenshots support the schema and load checks.')
figure('P1-database-design/P1-database-designer-diagram.png','Figure 1. Relational entities and their key relationships in the marketplace model.',5.9)

heading('Portfolio 2  Query processing and optimisation')
para('I tested eight reporting queries with MySQL EXPLAIN ANALYZE and added six indexes chosen for the filters, joins and grouping used by the workload. The clearest example was the one-postcode geolocation query: a covering index reduced the rows examined from one million to 103, with median execution time falling from 1.88 seconds to about 0.17 milliseconds on this machine. Results varied by query. A control query that had no relevant new index did not improve on its first run, although later warm runs were faster. This showed me that caching can look like an indexing gain. I therefore interpreted timings alongside execution plans and marked the machine-specific results as indicative rather than universal.')
figure('P2-query-optimisation/evidence06-indexes-created.png','Figure 2. MySQL output confirming creation of the workload indexes.',5.1)

heading('Portfolio 3  Transactions and concurrency')
para('I added a small stock table to model checkout because stock quantities are not present in the source dataset. With InnoDB, I demonstrated that a failed checkout can roll back its order, item and stock changes together. Two-session tests showed a dirty read under READ UNCOMMITTED, a non-repeatable read under READ COMMITTED and snapshot behaviour under REPEATABLE READ. I also reproduced a lost update: two sessions each sold from a stock value of ten, but the final value became nine instead of eight. SELECT FOR UPDATE and an atomic conditional UPDATE prevented that error. A separate deadlock test showed InnoDB detecting a lock cycle and rolling back one transaction. These exercises made clear that a correct stock decision must be checked and applied as one protected operation.')
figure('P3-transactions-concurrency/Window B Rollback error.png','Figure 3. Session evidence of InnoDB identifying and resolving a deadlock.',5.0)

heading('Portfolio 4  NoSQL document model')
para('I exported the relational data to JSON and loaded it into MongoDB Atlas. Each order document embeds its bounded items, payments, reviews and a customer snapshot, so a common order-history read does not need several joins. Products and sellers remain separate because they are shared by many orders. I queried arrays and used aggregation pipelines for revenue, reviews and seller results. A compound index supported cancelled-order date searches, and schema validation rejected an invalid status. The orders collection contains a 20,000-order sample, while product and seller collections contain all records. This model makes complete order reads convenient, but cross-document integrity and reports spanning many entities remain easier to manage relationally.')
figure('P4-nosql/Orders imported.png','Figure 4. MongoDB Compass evidence of the imported order documents.',5.3)

heading('Portfolio 5  Cloud distribution and design')
para('I deployed the MongoDB document model to an AWS Paris Atlas free cluster and observed a three-member replica set with one primary and two secondaries. In the write-concern runs, writes from Lagos took roughly 185 milliseconds on average. The measured difference between w:1 and majority was too small to separate from run-to-run variation, so these tests do not establish that both guarantees have identical costs in other conditions. At the measured document size, the full order data is estimated at about 80 MB. Sharding is therefore unnecessary for this dataset. If growth later justified it, I recommend a hashed customer unique ID key because it should distribute the observed customer workload while keeping one customer’s order history on one shard. Sharding and failover were not run on the free tier; these remain reasoned design proposals.')
figure('P5-distributed-cloud/C replica set health.png','Figure 5. Atlas replica-set health evidence from the deployed cluster.',5.35)

heading('Technical reflection')
para('The most useful lesson for me was that database choices depend on how the data is read and changed. Normalization reduced repeated facts in MySQL, while embedding selected order data made MongoDB reads simpler. Neither design is automatically best for every task. The transaction exercises were especially useful because the lost update looked harmless in a single session but produced the wrong stock count under concurrency. I also learned to be careful with performance claims: a plan can show fewer rows examined, while elapsed time is still affected by cache state, network distance and the machine. My next improvement would be to run isolated repeated benchmarks and to test the proposed cloud design on a tier that permits failover and sharding.')

heading('Repository, references and AI use')
para('The scripts, analyses, raw plans and supporting screenshots are organized in the project repository: https://github.com/odigieosimen/advanced-database-portfolio . The case study uses the Brazilian E-Commerce Public Dataset by Olist, distributed through Kaggle under CC BY-NC-SA 4.0. Technical references include the MySQL 8.0 Reference Manual, MongoDB Manual and MongoDB Atlas documentation. Tools used in the implementation include MySQL Community Server, MySQL Workbench, MongoDB Compass and MongoDB Atlas.')
para('AI use declaration: OpenAI Codex assisted in organizing evidence and drafting this summary from the assignment brief and portfolio files. I must review the wording, confirm every description against my own work, and be able to explain the scripts, results and design decisions before submission. The implementation evidence and measurements are from the project repository.')

# Avoid em dashes and keep paragraphs connected to headings.
alltext='\n'.join(p.text for p in doc.paragraphs)
assert '\u2014' not in alltext and '\u2013' not in alltext
doc.core_properties.title='Advanced Database Systems Portfolio Summary'
doc.core_properties.author='Osimen Odigie'
doc.core_properties.subject='MIT 8103 Individual Practical Assessment'
doc.save(OUT/'MIT8103_Advanced_Database_Portfolio_Report.docx')

