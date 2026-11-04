"""Builds and executes the two analysis notebooks. Run from the project root."""
import nbformat as nbf, sys
from nbclient import NotebookClient
def nb(cells,path):
    n=nbf.v4.new_notebook(); n.cells=[nbf.v4.new_markdown_cell(c[3:]) if c.startswith('MD:') else nbf.v4.new_code_cell(c) for c in cells]
    n.metadata.kernelspec={'name':'python3','display_name':'Python 3','language':'python'}
    NotebookClient(n,timeout=400,kernel_name='python3').execute(cwd='notebooks'); nbf.write(n,path)

setup='''import warnings; warnings.filterwarnings('ignore')
import json, os
import numpy as np, pandas as pd, psycopg2, matplotlib.pyplot as plt
import statsmodels.formula.api as smf
from statsmodels.stats.proportion import proportion_confint, proportions_ztest
from scipy import stats
pd.set_option('display.width',140)
plt.rcParams.update({'figure.dpi':130,'axes.spines.top':False,'axes.spines.right':False,'axes.grid':True,'axes.axisbelow':True,'grid.color':'#e6e6e3','font.size':10})
INK,ACC,MUTE='#2b2b2b','#20808D','#9a9a94'
os.makedirs('../outputs/charts',exist_ok=True)
def save_metrics(key,val):
    p='../outputs/metrics.json'; m=json.load(open(p)) if os.path.exists(p) else {}
    m[key]=val; json.dump(m,open(p,'w'),indent=2,default=float)
'''
late=[ 'MD:# Does late delivery lower repeat purchase and reviews?\n\n**Question.** Olist customers rarely return. Is late delivery a material cause?\n\n**Design.** One row per customer, using their first order. Follow-up starts at delivery, since that is when a customer experiences lateness. A customer enters the repeat analysis only if a full 180 days of data exists after delivery, so recent buyers are not miscounted as lost. Review score is not used as a control because it sits between lateness and repeat purchase.\n\n**Reading the result.** This is observational. It estimates an association after controls, not a proven causal effect. Eligibility depends on delivery date, so the study under-represents late orders from early 2018 (see README).',
setup,
'''con=psycopg2.connect(dbname='olist')
d=pd.read_sql("select * from analytics.delivery_cohort",con)
print('Delivered first orders:',len(d)); print('With full 180 days:',int(d.eligible_180d.sum()))
print('Reordered before first delivery (excluded):',int((d.eligible_180d&d.reordered_before_delivery).sum()))
s=d[d.eligible_180d & ~d.reordered_before_delivery & d.installments.notna()].copy()
s['y']=s.repeat_180d.astype(int); s['late']=s.is_late.astype(int)
top=s.category.value_counts().index[:15]; s['cat']=s.category.where(s.category.isin(top),'other')
s['log_gmv']=np.log(s.gmv); s['log_freight']=np.log1p(s.freight); s['same_state']=(s.customer_state==s.seller_state).astype(int)
s['month']=s.purchase_month.astype(str); s['state']=s.customer_state; s['pay']=s.payment_type.fillna('other')
print('Analysis sample:',len(s))''',
'MD:## 1. Raw comparison',
'''rows=[]
for g,x in s.groupby('late'):
    lo,hi=proportion_confint(x.y.sum(),len(x),method='wilson'); rows.append(dict(group='Late' if g else 'On time',customers=len(x),repeaters=x.y.sum(),repeat_pct=100*x.y.mean(),ci_low=100*lo,ci_high=100*hi))
raw=pd.DataFrame(rows); display(raw)
tab=[[s[s.late==1].y.sum(),(s.late==1).sum()-s[s.late==1].y.sum()],[s[s.late==0].y.sum(),(s.late==0).sum()-s[s.late==0].y.sum()]]
fisher=stats.fisher_exact(tab)[1]; print('Fisher exact p =',round(fisher,4))
p0=s[s.late==0].y.mean(); n1=(s.late==1).sum(); n0=(s.late==0).sum()
se=np.sqrt(p0*(1-p0)*(1/n1+1/n0)); mde=2.8*se; print(f'Smallest gap detectable with 80% power: {100*mde:.2f} points')''',
'MD:## 2. Adjusted estimates\n\nFour specifications test the same question. Standard errors cluster by seller, since orders from one seller share operations.\n\n- **A. Linear probability model** with category, state, month, payment and order controls\n- **B. Logit average marginal effect** with coarser controls so the model converges on a rare outcome\n- **C. Near-promise comparison**, within 3 days of the promised date, where late and on-time orders are most alike. It controls for days from the promise date, so it is noisy\n- **D. Seller fixed effects**, comparing orders within the same seller',
'''ctrl='log_gmv + log_freight + n_items + promised_days + same_state + installments + C(cat) + C(state) + C(month) + C(pay)'
cl=lambda df:{'groups':df.seller_id.astype('category').cat.codes}
res=[]
def add(name,est,lo,hi,p,n): res.append(dict(model=name,estimate_pts=100*est,ci_low=100*lo,ci_high=100*hi,p_value=p,n=n))
m=smf.ols('y ~ late + '+ctrl,s).fit(cov_type='cluster',cov_kwds=cl(s)); ci=m.conf_int().loc['late']; add('A. Linear, full controls',m.params['late'],ci[0],ci[1],m.pvalues['late'],len(s))
region={'SP':'SE','RJ':'SE','MG':'SE','ES':'SE','PR':'S','SC':'S','RS':'S','DF':'CW','GO':'CW','MT':'CW','MS':'CW'}
s['region']=s.state.map(region).fillna('N_NE'); s['qtr']=pd.PeriodIndex(pd.to_datetime(s.purchase_month),freq='Q').astype(str)
s['cat8']=s.category.where(s.category.isin(s.category.value_counts().index[:8]),'other')
lg=smf.logit('y ~ late + log_gmv + log_freight + n_items + promised_days + same_state + C(cat8) + C(region) + C(qtr)',s).fit(disp=0,maxiter=500,method='lbfgs',cov_type='cluster',cov_kwds=cl(s))
print('Logit converged:',lg.mle_retvals.get('converged'))
a=lg.get_margeff().summary_frame().loc['late']; add('B. Logit marginal effect',a.iloc[0],a.iloc[4],a.iloc[5],a.iloc[3],len(s))
n=s[s.days_late.between(-3,3)].copy()
m=smf.ols('y ~ late + days_late + log_gmv + log_freight + n_items + promised_days + same_state + C(region) + C(qtr)',n).fit(cov_type='cluster',cov_kwds=cl(n)); ci=m.conf_int().loc['late']; add('C. Near promise date (+/-3 days)',m.params['late'],ci[0],ci[1],m.pvalues['late'],len(n))
import patsy
y,X=patsy.dmatrices('y ~ late + log_gmv + log_freight + n_items + promised_days + same_state + installments + C(cat) + C(state) + C(month) + C(pay)',s,return_type='dataframe')
X=X.drop(columns='Intercept'); g=s.seller_id.values
dy=y-y.groupby(g).transform('mean'); dX=X-X.groupby(g).transform('mean')
import statsmodels.api as sm
keep=dX.columns[dX.std()>0]; m=sm.OLS(dy,dX[keep]).fit(cov_type='cluster',cov_kwds=cl(s)); ci=m.conf_int().loc['late']; add('D. Seller fixed effects',m.params['late'],ci[0],ci[1],m.pvalues['late'],len(s))
models=pd.DataFrame(res); display(models.round(3))
models.to_csv('../outputs/tables/late_repeat_models.csv',index=False)''',
'''fig,ax=plt.subplots(figsize=(7.2,2.8)); yy=range(len(models))[::-1]
ax.errorbar(models.estimate_pts,yy,xerr=[models.estimate_pts-models.ci_low,models.ci_high-models.estimate_pts],fmt='o',color=ACC,capsize=3)
ax.axvline(0,color=INK,lw=1); ax.set_yticks(list(yy)); ax.set_yticklabels(models.model); ax.set_xlabel('Change in 180-day repeat rate, percentage points (95% CI)')
ax.set_title('Every interval includes zero',loc='left',fontsize=11); plt.tight_layout(); plt.savefig('../outputs/charts/late_repeat_models.png'); plt.show()''',
'MD:## 3. Is on-time, 5-star service enough?\n\nIf repeat stays near 2% for the best experiences, delivery cannot be the main retention constraint.',
'''exp=s.dropna(subset=['review_score']).copy()
exp['group']=np.select([(exp.late==0)&(exp.review_score==5),(exp.late==0)&(exp.review_score<=2),(exp.late==1)],['On time, 5 stars','On time, 1-2 stars','Late, any score'],'Other')
t=exp[exp.group!='Other'].groupby('group').y.agg(customers='size',repeaters='sum',repeat_pct=lambda v:100*v.mean()).reset_index(); display(t.round(2))
t.to_csv('../outputs/tables/repeat_by_experience.csv',index=False)
sc=exp.groupby('review_score').y.agg(customers='size',repeaters='sum',repeat_pct=lambda v:100*v.mean()).round(2); display(sc)
sc.to_csv('../outputs/tables/repeat_by_review.csv')
s365=d[d.eligible_365d & ~d.reordered_before_delivery]
t365=s365.groupby('is_late').repeat_365d.agg(['size','sum','mean']); display(t365)
print('Fisher p, 365d:',round(stats.fisher_exact([[t365.loc[True,'sum'],t365.loc[True,'size']-t365.loc[True,'sum']],[t365.loc[False,'sum'],t365.loc[False,'size']-t365.loc[False,'sum']]])[1],3))''',
'MD:## 4. Late delivery and reviews\n\nThis uses all delivered orders with a review in the analysis window. Unlike repeat purchase, reviews differ sharply. Review surveys can arrive before a delayed parcel does, so a late order may be reviewed while it is still missing. That is a real part of the customer experience, so those reviews stay in.',
'''o=pd.read_sql("""select * from analytics.orders where delivered_at is not null and purchase_month between '2017-01-01' and '2018-08-01' and review_score is not null and installments is not null and order_status='delivered'""",con)
o['late']=o.is_late.astype(int); o['low']=(o.review_score<=2).astype(int)
o['cat']=o.category.where(o.category.isin(o.category.value_counts().index[:15]),'other'); o['log_gmv']=np.log(o.gmv); o['log_freight']=np.log1p(o.freight); o['same_state']=(o.customer_state==o.seller_state).astype(int)
o['month']=o.purchase_month.astype(str); o['state']=o.customer_state; o['pay']=o.payment_type.fillna('other')
print(o.groupby('late').agg(orders=('late','size'),avg_review=('review_score','mean'),low_pct=('low',lambda v:100*v.mean())).round(2))
ctrl2='late + log_gmv + log_freight + n_items + promised_days + same_state + C(cat) + C(state) + C(month) + C(pay)'
rs=smf.ols('review_score ~ '+ctrl2,o).fit(cov_type='cluster',cov_kwds=cl(o)); rl=smf.ols('low ~ '+ctrl2,o).fit(cov_type='cluster',cov_kwds=cl(o))
print('Adjusted review effect:',round(rs.params['late'],3),rs.conf_int().loc['late'].round(3).values)
print('Adjusted low-review effect, pts:',round(100*rl.params['late'],1),(100*rl.conf_int().loc['late']).round(1).values)
save_metrics('reviews',dict(n=len(o),late_review=o[o.late==1].review_score.mean(),ontime_review=o[o.late==0].review_score.mean(),late_low=100*o[o.late==1].low.mean(),ontime_low=100*o[o.late==0].low.mean(),adj_review=rs.params['late'],adj_review_lo=rs.conf_int().loc['late',0],adj_review_hi=rs.conf_int().loc['late',1],adj_low=100*rl.params['late'],adj_low_lo=100*rl.conf_int().loc['late',0],adj_low_hi=100*rl.conf_int().loc['late',1],late_share_low=100*o[o.low==1].late.mean(),late_share_orders=100*o.late.mean()))
save_metrics('repeat',dict(n=len(s),late_n=int(s.late.sum()),ontime_rate=100*s[s.late==0].y.mean(),late_rate=100*s[s.late==1].y.mean(),fisher_p=fisher,mde_pts=100*mde,adj=res[0]['estimate_pts'],adj_lo=res[0]['ci_low'],adj_hi=res[0]['ci_high'],share_late=100*s.late.mean()))
print(dict(late_share_of_low=100*o[o.low==1].late.mean()))''',
'MD:## Conclusion\n\nSee the numbers above and `README.md`. Late orders score far lower on reviews, even after controls. Their link to repeat purchase is not statistically distinguishable from zero, but the study cannot rule out a meaningful effect on late customers themselves. Repeat stays near 2% even after on-time, 5-star orders, so delivery does not appear to be the main retention constraint in this data.']
ab=['MD:# A/B test: does moving the first gate from level 30 to 40 change retention?\n\n**Data.** Cookie Cats mobile game experiment, 90,189 players randomised to `gate_30` (control) or `gate_40`. This module is independent of Olist. It exists to show experiment analysis, because Olist has no experiment data.\n\n**Plan.** Two primary outcomes, day-1 and day-7 retention, so significance is judged at alpha = 0.025 (Bonferroni).',
setup,
'''d=pd.read_csv('../data/raw/cookie_cats.csv')
print(d.shape,'| nulls',d.isna().sum().sum(),'| duplicate users',d.userid.duplicated().sum())
g=d.groupby('version').agg(players=('userid','size'),d1_pct=('retention_1',lambda v:100*v.mean()),d7_pct=('retention_7',lambda v:100*v.mean()),median_rounds=('sum_gamerounds','median'),zero_rounds_pct=('sum_gamerounds',lambda v:100*(v==0).mean()),max_rounds=('sum_gamerounds','max')); display(g.round(2))
g.to_csv('../outputs/tables/ab_summary.csv')''',
'MD:## 1. Sample ratio check\n\nThis test assumes a 50/50 design, which the public data does not document. A 50/50 experiment should split close to 50/50. A failed check can signal a broken assignment or logging process, and it should be raised before any result is trusted.',
'''n30=(d.version=='gate_30').sum(); srm=stats.chisquare([n30,len(d)-n30]).pvalue
print(f'gate_30 share: {100*n30/len(d):.2f}%  |  chi-square p = {srm:.4f}')
print('FLAG: below the usual 0.01 alarm threshold' if srm<.01 else 'OK')''',
'MD:If the design was 50/50, the split is off by under 1% and still fails the usual p < 0.01 alarm. The public data has no assignment logs, so the cause cannot be traced. The results below are reported with that warning attached, and a real team would investigate before shipping.\n\n## 2. Outliers\n\nOne player logged 49,854 rounds, nearly 17 times the next highest. Retention is a yes/no outcome, so this cannot distort the main results. It would distort any mean-rounds comparison, so that comparison uses medians and a rank test.',
'''rng=np.random.default_rng(42); out=[]; B=20000
for metric,label in [('retention_1','Day 1'),('retention_7','Day 7')]:
    a=d[d.version=='gate_40'][metric]; b=d[d.version=='gate_30'][metric]
    z,p=proportions_ztest([a.sum(),b.sum()],[len(a),len(b)])
    diff=a.mean()-b.mean(); boot=rng.binomial(len(a),a.mean(),B)/len(a)-rng.binomial(len(b),b.mean(),B)/len(b)
    out.append(dict(metric=label,gate_30_pct=100*b.mean(),gate_40_pct=100*a.mean(),diff_pts=100*diff,ci_low=100*np.percentile(boot,1.25),ci_high=100*np.percentile(boot,98.75),z=z,p_value=p,sig_at_0025=p<.025,prob_gate40_worse=(boot<0).mean()))
ab=pd.DataFrame(out); display(ab.round(4)); ab.to_csv('../outputs/tables/ab_results.csv',index=False)
print('Rounds, Mann-Whitney p:',round(stats.mannwhitneyu(d[d.version=='gate_30'].sum_gamerounds,d[d.version=='gate_40'].sum_gamerounds).pvalue,4))
save_metrics('ab',dict(srm_p=srm,gate30_share=100*n30/len(d),results=ab.to_dict('records')))''',
'MD:Intervals are 97.5%, matching the corrected alpha. Because the outcome is binary, resampling a group is equivalent to a binomial draw, which makes 20,000 replications instant.\n\n## 3. Power',
'''from statsmodels.stats.power import NormalIndPower
from statsmodels.stats.proportion import proportion_effectsize as es
pw=NormalIndPower()
for lab,base in [('Day 1',.4482),('Day 7',.1902)]:
    h=es(base,base-.005); print(lab,'n per group for a 0.5-point drop at 80% power, alpha .025:',int(pw.solve_power(h,power=.8,alpha=.025)))
    print('   Achieved power for that drop with ~45,000 per group:',round(pw.power(h,45000,.025),2))''',
'''fig,ax=plt.subplots(figsize=(6.6,2.1)); y=[1,0]
ax.errorbar(ab.diff_pts,y,xerr=[ab.diff_pts-ab.ci_low,ab.ci_high-ab.diff_pts],fmt='o',color=ACC,capsize=3); ax.axvline(0,color=INK,lw=1)
ax.set_yticks(y); ax.set_yticklabels(ab.metric); ax.set_ylim(-.6,1.6); ax.set_xlabel('gate_40 minus gate_30, percentage points (97.5% CI)')
ax.set_title('Day-7 retention is lower with the later gate',loc='left',fontsize=11); plt.tight_layout(); plt.savefig('../outputs/charts/ab_result.png'); plt.show()''',
'MD:## Decision\n\nKeep the gate at level 30. Day-7 retention is significantly lower at level 40 after correction. Day-1 retention is not significantly different, even before correction. Most players stop before level 30, which dilutes the measured effect, and filtering to players who reached the gate would bias the comparison because reaching it happens after assignment. The sample ratio warning should be investigated before treating the size of the effect as final.']
nb(late,'notebooks/01_late_delivery_impact.ipynb'); nb(ab,'notebooks/02_ab_test_cookie_cats.ipynb')
