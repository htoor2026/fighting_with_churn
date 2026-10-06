from __future__ import annotations

import json
import math
import re
from pathlib import Path

import joblib
import numpy as np
import pandas as pd
from sklearn.compose import ColumnTransformer
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import average_precision_score, roc_auc_score
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import OneHotEncoder, StandardScaler
from xgboost import XGBClassifier


ROOT = Path(__file__).resolve().parents[1]
DATA_DIR = ROOT / "data"
MODEL_DIR = ROOT / "models"
README_PATH = ROOT / "README.md"

RAW_DATA_PATH = DATA_DIR / "churn_training_final.csv"
MODELING_DATA_PATH = DATA_DIR / "churn_modeling_ready.csv"

TEST_START = pd.Timestamp("2020-04-11")
TRAIN_END = TEST_START - pd.DateOffset(months=1)

MODEL_DIR.mkdir(exist_ok=True)
DATA_DIR.mkdir(exist_ok=True)


CORE_CATEGORICAL = [
    "channel",
    "country",
]

CORE_NUMERIC = [
    "customer_age",
    "account_tenure_days",
    "post_per_month",
    "newfriend_per_month",
    "like_per_month",
    "adview_per_month",
    "dislike_per_month",
    "unfriend_per_month",
    "message_per_month",
    "reply_per_month",
    "total_engagement",
    "negative_engagement",
    "total_activity",
    "dislike_rate",
    "unfriend_rate",
    "reply_rate",
    "negative_activity_share",
    "adview_share",
]

CORE_FEATURES = CORE_CATEGORICAL + CORE_NUMERIC

EXTENDED_CATEGORICAL = [
    "channel",
    "country",
    "current_plan",
]

EXTENDED_NUMERIC = CORE_NUMERIC + [
    "current_mrr",
    "bill_period_months",
    "discount",
    "mrr_change",
    "upgrade_flag",
    "downsell_flag",
    "upgrade_last_90d",
    "downsell_last_90d",
]

EXTENDED_FEATURES = EXTENDED_CATEGORICAL + EXTENDED_NUMERIC


def build_modeling_dataset() -> pd.DataFrame:
    df = pd.read_csv(
        RAW_DATA_PATH,
        parse_dates=["observation_date"],
    )

    df["country"] = df["country"].fillna("Unknown")

    df["is_churn"] = (
        df["is_churn"]
        .astype(str)
        .str.strip()
        .str.lower()
        .map(
            {
                "t": 1,
                "true": 1,
                "1": 1,
                "f": 0,
                "false": 0,
                "0": 0,
            }
        )
    )

    df["total_engagement"] = (
        df["post_per_month"]
        + df["newfriend_per_month"]
        + df["like_per_month"]
        + df["message_per_month"]
        + df["reply_per_month"]
    )

    df["negative_engagement"] = (
        df["dislike_per_month"]
        + df["unfriend_per_month"]
    )

    df["total_activity"] = (
        df["post_per_month"]
        + df["newfriend_per_month"]
        + df["like_per_month"]
        + df["adview_per_month"]
        + df["dislike_per_month"]
        + df["unfriend_per_month"]
        + df["message_per_month"]
        + df["reply_per_month"]
    )

    df["dislike_rate"] = np.where(
        (
            df["like_per_month"]
            + df["dislike_per_month"]
        )
        > 0,
        df["dislike_per_month"]
        / (
            df["like_per_month"]
            + df["dislike_per_month"]
        ),
        0.0,
    )

    df["unfriend_rate"] = np.where(
        (
            df["newfriend_per_month"]
            + df["unfriend_per_month"]
        )
        > 0,
        df["unfriend_per_month"]
        / (
            df["newfriend_per_month"]
            + df["unfriend_per_month"]
        ),
        0.0,
    )

    df["reply_rate"] = np.where(
        df["message_per_month"] > 0,
        df["reply_per_month"]
        / df["message_per_month"],
        0.0,
    )

    df["negative_activity_share"] = np.where(
        df["total_activity"] > 0,
        df["negative_engagement"]
        / df["total_activity"],
        0.0,
    )

    df["adview_share"] = np.where(
        df["total_activity"] > 0,
        df["adview_per_month"]
        / df["total_activity"],
        0.0,
    )

    model_df = df[
        [
            "account_id",
            "observation_date",
            "is_churn",
        ]
        + EXTENDED_FEATURES
    ].copy()

    if model_df.isna().any().any():
        missing = (
            model_df.isna()
            .sum()
            .loc[lambda values: values > 0]
        )
        raise ValueError(
            "Unexpected missing values in modeling data:\n"
            + missing.to_string()
        )

    model_df.to_csv(
        MODELING_DATA_PATH,
        index=False,
    )

    return model_df


