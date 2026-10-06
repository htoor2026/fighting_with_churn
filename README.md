# Fighting Churn: Customer Churn Prediction & Retention Prioritization

An end-to-end machine learning portfolio project for identifying customers at risk of churn, comparing behavioral and subscription-aware models, and turning churn probabilities into retention priorities and expected monthly revenue at risk.

## Business problem

A subscription-based social media company wants to:

- identify customers likely to churn before cancellation;
- understand which behavioral and subscription signals are useful for prediction;
- prioritize a limited retention budget toward the highest-risk customers; and
- quantify recurring revenue exposure.

## Project evolution

This repository combines two stages of work.

### 1. Baseline churn framework

The `baseline/` directory preserves the learning and reproduction stage based on the churn-analysis workflow from Carl Gold's *Fighting Churn with Data* and the ChurnSim SocialNet simulation framework.

The baseline work covers:

- churn and retention SQL;
- active-period and observation construction;
- behavioral frequency, recency, ratio, tenure, and demographic features;
- skew / fat-tail feature handling;
- Logistic Regression;
- forecasting and validation concepts.

### 2. Extended churn solution

The final project extends the behavioral baseline with a richer synthetic subscription layer:

- Basic, Plus, and Premium plans;
- monthly recurring revenue (MRR);
- 1-, 3-, and 6-month billing commitments;
- discounts;
- upgrades and downsells;
- recent subscription-movement indicators;
- all eight SocialNet behavior types;
- additional engagement and behavioral-ratio features.

The final modeling workflow compares a behavior-only feature set with the extended behavior + subscription feature set.

## Data

The underlying customer behavior is simulated SocialNet / ChurnSim data. The subscription enrichment is a synthetic extension created for this project.

The final modeling dataset contains approximately 32.9K account-observation rows and is intentionally imbalanced, with churn representing about 2% of observations.

Behavioral inputs include:

- posts;
- new friends;
- likes;
- ad views;
- dislikes;
- unfriends;
- messages;
- replies.

Additional engineered features include total engagement, total activity, negative engagement, dislike rate, unfriend rate, reply rate, negative activity share, and ad-view share.

## Modeling approach

The project uses an out-of-time split rather than relying only on a random split, so evaluation better reflects a forecasting use case.

Models compared:

| Model | ROC-AUC | PR-AUC |
|---|---:|---:|
| Logistic Regression - Core | 0.6529 | 0.0426 |
| Logistic Regression - Extended | 0.6526 | 0.0438 |
| XGBoost - Core | 0.6619 | 0.0589 |
| **XGBoost - Extended** | **0.6735** | **0.0620** |

The final selected model is the **Extended XGBoost** model. The subscription features add modest incremental predictive value in the nonlinear model.

Because churn is rare, PR-AUC and lift are emphasized alongside ROC-AUC rather than using accuracy as the primary metric.

## Retention targeting results

On the out-of-time test set:

- 11,645 customers were scored;
- 188 churners were observed;
- baseline churn rate was **1.61%**;
- targeting the highest-risk 10% selected 1,165 customers;
- that group captured **60 of 188 churners (31.91%)**;
- churn rate inside the targeted group was **5.15%**;
- lift versus random targeting was **3.19x**.

## Revenue-at-risk prioritization

Expected monthly revenue at risk is defined as:

```text
churn probability × current MRR
```

Across the test set:

- expected monthly revenue at risk: **$3,036.17**;
- expected monthly revenue at risk in the top-risk 10%: **$1,200.78**;
- the top-risk 10% therefore concentrates about **39.5%** of modeled monthly revenue exposure.

This is an expected-value prioritization metric, not a guaranteed revenue-loss estimate.

## Streamlit application

`app.py` provides two views:

- **Business Stakeholder View** — customer-level churn scoring, retention priority, and expected monthly revenue at risk;
- **Technical View** — project evolution, feature engineering, model comparison, retention performance, and limitations.

The manual customer-input form is a portfolio demonstration. In production, the same features would typically be populated automatically from customer activity and subscription systems.

## Repository structure

```text
fighting_with_churn/
├── app.py
├── README.md
├── requirements.txt
├── baseline/
│   ├── data/
│   ├── figures/
│   ├── notebooks/
│   └── sql/
├── data/
├── models/
├── notebooks/
└── simulation_reference/
    └── socialnet7/
```

### Key final files

```text
data/churn_training_final.csv
data/churn_modeling_ready.csv
data/final_model_comparison.csv
data/xgboost_test_predictions.csv
data/high_priority_retention_customers.csv

models/logistic_regression_extended.pkl
models/xgboost_extended.pkl

notebooks/01_data_validation_and_eda.ipynb
notebooks/02_exploratory_analysis_feature_engineering.ipynb
notebooks/04_logistic_regression.ipynb
notebooks/05_xgboost_backtest.ipynb
notebooks/06_retention_business_analysis.ipynb
```

## Run locally

Clone the repository and install the dependencies:

```bash
git clone https://github.com/htoor2026/fighting_with_churn.git
cd fighting_with_churn
python -m pip install -r requirements.txt
```

Start the Streamlit application:

```bash
python -m streamlit run app.py
```

Then open the local Streamlit URL shown in the terminal.

## Important limitations

- The underlying behavioral data is simulated rather than proprietary production customer data.
- The richer subscription layer is a synthetic project extension.
- Subscription movements were added after the original churn simulation, so upgrade/downsell relationships should not be interpreted causally.
- Feature importance reflects predictive contribution, not causal impact.
- Model performance is useful for ranking and targeting, but it is not sufficient evidence that any specific retention treatment will reduce churn.

## Portfolio takeaway

This project demonstrates the full churn workflow: SQL-based customer analytics, feature engineering, temporal model validation, Logistic Regression and XGBoost comparison, retention lift analysis, revenue-at-risk prioritization, and deployment in a Streamlit decision-support application.
