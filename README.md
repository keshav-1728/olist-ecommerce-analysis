# Olist E-Commerce: Growth Diagnostic
### SQL + Python + RFM Segmentation | 99,441 orders | 8 relational tables | 2016 to 2018

---

## What This Project Is About

Olist is a real Brazilian e-commerce marketplace that connects small
businesses to major retail channels. They published their transaction
data publicly on Kaggle, covering roughly 100,000 orders placed between
2016 and 2018.

The dataset is not a clean tutorial CSV. It is 8 relational tables that
need to be joined correctly before any analysis is possible. That is
what makes it interesting. Most student projects work on flat files.
This one requires understanding a real data model, handling data quality
issues, and building a master table before a single business question
can be answered.

The business question I set out to answer was straightforward: the
company has strong order volumes, so why is revenue not compounding?
What is holding growth back?

---

## The Short Answer

97% of customers never come back after their first purchase.

Out of 93,358 unique customers, 90,557 placed exactly one order and
never returned. That 3% repeat rate is the root of everything else in
this analysis. A business that cannot retain customers has to spend
more and more on acquisition just to stay flat. There is no compounding.

The data also shows what is driving it.

---

## Key Findings

| Finding | Number | What It Means |
|---------|--------|---------------|
| Customer repeat rate | 3.0% | 97 out of 100 customers never return |
| Avg review score, late delivery (3+ days) | 1.85 / 5 | Late = near-certain customer loss |
| Avg review score, early delivery | 4.22 / 5 | 2.37-point gap on a 5-point scale |
| At Risk RFM segment | 22,230 customers | R$3.7M in revenue showing disengagement |
| Revenue through bottom 10% sellers | R$476K | 307 sellers producing poor experiences |
| Installment buyers vs one-shot buyers | R$195 vs R$96 avg order | 2x spend difference |
| RJ satisfaction score vs SP | 3.87 vs 4.18 | Second biggest market, lowest satisfaction |

---

## The Data Model

This is what separates this project from a standard flat-file analysis.
Eight tables, all joined through a central orders table.

```
orders
  +-- customers       (via customer_id)
  +-- order_items     (via order_id)
  +-- products        (via product_id)
  +-- sellers         (via seller_id)
  +-- payments        (via order_id)
  +-- reviews         (via order_id)

customers / sellers
  +-- geolocation     (via zip_code_prefix)
```

One data quality issue worth calling out: the customers table has both
customer_id and customer_unique_id. The customer_id is generated per
order, so a customer who buys 3 times gets 3 different customer_ids.
Using customer_id to measure repeat purchases would make every customer
look like a first-time buyer and destroy the entire retention analysis.
All customer-level work uses customer_unique_id.

---

## RFM Segmentation

RFM (Recency, Frequency, Monetary) is a standard framework for
understanding customer behaviour. Each customer gets scored 1 to 5 on
three dimensions:

- **Recency**: how recently did they last buy?
- **Frequency**: how many times have they bought?
- **Monetary**: how much have they spent in total?

Those three scores combine into a segment label.

| Segment | Customers | Total Revenue | Avg Revenue / Customer |
|---------|-----------|---------------|------------------------|
| At Risk | 22,230 | R$3.71M | R$167 |
| Loyal | 27,288 | R$3.66M | R$134 |
| New Customers | 14,984 | R$2.45M | R$163 |
| Lost | 14,986 | R$2.44M | R$163 |
| Champions | 6,497 | R$2.03M | R$312 |
| Potential | 7,373 | R$1.13M | R$154 |

At Risk is the most important segment to act on. These customers have
purchase history (they scored decently on frequency) but have gone
quite recently (low recency score). They have not left yet. AA 
reactivation campaign targeting these 22,230 customers is cheaper than
acquiring 22,230 new ones and are more likely to convert.

Champions average R$312 per customer, more than double the overall
average. The long-term goal is to move more customers into this bucket.

---

## Delivery Performance vs Customer Satisfaction

This was the clearest single chart in the entire analysis.

| Delivery Status | Orders | Avg Review Score |
|----------------|--------|-----------------|
| Early (3+ days) | 85,173 | 4.22 |
| On time | 4,270 | 4.06 |
| Late (1 to 3 days) | 1,852 | 3.23 |
| Late (3+ days) | 4,529 | 1.85 |

When a delivery arrives more than 3 days late, the review score drops
to 1.85 out of 5. Customers who give a score that low seldom
return. There are 4,529 such orders in this dataset. Each one represents
a near-certain, permanently lost customer.

Fixing delivery timing is the single highest-leverage action available
to improve the 3% repeat rate.

---

## Geographic Breakdown

Sao Paulo dominates at R$5.77M (37% of total revenue), which is
expected. The concern is Rio de Janeiro. It is the second largest
market at R$2.05M but has the lowest satisfaction score among top
states at 3.87, compared to the national average of around 4.1.

Bahia shows a similar pattern at 3.86. Both states are large enough
to matter and both are underperforming on the metric that most directly
predicts whether customers return.

---

## Payment Behaviour

Credit card accounts for 80% of transactions. Within credit card
payments, customers who use installments spend an average of R$195
per order versus R$96 for those who pay in full. Installment buyers
represent 67% of all credit card orders.

This means customers are already comfortable with installment payments
and are willing to spend significantly more when they use them. Making
installments more prominent on higher-value product pages is a 
straightforward way to lift the average order value without acquiring
new customers.

---

## Recommendations

Three actions, ordered by expected impact:

**1. Fix delivery performance**
Find the sellers and logistics routes producing the most late
deliveries. Set a minimum performance standard and enforce it.
A 20% improvement in the on-time delivery rate would materially
shift review scores and, over time, the 3% repeat rate.

**2. Reactivate the At Risk segment**
22,230 customers with R$3.7M in prior spend are showing signs of
disengagement. A targeted email or offer campaign costs a fraction
of acquiring equivalent new customers. Even a 10% reactivation
rate recovers roughly R$370K in revenue.

**3. Investigate RJ and BA operations**
Both states contribute substantial revenue but score below average
on satisfaction. The cause could be seller concentration, courier
reliability, or product mix. Diagnosing this before investing further
in these markets is the right order of operations.

---

## Files in This Repo

| File | What It Is |
|------|------------|
| `sql/olist_queries.sql` | All SQL queries with inline comments |
| `notebooks/olist_analysis.ipynb` | Python notebook with full analysis |
| `reports/Executive_Summary.pdf` | One-page summary for decision makers |
| `reports/Full_Analysis_Report.pdf` | Complete findings with charts |
| `dashboard/dashboard_preview.png` | Power BI dashboard screenshot |

---

## Tools Used

- SQL (SQLite) for joins, aggregations, and segmentation queries
- Python with pandas and matplotlib for RFM scoring and visualisations
- Excel for initial data exploration and column mapping
- Power BI for the final dashboard

---

## Dataset

Brazilian E-Commerce Public Dataset by Olist, available on Kaggle.
The dataset is not included in this repo due to file size. Download
it directly from Kaggle and place the CSV files in a `/data` folder
to run the queries and notebook locally.

---

## Dashboard Preview

*Coming soon. Power BI dashboard covers: monthly revenue trend,
repeat rate, delivery performance breakdown, RFM segment map,
and state-level satisfaction scores.*