def evaluate(name: str, y_true: pd.Series, probabilities: np.ndarray) -> dict:
    return {
        "model": name,
        "roc_auc": float(roc_auc_score(y_true, probabilities)),
        "pr_auc": float(average_precision_score(y_true, probabilities)),
    }


def make_logistic_pipeline(
    categorical_features: list[str],
    numeric_features: list[str],
) -> Pipeline:
    preprocessor = ColumnTransformer(
        transformers=[
            (
                "numeric",
                StandardScaler(),
                numeric_features,
            ),
            (
                "categorical",
                OneHotEncoder(handle_unknown="ignore"),
                categorical_features,
            ),
        ]
    )

    model = LogisticRegression(
        max_iter=5000,
        solver="lbfgs",
        C=1.0,
    )

    return Pipeline(
        steps=[
            ("preprocessor", preprocessor),
            ("model", model),
        ]
    )


def make_xgb_preprocessor(
    categorical_features: list[str],
    numeric_features: list[str],
) -> ColumnTransformer:
    return ColumnTransformer(
        transformers=[
            (
                "categorical",
                OneHotEncoder(handle_unknown="ignore"),
                categorical_features,
            ),
            (
                "numeric",
                "passthrough",
                numeric_features,
            ),
        ]
    )


def split_data(df: pd.DataFrame):
    train_df = df[
        df["observation_date"] < TRAIN_END
    ].copy()

    embargo_df = df[
        (df["observation_date"] >= TRAIN_END)
        & (df["observation_date"] < TEST_START)
    ].copy()

    test_df = df[
        df["observation_date"] >= TEST_START
    ].copy()

    return train_df, embargo_df, test_df


def update_readme(metrics: dict) -> None:
    if not README_PATH.exists():
        return

    text = README_PATH.read_text(encoding="utf-8")

    model_rows = metrics["models"]
    best = max(model_rows, key=lambda row: row["pr_auc"])

    model_block = [
        "<!-- AUTO_MODEL_RESULTS_START -->",
        "| Model | ROC-AUC | PR-AUC |",
        "|---|---:|---:|",
    ]

    for row in model_rows:
        model_name = row["model"]
        if model_name == best["model"]:
            model_name = f"**{model_name}**"
            roc = f"**{row['roc_auc']:.4f}**"
            pr = f"**{row['pr_auc']:.4f}**"
        else:
            roc = f"{row['roc_auc']:.4f}"
            pr = f"{row['pr_auc']:.4f}"

        model_block.append(
            f"| {model_name} | {roc} | {pr} |"
        )

    model_block.extend(
        [
            "",
            f"Best model by PR-AUC: **{best['model']}**.",
            "<!-- AUTO_MODEL_RESULTS_END -->",
        ]
    )

    retention = metrics["retention"]

    retention_block = [
        "<!-- AUTO_RETENTION_RESULTS_START -->",
        f"- {retention['test_observations']:,} customers were scored;",
        f"- {retention['actual_churners']:,} churners were observed;",
        f"- baseline churn rate was **{retention['overall_churn_rate']:.2%}**;",
        (
            "- targeting the highest-risk 10% selected "
            f"{retention['targeted_observations']:,} customers;"
        ),
        (
            "- that group captured "
            f"**{retention['captured_churners']:,} of "
            f"{retention['actual_churners']:,} churners "
            f"({retention['capture_rate']:.2%})**;"
        ),
        (
            "- churn rate inside the targeted group was "
            f"**{retention['target_churn_rate']:.2%}**;"
        ),
        f"- lift versus random targeting was **{retention['lift']:.2f}x**.",
        "<!-- AUTO_RETENTION_RESULTS_END -->",
    ]

    revenue_block = [
        "<!-- AUTO_REVENUE_RESULTS_START -->",
        (
            "- expected monthly revenue at risk: **$"
            + f"{retention['total_revenue_at_risk']:,.2f}"
            + "**;"
        ),
        (
            "- expected monthly revenue at risk in the top-risk 10%: **$"
            + f"{retention['high_priority_revenue_at_risk']:,.2f}"
            + "**;"
        ),
        (
            "- the top-risk 10% therefore concentrates about "
            f"**{retention['high_priority_revenue_share']:.1%}** "
            "of modeled monthly revenue exposure."
        ),
        "<!-- AUTO_REVENUE_RESULTS_END -->",
    ]

    text = re.sub(
        r"<!-- AUTO_MODEL_RESULTS_START -->.*?<!-- AUTO_MODEL_RESULTS_END -->",
        "\n".join(model_block),
        text,
        flags=re.S,
    )

    text = re.sub(
        r"<!-- AUTO_RETENTION_RESULTS_START -->.*?<!-- AUTO_RETENTION_RESULTS_END -->",
        "\n".join(retention_block),
        text,
        flags=re.S,
    )

    text = re.sub(
        r"<!-- AUTO_REVENUE_RESULTS_START -->.*?<!-- AUTO_REVENUE_RESULTS_END -->",
        "\n".join(revenue_block),
        text,
        flags=re.S,
    )

    README_PATH.write_text(text, encoding="utf-8")


def main() -> None:
    df = build_modeling_dataset()

    train_df, embargo_df, test_df = split_data(df)

    y_train = train_df["is_churn"].astype(int)
    y_test = test_df["is_churn"].astype(int)

    print("Purged temporal split")
    print(
        "Train:",
        len(train_df),
        train_df["observation_date"].min(),
        "to",
        train_df["observation_date"].max(),
    )
    print(
        "Embargo:",
        len(embargo_df),
        embargo_df["observation_date"].min(),
        "to",
        embargo_df["observation_date"].max(),
    )
    print(
        "Test:",
        len(test_df),
        test_df["observation_date"].min(),
        "to",
        test_df["observation_date"].max(),
    )

    logistic_core = make_logistic_pipeline(
        CORE_CATEGORICAL,
        CORE_NUMERIC,
    )

    logistic_extended = make_logistic_pipeline(
        EXTENDED_CATEGORICAL,
        EXTENDED_NUMERIC,
    )

    logistic_core.fit(
        train_df[CORE_FEATURES],
        y_train,
    )

    logistic_extended.fit(
        train_df[EXTENDED_FEATURES],
        y_train,
    )

    logistic_core_probability = logistic_core.predict_proba(
        test_df[CORE_FEATURES]
    )[:, 1]

    logistic_extended_probability = logistic_extended.predict_proba(
        test_df[EXTENDED_FEATURES]
    )[:, 1]

    logistic_core_result = evaluate(
        "Core Behavior Logistic Regression",
        y_test,
        logistic_core_probability,
    )

    logistic_extended_result = evaluate(
        "Extended Subscription Logistic Regression",
        y_test,
        logistic_extended_probability,
    )

    logistic_comparison = pd.DataFrame(
        [
            logistic_core_result,
            logistic_extended_result,
        ]
    )

    logistic_predictions = test_df[
        [
            "account_id",
            "observation_date",
            "is_churn",
            "current_plan",
            "current_mrr",
            "upgrade_last_90d",
            "downsell_last_90d",
        ]
    ].copy()

    logistic_predictions["churn_probability"] = (
        logistic_extended_probability
    )

    logistic_predictions["risk_rank"] = (
        logistic_predictions["churn_probability"]
        .rank(
            method="first",
            ascending=False,
        )
    )

    logistic_predictions["risk_percentile"] = (
        logistic_predictions["churn_probability"]
        .rank(pct=True)
    )

    logistic_predictions["monthly_revenue_at_risk"] = (
        logistic_predictions["churn_probability"]
        * logistic_predictions["current_mrr"]
    )

    joblib.dump(
        logistic_extended,
        MODEL_DIR / "logistic_regression_extended.pkl",
    )

    logistic_predictions.to_csv(
        DATA_DIR / "logistic_regression_test_predictions.csv",
        index=False,
    )

    logistic_comparison.to_csv(
        DATA_DIR / "logistic_regression_model_comparison.csv",
        index=False,
    )

    core_preprocessor = make_xgb_preprocessor(
        CORE_CATEGORICAL,
        CORE_NUMERIC,
    )

    extended_preprocessor = make_xgb_preprocessor(
        EXTENDED_CATEGORICAL,
        EXTENDED_NUMERIC,
    )

    X_train_core = core_preprocessor.fit_transform(
        train_df[CORE_FEATURES]
    )

    X_test_core = core_preprocessor.transform(
        test_df[CORE_FEATURES]
    )

    X_train_extended = extended_preprocessor.fit_transform(
        train_df[EXTENDED_FEATURES]
    )

    X_test_extended = extended_preprocessor.transform(
        test_df[EXTENDED_FEATURES]
    )

    xgb_params = {
        "objective": "binary:logistic",
        "eval_metric": "logloss",
        "n_estimators": 400,
        "learning_rate": 0.03,
        "max_depth": 4,
        "min_child_weight": 5,
        "subsample": 0.8,
        "colsample_bytree": 0.8,
        "reg_alpha": 0.1,
        "reg_lambda": 1.0,
        "tree_method": "hist",
        "random_state": 42,
        "n_jobs": -1,
    }

    xgb_core = XGBClassifier(**xgb_params)
    xgb_extended = XGBClassifier(**xgb_params)

    xgb_core.fit(
        X_train_core,
        y_train,
    )

    xgb_extended.fit(
        X_train_extended,
        y_train,
    )

    xgb_core_probability = xgb_core.predict_proba(
        X_test_core
    )[:, 1]

    xgb_extended_probability = xgb_extended.predict_proba(
        X_test_extended
    )[:, 1]

    xgb_core_result = evaluate(
        "Core Behavior XGBoost",
        y_test,
        xgb_core_probability,
    )

    xgb_extended_result = evaluate(
        "Extended Subscription XGBoost",
        y_test,
        xgb_extended_probability,
    )

    final_comparison = pd.DataFrame(
        [
            {
                "model": "Logistic - Core",
                "roc_auc": logistic_core_result["roc_auc"],
                "pr_auc": logistic_core_result["pr_auc"],
            },
            {
                "model": "Logistic - Extended",
                "roc_auc": logistic_extended_result["roc_auc"],
                "pr_auc": logistic_extended_result["pr_auc"],
            },
            {
                "model": "XGBoost - Core",
                "roc_auc": xgb_core_result["roc_auc"],
                "pr_auc": xgb_core_result["pr_auc"],
            },
            {
                "model": "XGBoost - Extended",
                "roc_auc": xgb_extended_result["roc_auc"],
                "pr_auc": xgb_extended_result["pr_auc"],
            },
        ]
    )

    predictions = test_df[
        [
            "account_id",
            "observation_date",
            "is_churn",
            "current_plan",
            "current_mrr",
            "upgrade_last_90d",
            "downsell_last_90d",
        ]
    ].copy()

    predictions["xgb_churn_probability"] = (
        xgb_extended_probability
    )

    predictions = (
        predictions
        .sort_values(
            "xgb_churn_probability",
            ascending=False,
        )
        .reset_index(drop=True)
    )

    predictions["risk_rank"] = np.arange(
        1,
        len(predictions) + 1,
    )

    predictions["monthly_revenue_at_risk"] = (
        predictions["xgb_churn_probability"]
        * predictions["current_mrr"]
    )

    joblib.dump(
        {
            "preprocessor": extended_preprocessor,
            "model": xgb_extended,
            "features": EXTENDED_FEATURES,
        },
        MODEL_DIR / "xgboost_extended.pkl",
    )

    predictions.to_csv(
        DATA_DIR / "xgboost_test_predictions.csv",
        index=False,
    )

    final_comparison.to_csv(
        DATA_DIR / "final_model_comparison.csv",
        index=False,
    )

    target_count = max(
        1,
        math.ceil(len(predictions) * 0.10),
    )

    high_priority = (
        predictions
        .head(target_count)
        .copy()
    )

    high_priority["retention_priority"] = (
        "High Priority"
    )

    high_priority["expected_monthly_revenue_at_risk"] = (
        high_priority["xgb_churn_probability"]
        * high_priority["current_mrr"]
    )

    predictions["expected_monthly_revenue_at_risk"] = (
        predictions["xgb_churn_probability"]
        * predictions["current_mrr"]
    )

    actual_churners = int(
        predictions["is_churn"].sum()
    )

    captured_churners = int(
        high_priority["is_churn"].sum()
    )

    overall_churn_rate = float(
        predictions["is_churn"].mean()
    )

    target_churn_rate = float(
        high_priority["is_churn"].mean()
    )

    capture_rate = (
        captured_churners / actual_churners
        if actual_churners
        else 0.0
    )

    lift = (
        target_churn_rate / overall_churn_rate
        if overall_churn_rate
        else 0.0
    )

    total_revenue_at_risk = float(
        predictions["expected_monthly_revenue_at_risk"].sum()
    )

    high_priority_revenue_at_risk = float(
        high_priority["expected_monthly_revenue_at_risk"].sum()
    )

    revenue_share = (
        high_priority_revenue_at_risk
        / total_revenue_at_risk
        if total_revenue_at_risk
        else 0.0
    )

    high_priority.to_csv(
        DATA_DIR / "high_priority_retention_customers.csv",
        index=False,
    )

    metrics = {
        "validation": {
            "train_before": str(TRAIN_END.date()),
            "embargo_start": str(TRAIN_END.date()),
            "test_start": str(TEST_START.date()),
            "train_rows": int(len(train_df)),
            "embargo_rows": int(len(embargo_df)),
            "test_rows": int(len(test_df)),
        },
        "models": final_comparison.to_dict(
            orient="records"
        ),
        "deployed_model": "XGBoost - Extended",
        "retention": {
            "test_observations": int(len(predictions)),
            "actual_churners": actual_churners,
            "targeted_observations": int(target_count),
            "captured_churners": captured_churners,
            "capture_rate": float(capture_rate),
            "overall_churn_rate": overall_churn_rate,
            "target_churn_rate": target_churn_rate,
            "lift": float(lift),
            "total_revenue_at_risk": total_revenue_at_risk,
            "high_priority_revenue_at_risk": high_priority_revenue_at_risk,
            "high_priority_revenue_share": float(revenue_share),
        },
    }

    with (
        DATA_DIR / "project_metrics.json"
    ).open(
        "w",
        encoding="utf-8",
    ) as handle:
        json.dump(
            metrics,
            handle,
            indent=2,
        )

    update_readme(metrics)

    print("\nModel comparison")
    print(final_comparison.to_string(index=False))

    print("\nRetention results")
    print(
        f"Top 10%: {target_count:,} observations"
    )
    print(
        f"Captured: {captured_churners:,}/{actual_churners:,} "
        f"({capture_rate:.2%})"
    )
    print(
        f"Target churn rate: {target_churn_rate:.2%}"
    )
    print(
        f"Overall churn rate: {overall_churn_rate:.2%}"
    )
    print(
        f"Lift: {lift:.2f}x"
    )
    print(
        "Expected monthly revenue at risk: $"
        + f"{total_revenue_at_risk:,.2f}"
    )
    print(
        "High-priority revenue at risk: $"
        + f"{high_priority_revenue_at_risk:,.2f}"
    )


if __name__ == "__main__":
    main()
