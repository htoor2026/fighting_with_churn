# ============================================================
# CUSTOMER CHURN PREDICTION APPLICATION
# Business Stakeholder View + Technical View
# ============================================================

import streamlit as st
import pandas as pd
import numpy as np
import joblib
from pathlib import Path


# ============================================================
# 1. PAGE CONFIGURATION
# ============================================================

st.set_page_config(
    page_title="Customer Churn Prediction",
    layout="wide"
)

# ============================================================
# PORTFOLIO UI STYLING
# ============================================================
st.markdown(
    """
    <style>

    /* ========================================================
       PAGE
    ======================================================== */

    .stApp {
        background-color: #F4F5F7 !important;
        color: #1F2937 !important;
    }

    .block-container {
        max-width: 1280px;
        padding-top: 2.2rem;
        padding-bottom: 5rem;
    }


    /* ========================================================
       HEADINGS
    ======================================================== */

    h1, h2, h3 {
        color: #182230 !important;
    }

    h1 {
        font-weight: 750 !important;
    }

    h2 {
        font-weight: 700 !important;
    }

    h3 {
        font-weight: 650 !important;
    }


    /* ========================================================
       BODY TEXT
    ======================================================== */

    p,
    li {
        color: #475467 !important;
        line-height: 1.65 !important;
    }


    /* ========================================================
       ACCENT LABELS
    ======================================================== */

    .hero-eyebrow,
    .section-label {
        color: #9A6A18 !important;
        font-weight: 700;
    }


    /* ========================================================
       HERO
    ======================================================== */

    .hero {
        background-color: #FFFFFF !important;
        border: 1px solid #E4E7EC !important;
        border-radius: 22px;
        padding: 48px 52px;
        margin-bottom: 30px;

        box-shadow:
            0 8px 24px rgba(16, 24, 40, 0.06);
    }

    .hero-title {
        color: #182230 !important;
        font-size: 3.8rem;
        line-height: 1.02;
        font-weight: 780;
        letter-spacing: -0.045em;
        margin-bottom: 20px;
    }

    .hero-subtitle {
        color: #667085 !important;
        font-size: 1.08rem;
        line-height: 1.7;
        max-width: 850px;
    }


    /* ========================================================
       TABS
    ======================================================== */

    div[data-baseweb="tab-list"] {
        gap: 10px;
        border-bottom: 1px solid #D0D5DD !important;
        margin-bottom: 28px;
    }

    button[data-baseweb="tab"] {
        background: transparent !important;
        color: #667085 !important;

        font-size: 1.05rem !important;
        font-weight: 600 !important;

        padding: 14px 20px !important;
        border-radius: 8px 8px 0 0 !important;
    }

    button[data-baseweb="tab"] p {
        color: #667085 !important;
        font-size: 1.05rem !important;
        font-weight: 600 !important;
    }

    button[data-baseweb="tab"]:hover {
        background-color: #EAECF0 !important;
    }

    button[data-baseweb="tab"]:hover p {
        color: #182230 !important;
    }

    button[data-baseweb="tab"][aria-selected="true"] {
        background-color: #FFFFFF !important;
        border-bottom: 3px solid #344054 !important;
    }

    button[data-baseweb="tab"][aria-selected="true"] p {
        color: #182230 !important;
        font-weight: 700 !important;
    }


    /* ========================================================
       METRIC CARDS
    ======================================================== */

    div[data-testid="stMetric"] {
        background-color: #FFFFFF !important;
        border: 1px solid #E4E7EC !important;
        border-radius: 14px;
        padding: 22px;

        box-shadow:
            0 4px 16px rgba(16, 24, 40, 0.05);
    }

    div[data-testid="stMetricLabel"] {
        color: #667085 !important;
        font-size: 0.86rem !important;
        font-weight: 600 !important;
    }

    div[data-testid="stMetricValue"] {
        color: #182230 !important;
        font-size: 2rem !important;
        font-weight: 750 !important;
    }


    /* ========================================================
       CUSTOMER INPUT FORM
    ======================================================== */

    div[data-testid="stForm"] {
        background-color: #FFFFFF !important;
        border: 1px solid #D0D5DD !important;
        border-radius: 18px;
        padding: 28px;

        box-shadow:
            0 8px 24px rgba(16, 24, 40, 0.06);
    }

    div[data-testid="stForm"] h2,
    div[data-testid="stForm"] h3,
    div[data-testid="stForm"] p,
    div[data-testid="stForm"] label,
    div[data-testid="stForm"] span {
        color: #182230 !important;
    }


    /* ========================================================
       INPUTS
    ======================================================== */

    div[data-baseweb="select"] > div,
    div[data-testid="stNumberInput"] input,
    div[data-testid="stTextInput"] input {
        background-color: #F9FAFB !important;
        color: #182230 !important;

        border: 1px solid #D0D5DD !important;
        border-radius: 9px !important;
    }


    /* ========================================================
       PREDICT BUTTON
    ======================================================== */

    div[data-testid="stFormSubmitButton"] button {
        width: 100%;

        background-color: #253858 !important;
        color: #FFFFFF !important;

        border: none !important;
        border-radius: 9px !important;

        padding: 0.85rem 1.4rem !important;

        font-size: 1rem !important;
        font-weight: 700 !important;
    }
    
    div[data-testid="stFormSubmitButton"] button p,
    div[data-testid="stFormSubmitButton"] button span {
        color: #FFFFFF !important;
    }

    div[data-testid="stFormSubmitButton"] button:hover,
    div[data-testid="stFormSubmitButton"] button:hover p,
    div[data-testid="stFormSubmitButton"] button:hover span {
        color: #FFFFFF !important;
    }


    /* ========================================================
       DATAFRAMES
    ======================================================== */

    div[data-testid="stDataFrame"] {
        background-color: #FFFFFF !important;
        border: 1px solid #E4E7EC !important;
        border-radius: 12px;
        overflow: hidden;
    }


    /* ========================================================
       CODE BLOCKS
    ======================================================== */

    pre {
        background-color: #182230 !important;
        border: 1px solid #344054 !important;
        border-radius: 12px !important;
        padding: 20px !important;
    }

    code {
        color: #F2F4F7 !important;
    }


    /* ========================================================
       DIVIDERS
    ======================================================== */

    hr {
        border-color: #D0D5DD !important;
        margin-top: 3rem !important;
        margin-bottom: 3rem !important;
    }


    /* ========================================================
       CAPTIONS
    ======================================================== */

    div[data-testid="stCaptionContainer"] {
        color: #667085 !important;
    }


    /* ========================================================
       REMOVE STREAMLIT MENU / FOOTER
    ======================================================== */

    #MainMenu {
        visibility: hidden;
    }

    footer {
        visibility: hidden;
    }

    </style>
    """,
    unsafe_allow_html=True
)

# ============================================================
# 2. FILE PATHS
# ============================================================

MODEL_PATH = Path("models/xgboost_extended.pkl")

PREDICTIONS_PATH = Path(
    "data/xgboost_test_predictions.csv"
)

MODEL_COMPARISON_PATH = Path(
    "data/final_model_comparison.csv"
)


# ============================================================
# 3. VERIFY REQUIRED FILES
# ============================================================

if not MODEL_PATH.exists():

    st.error(
        f"Model file not found: {MODEL_PATH}"
    )

    st.stop()


if not PREDICTIONS_PATH.exists():

    st.error(
        f"Prediction file not found: {PREDICTIONS_PATH}"
    )

    st.stop()


if not MODEL_COMPARISON_PATH.exists():

    st.error(
        f"Model comparison file not found: {MODEL_COMPARISON_PATH}"
    )

    st.stop()


# ============================================================
# 4. LOAD FINAL MODEL
# ============================================================

@st.cache_resource
def load_model():

    saved_model = joblib.load(
        MODEL_PATH
    )

    return (
        saved_model["preprocessor"],
        saved_model["model"],
        saved_model["features"]
    )


preprocessor, model, model_features = load_model()


# ============================================================
# 5. LOAD STORED TEST PREDICTIONS
# ============================================================

@st.cache_data
def load_test_predictions():

    predictions = pd.read_csv(
        PREDICTIONS_PATH
    )

    return predictions


test_predictions = load_test_predictions()


@st.cache_data
def load_model_comparison():

    comparison = pd.read_csv(
        MODEL_COMPARISON_PATH
    )

    return comparison


model_comparison = load_model_comparison()


# ============================================================
# 6. TEST-SET BUSINESS METRICS
# ============================================================

# Retention capacity is fixed at the highest-risk 10% of the
# out-of-time test population. Ranking creates an exact segment.

ranked_predictions = (
    test_predictions
    .sort_values(
        "xgb_churn_probability",
        ascending=False
    )
    .reset_index(drop=True)
)

TEST_OBSERVATIONS = len(ranked_predictions)

TARGET_COUNT = max(
    1,
    int(np.ceil(TEST_OBSERVATIONS * 0.10))
)

top_risk_predictions = (
    ranked_predictions
    .head(TARGET_COUNT)
    .copy()
)

HIGH_RISK_THRESHOLD = (
    top_risk_predictions[
        "xgb_churn_probability"
    ]
    .min()
)

ACTUAL_CHURNERS = int(
    ranked_predictions["is_churn"].sum()
)

CAPTURED_CHURNERS = int(
    top_risk_predictions["is_churn"].sum()
)

OVERALL_CHURN_RATE = ranked_predictions["is_churn"].mean()
TOP_RISK_CHURN_RATE = top_risk_predictions["is_churn"].mean()

CAPTURE_RATE = (
    CAPTURED_CHURNERS / ACTUAL_CHURNERS
    if ACTUAL_CHURNERS
    else 0.0
)

RETENTION_LIFT = (
    TOP_RISK_CHURN_RATE / OVERALL_CHURN_RATE
    if OVERALL_CHURN_RATE
    else 0.0
)

ranked_predictions["expected_monthly_revenue_at_risk"] = (
    ranked_predictions["xgb_churn_probability"]
    * ranked_predictions["current_mrr"]
)

top_risk_predictions["expected_monthly_revenue_at_risk"] = (
    top_risk_predictions["xgb_churn_probability"]
    * top_risk_predictions["current_mrr"]
)

TOTAL_REVENUE_AT_RISK = (
    ranked_predictions["expected_monthly_revenue_at_risk"].sum()
)

HIGH_PRIORITY_REVENUE_AT_RISK = (
    top_risk_predictions["expected_monthly_revenue_at_risk"].sum()
)

HIGH_PRIORITY_REVENUE_SHARE = (
    HIGH_PRIORITY_REVENUE_AT_RISK / TOTAL_REVENUE_AT_RISK
    if TOTAL_REVENUE_AT_RISK
    else 0.0
)


# ============================================================
# 7. SUBSCRIPTION PARAMETERS
# ============================================================

PLAN_PRICES = {

    "basic": 10.0,

    "plus": 20.0,

    "premium": 35.0
}


BILLING_DISCOUNTS = {

    1: 0.00,

    3: 0.05,

    6: 0.10
}


# ============================================================
# 8. MAIN APPLICATION TABS
# ============================================================

business_tab, technical_tab = st.tabs(
    [
        "Business Stakeholder View",
        "Technical View"
    ]
)


# ============================================================
# BUSINESS STAKEHOLDER VIEW
# ============================================================

with business_tab:
    st.markdown(
        '<div class="section-label">BUSINESS CASE</div>',
        unsafe_allow_html=True
    )

    st.header(
        "From Churn Prediction to Retention Decisions"
    )

    st.write(
        """
        The goal is to help a subscription business decide where
        limited retention resources should be focused.

        Instead of treating every customer equally, the system ranks
        customers by predicted churn risk and combines that risk with
        recurring revenue to create an actionable retention priority.
        """
    )
    

    st.header(
        "Business Churn and Retention Decision Tool"
    )


    # ========================================================
    # BUSINESS PROBLEM
    # ========================================================

    st.subheader("Business Problem")

    st.write(
        """
        A subscription-based social media company wants to identify
        customers who are at elevated risk of cancelling their
        subscription before churn occurs.

        The objective is not simply to predict churn. The business
        also needs to determine which customers should receive
        retention attention and which customers represent meaningful
        recurring-revenue exposure.
        """
    )


    # ========================================================
    # BUSINESS QUESTIONS
    # ========================================================

    st.subheader("Questions This System Addresses")

    st.markdown(
        """
        - Which customers are most likely to churn?
        - Which customer behaviors are associated with churn risk?
        - Does subscription information improve churn prediction?
        - Which customers should the retention team contact first?
        - How much monthly recurring revenue is associated with
          predicted churn risk?
        """
    )


    # ========================================================
    # KEY PROJECT RESULTS
    # ========================================================

    st.subheader("Key Business Results")

    col1, col2, col3, col4 = st.columns(4)


    with col1:

        st.metric(
            "Top 10% Churners Captured",
            "31.9%"
        )


    with col2:

        st.metric(
            "Retention Lift",
            "3.19x"
        )


    with col3:

        st.metric(
            "Targeted Group Churn Rate",
            "5.15%"
        )


    with col4:

        st.metric(
            "Overall Test Churn Rate",
            "1.61%"
        )


    st.write(
        """
        In the out-of-time test population, targeting only the
        highest-risk 10% of customer observations identified
        approximately 31.9% of actual churners.

        The targeted group's churn rate was approximately 5.15%,
        compared with 1.61% across the full test population,
        representing approximately 3.19 times lift.
        """
    )


    # ========================================================
    # REVENUE RESULT
    # ========================================================

    st.subheader("Revenue Prioritization")

    col1, col2 = st.columns(2)


    with col1:

        st.metric(
            "Expected Monthly Revenue at Risk",
            "$3,036.17"
        )


    with col2:

        st.metric(
            "High-Priority Revenue at Risk",
            "$1,200.78"
        )


    st.write(
        """
        Approximately 40% of modeled monthly revenue exposure was
        concentrated in the highest-risk retention segment.

        This allows the company to prioritize customers using both
        predicted churn risk and customer economic value.
        """
    )


    st.info(
        """
        Expected revenue at risk is calculated as predicted churn
        probability multiplied by current monthly recurring revenue.
        It represents modeled exposure, not guaranteed revenue loss.
        """
    )


    # ========================================================
    # CUSTOMER PREDICTION TOOL
    # ========================================================

    st.divider()

    st.header("Customer Churn Risk Assessment")

    st.write(
        """
        Enter a customer's current profile, recent 28-day activity,
        and subscription information to generate an estimated churn
        probability and retention priority.
        """
    )


    with st.form("prediction_form"):


        # ====================================================
        # CUSTOMER PROFILE
        # ====================================================

        st.subheader("Customer Profile")

        col1, col2, col3, col4 = st.columns(4)


        with col1:

            channel = st.selectbox(
                "Acquisition Channel",
                [
                    "web",
                    "appstore1",
                    "appstore2"
                ]
            )


        with col2:

            country = st.text_input(
                "Country Code",
                value="US",
                help=(
                    "Examples: US, CA, AU, CN. "
                    "Use Unknown if unavailable."
                )
            )


        with col3:

            customer_age = st.number_input(
                "Customer Age",
                min_value=12,
                max_value=100,
                value=35
            )


        with col4:

            account_tenure_days = st.number_input(
                "Account Tenure (Days)",
                min_value=0,
                value=90
            )


        # ====================================================
        # CUSTOMER ACTIVITY
        # ====================================================

        st.subheader(
            "Last 28 Days of Customer Activity"
        )

        st.caption(
            """
            Enter the number of events generated during the
            previous 28 days.
            """
        )


        col1, col2, col3, col4 = st.columns(4)


        with col1:

            post_per_month = st.number_input(
                "Posts",
                min_value=0,
                value=10
            )

            newfriend_per_month = st.number_input(
                "New Friends",
                min_value=0,
                value=5
            )


        with col2:

            like_per_month = st.number_input(
                "Likes",
                min_value=0,
                value=50
            )

            adview_per_month = st.number_input(
                "Ad Views",
                min_value=0,
                value=30
            )


        with col3:

            dislike_per_month = st.number_input(
                "Dislikes",
                min_value=0,
                value=5
            )

            unfriend_per_month = st.number_input(
                "Unfriends",
                min_value=0,
                value=1
            )


        with col4:

            message_per_month = st.number_input(
                "Messages",
                min_value=0,
                value=20
            )

            reply_per_month = st.number_input(
                "Replies",
                min_value=0,
                value=8
            )


        # ====================================================
        # SUBSCRIPTION INFORMATION
        # ====================================================

        st.subheader("Subscription Information")


        col1, col2, col3 = st.columns(3)


        with col1:

            current_plan = st.selectbox(
                "Current Plan",
                [
                    "basic",
                    "plus",
                    "premium"
                ]
            )


        with col2:

            bill_period_months = st.selectbox(
                "Billing Commitment",
                [
                    1,
                    3,
                    6
                ],
                format_func=lambda x: (
                    f"{x} month"
                    if x == 1
                    else f"{x} months"
                )
            )


        with col3:

            previous_plan = st.selectbox(
                "Previous Plan",
                [
                    "basic",
                    "plus",
                    "premium"
                ],
                help=(
                    "Use the current plan if the customer "
                    "did not recently change plans."
                )
            )


        col1, col2 = st.columns(2)


        with col1:

            recent_upgrade = st.checkbox(
                "Upgrade in last 90 days"
            )


        with col2:

            recent_downsell = st.checkbox(
                "Downsell in last 90 days"
            )


        submitted = st.form_submit_button(
            "Predict Churn Risk",
            use_container_width=True
        )


    # ========================================================
    # PREDICTION LOGIC
    # ========================================================

    if submitted:


        # ====================================================
        # SUBSCRIPTION FEATURE ENGINEERING
        # ====================================================

        discount = BILLING_DISCOUNTS[
            bill_period_months
        ]


        current_mrr = (
            PLAN_PRICES[current_plan]
            * (1 - discount)
        )


        previous_mrr = (
            PLAN_PRICES[previous_plan]
            * (1 - discount)
        )


        mrr_change = (
            current_mrr
            - previous_mrr
        )


        upgrade_flag = int(
            mrr_change > 0
        )


        downsell_flag = int(
            mrr_change < 0
        )


        upgrade_last_90d = int(
            recent_upgrade
        )


        downsell_last_90d = int(
            recent_downsell
        )


        # ====================================================
        # BEHAVIORAL FEATURE ENGINEERING
        # ====================================================

        total_engagement = (

            post_per_month
            + newfriend_per_month
            + like_per_month
            + message_per_month
            + reply_per_month
        )


        negative_engagement = (

            dislike_per_month
            + unfriend_per_month
        )


        total_activity = (

            post_per_month
            + newfriend_per_month
            + like_per_month
            + adview_per_month
            + dislike_per_month
            + unfriend_per_month
            + message_per_month
            + reply_per_month
        )


        # ----------------------------------------------------
        # Dislike rate
        # ----------------------------------------------------

        like_dislike_total = (

            like_per_month
            + dislike_per_month
        )


        if like_dislike_total > 0:

            dislike_rate = (

                dislike_per_month
                / like_dislike_total
            )

        else:

            dislike_rate = 0.0


        # ----------------------------------------------------
        # Unfriend rate
        # ----------------------------------------------------

        friend_activity_total = (

            newfriend_per_month
            + unfriend_per_month
        )


        if friend_activity_total > 0:

            unfriend_rate = (

                unfriend_per_month
                / friend_activity_total
            )

        else:

            unfriend_rate = 0.0


        # ----------------------------------------------------
        # Reply rate
        # ----------------------------------------------------

        if message_per_month > 0:

            reply_rate = (

                reply_per_month
                / message_per_month
            )

        else:

            reply_rate = 0.0


        # ----------------------------------------------------
        # Activity shares
        # ----------------------------------------------------

        if total_activity > 0:

            negative_activity_share = (

                negative_engagement
                / total_activity
            )


            adview_share = (

                adview_per_month
                / total_activity
            )

        else:

            negative_activity_share = 0.0

            adview_share = 0.0


        # ====================================================
        # BUILD MODEL INPUT ROW
        # ====================================================

        customer = pd.DataFrame(
            [
                {

                    "channel":
                        channel,

                    "country":
                        (
                            country
                            .strip()
                            .upper()
                            if country.strip()
                            else "Unknown"
                        ),

                    "current_plan":
                        current_plan,

                    "customer_age":
                        customer_age,

                    "account_tenure_days":
                        account_tenure_days,

                    "post_per_month":
                        post_per_month,

                    "newfriend_per_month":
                        newfriend_per_month,

                    "like_per_month":
                        like_per_month,

                    "adview_per_month":
                        adview_per_month,

                    "dislike_per_month":
                        dislike_per_month,

                    "unfriend_per_month":
                        unfriend_per_month,

                    "message_per_month":
                        message_per_month,

                    "reply_per_month":
                        reply_per_month,

                    "total_engagement":
                        total_engagement,

                    "negative_engagement":
                        negative_engagement,

                    "total_activity":
                        total_activity,

                    "dislike_rate":
                        dislike_rate,

                    "unfriend_rate":
                        unfriend_rate,

                    "reply_rate":
                        reply_rate,

                    "negative_activity_share":
                        negative_activity_share,

                    "adview_share":
                        adview_share,

                    "current_mrr":
                        current_mrr,

                    "bill_period_months":
                        bill_period_months,

                    "discount":
                        discount,

                    "mrr_change":
                        mrr_change,

                    "upgrade_flag":
                        upgrade_flag,

                    "downsell_flag":
                        downsell_flag,

                    "upgrade_last_90d":
                        upgrade_last_90d,

                    "downsell_last_90d":
                        downsell_last_90d
                }
            ]
        )


        # Exact feature order used during model training

        customer = customer[
            model_features
        ]


        # ====================================================
        # MODEL TRANSFORMATION
        # ====================================================

        X_customer = preprocessor.transform(
            customer
        )


        # ====================================================
        # CHURN PROBABILITY
        # ====================================================

        churn_probability = (

            model.predict_proba(
                X_customer
            )[0, 1]
        )


        # ====================================================
        # REVENUE AT RISK
        # ====================================================

        revenue_at_risk = (

            churn_probability
            * current_mrr
        )


        # ====================================================
        # RETENTION PRIORITY
        # ====================================================

        if (
            churn_probability
            >= HIGH_RISK_THRESHOLD
        ):

            risk_level = "High Priority"

        else:

            risk_level = "Standard Priority"


        # ====================================================
        # DISPLAY RESULTS
        # ====================================================

        st.divider()

        st.header("Churn Risk Assessment")


        col1, col2, col3, col4 = (
            st.columns(4)
        )


        with col1:

            st.metric(
                "Estimated Churn Risk",
                f"{churn_probability:.1%}"
            )


        with col2:

            st.metric(
                "Retention Priority",
                risk_level
            )


        with col3:

            st.metric(
                "Current MRR",
                f"${current_mrr:.2f}"
            )


        with col4:

            st.metric(
                "Expected Monthly Revenue at Risk",
                f"${revenue_at_risk:.2f}"
            )


        # ====================================================
        # BUSINESS INTERPRETATION
        # ====================================================

        st.subheader("Business Interpretation")


        if risk_level == "High Priority":

            st.warning(
                """
                This customer falls within the model's
                highest-risk retention segment.

                The retention or customer-success team may
                want to prioritize this customer for review
                and potential retention outreach.
                """
            )

        else:

            st.success(
                """
                This customer does not currently fall within
                the highest-risk retention segment.

                The customer can remain under standard
                retention monitoring.
                """
            )


        st.write(
            f"""
            The model estimates a churn probability of
            **{churn_probability:.1%}**.

            With current monthly recurring revenue of
            **${current_mrr:.2f}**, the modeled expected monthly
            revenue exposure is approximately
            **${revenue_at_risk:.2f}**.
            """
        )


        # ====================================================
        # CUSTOMER SUMMARY
        # ====================================================

        st.subheader("Customer Summary")


        customer_summary = pd.DataFrame(
            {

                "Metric": [

                    "Current Plan",

                    "Previous Plan",

                    "Billing Commitment",

                    "Discount",

                    "Current MRR",

                    "Total Engagement",

                    "Total Activity",

                    "Dislike Rate",

                    "Unfriend Rate",

                    "Reply Rate",

                    "Recent Upgrade",

                    "Recent Downsell"
                ],

                "Value": [

                    current_plan.title(),

                    previous_plan.title(),

                    (
                        f"{bill_period_months} "
                        "month"
                        if bill_period_months == 1
                        else
                        f"{bill_period_months} "
                        "months"
                    ),

                    f"{discount:.0%}",

                    f"${current_mrr:.2f}",

                    total_engagement,

                    total_activity,

                    f"{dislike_rate:.1%}",

                    f"{unfriend_rate:.1%}",

                    f"{reply_rate:.2f}",

                    (
                        "Yes"
                        if recent_upgrade
                        else "No"
                    ),

                    (
                        "Yes"
                        if recent_downsell
                        else "No"
                    )
                ]
            }
        )


        st.dataframe(
            customer_summary,
            hide_index=True,
            use_container_width=True
        )


        # ====================================================
        # HOW BUSINESS WOULD USE THIS
        # ====================================================

        st.subheader(
            "How This Would Be Used in a Business"
        )


        st.code(
            """
Customer activity and subscription data
        |
        v
Churn prediction model
        |
        v
Predicted churn probability
        |
        v
Customer risk ranking
        |
        +-----------------------------+
        |                             |
        v                             v
Retention priority              Current MRR
        |                             |
        +-------------+---------------+
                      |
                      v
            Revenue-at-risk priority
                      |
                      v
             Retention outreach
            """,
            language="text"
        )


        st.write(
            """
            In a production environment, these features would
            normally be calculated automatically from customer
            activity and subscription systems rather than entered
            manually.
            """
        )


# ============================================================
# TECHNICAL VIEW
# ============================================================

with technical_tab:
    
    st.markdown(
        '<div class="section-label">TECHNICAL CASE STUDY</div>',
        unsafe_allow_html=True
    )

    st.header(
        "From Raw Behavioral Events to Deployed Predictions"
    )

    st.write(
        """
        This section documents the analytical and machine-learning
        pipeline behind the application: data preparation, feature
        engineering, temporal validation, model benchmarking,
        evaluation and deployment.
        """
    )
    st.header("Technical Model Documentation")

    st.write(
        """
        This section explains the data, feature engineering,
        validation methodology, model comparison, model
        interpretation, and deployment pipeline.
        """
    )


    # ========================================================
    # 1. PROJECT DEVELOPMENT
    # ========================================================

    st.subheader("1. Project Development")

    st.write(
        """
        The project began by reproducing and studying an existing
        churn-analysis framework based on Carl Gold's ChurnSim and
        SocialNet simulated customer data.

        The original workflow provided the baseline churn methodology,
        behavioral metrics, feature-engineering concepts, and modeling
        structure.

        The project was then extended with a richer synthetic
        subscription layer and additional behavioral feature
        engineering to create a more complete retention use case.
        """
    )


    # ========================================================
    # 2. DATASET
    # ========================================================

    st.subheader("2. Dataset")

    col1, col2, col3, col4 = st.columns(4)


    with col1:

        st.metric(
            "Customer Accounts",
            "14,641"
        )


    with col2:

        st.metric(
            "Raw Events",
            "17.1M+"
        )


    with col3:

        st.metric(
            "Model Observations",
            "32,897"
        )


    with col4:

        st.metric(
            "Churn Observations",
            "645"
        )


    st.write(
        """
        The final training dataset contains customer-date
        observations combining customer characteristics, recent
        behavioral activity, subscription information, and the
        churn target.
        """
    )


    st.markdown(
        """
        **Behavior event types**

        - Post
        - New friend
        - Like
        - Ad view
        - Dislike
        - Unfriend
        - Message
        - Reply
        """
    )


    # ========================================================
    # 3. SUBSCRIPTION EXTENSION
    # ========================================================

    st.subheader("3. Subscription Extension")

    st.write(
        """
        The original subscription structure was extended to
        represent a richer subscription business.
        """
    )


    subscription_table = pd.DataFrame(
        {

            "Component": [

                "Plans",
                "MRR",
                "Billing Commitment",
                "Discounts",
                "Plan Movement",
                "Movement History"
            ],

            "Extension": [

                "Basic, Plus, Premium",

                "$9 to $35",

                "1, 3, and 6 months",

                "Billing-based discounts",

                "Upgrade and downsell indicators",

                "Upgrade/downsell within previous 90 days"
            ]
        }
    )


    st.dataframe(
        subscription_table,
        hide_index=True,
        use_container_width=True
    )


    st.caption(
        """
        The richer subscription layer is a synthetic extension
        created for this portfolio project.
        """
    )


    # ========================================================
    # 4. FEATURE ENGINEERING
    # ========================================================

    st.subheader("4. Feature Engineering")


    st.markdown(
        """
        **Customer features**

        - Acquisition channel
        - Country
        - Customer age
        - Account tenure


        **Raw 28-day behavior features**

        - Posts
        - New friends
        - Likes
        - Ad views
        - Dislikes
        - Unfriends
        - Messages
        - Replies


        **Engineered behavioral features**

        - Total engagement
        - Negative engagement
        - Total activity
        - Dislike rate
        - Unfriend rate
        - Reply rate
        - Negative activity share
        - Ad-view share


        **Subscription features**

        - Current plan
        - Current MRR
        - Billing commitment
        - Discount
        - MRR change
        - Upgrade flag
        - Downsell flag
        - Upgrade in previous 90 days
        - Downsell in previous 90 days
        """
    )


    # ========================================================
    # 5. EDA FINDINGS
    # ========================================================

    st.subheader("5. Exploratory Analysis Findings")


    eda_results = pd.DataFrame(
        {

            "Metric": [

                "Median total engagement - retained",

                "Median total engagement - churned",

                "Median dislike rate - retained",

                "Median dislike rate - churned",

                "Overall churn rate"
            ],

            "Result": [

                "128",

                "61",

                "16.7%",

                "20.8%",

                "1.96%"
            ]
        }
    )


    st.dataframe(
        eda_results,
        hide_index=True,
        use_container_width=True
    )


    st.write(
        """
        Churned observations showed substantially lower overall
        customer activity.

        Raw negative-event counts were also lower because churners
        performed less activity overall. Ratio features therefore
        provided additional context by measuring negative behavior
        relative to total or related activity.
        """
    )


    # ========================================================
    # 6. TEMPORAL VALIDATION
    # ========================================================

    st.subheader("6. Validation Strategy")


    st.code(
        """
February 9, 2020
        |
        |   Training observations
        |
        |---------------- April 11, 2020
                           |
                           |   Out-of-time test observations
                           |
                           |---------------- May 10, 2020
        """,
        language="text"
    )


    st.write(
        """
        A temporal train/test split was used.

        Earlier observations were used for model training and later
        observations were held out for evaluation.

        This is closer to the real production scenario in which
        historical customer behavior is used to predict future churn.
        """
    )


    # ========================================================
    # 7. MODEL COMPARISON
    # ========================================================

    st.subheader("7. Model Comparison")


    model_results = pd.DataFrame(
        {

            "Model": [

                "Logistic Regression - Core",

                "Logistic Regression - Extended",

                "XGBoost - Core",

                "XGBoost - Extended"
            ],

            "ROC-AUC": [

                0.6529,

                0.6526,

                0.6619,

                0.6735
            ],

            "PR-AUC": [

                0.0426,

                0.0438,

                0.0589,

                0.0620
            ]
        }
    )


    st.dataframe(
        model_results,
        hide_index=True,
        use_container_width=True
    )


    st.success(
        """
        Final model: Extended XGBoost

        ROC-AUC: 0.6735

        PR-AUC: 0.0620

        Test-period churn prevalence: 1.61%
        """
    )


    st.write(
        """
        Subscription features provided little improvement to the
        Logistic Regression model but improved the XGBoost model.

        This suggests that some subscription information contributes
        through nonlinear relationships or interactions with customer
        behavior.
        """
    )


    # ========================================================
    # 8. XGBOOST FEATURE IMPORTANCE
    # ========================================================

    st.subheader("8. Important Predictive Features")


    feature_importance = pd.DataFrame(
        {

            "Feature": [

                "Total engagement",

                "Replies per month",

                "Account tenure",

                "New friends per month",

                "Messages per month",

                "Unfriend rate",

                "Posts per month",

                "Total activity",

                "Country - CA",

                "Channel - appstore2",

                "Ad-view share",

                "Negative activity share",

                "Discount",

                "Dislike rate",

                "Billing period",

                "Current MRR"
            ],

            "Importance": [

                0.057246,

                0.037523,

                0.035640,

                0.032505,

                0.031875,

                0.031689,

                0.030159,

                0.027056,

                0.026445,

                0.025410,

                0.024854,

                0.024199,

                0.023656,

                0.023612,

                0.022538,

                0.022513
            ]
        }
    )


    st.dataframe(
        feature_importance,
        hide_index=True,
        use_container_width=True
    )


    st.write(
        """
        Behavioral engagement was the strongest source of predictive
        information. Subscription characteristics also contributed
        incremental predictive value.
        """
    )


    st.caption(
        """
        XGBoost feature importance represents predictive contribution.
        It does not establish causality or by itself indicate whether
        increasing a variable raises or lowers churn probability.
        """
    )


    # ========================================================
    # 9. RETENTION PERFORMANCE
    # ========================================================

    st.subheader("9. Retention Targeting Performance")


    retention_results = pd.DataFrame(
        {

            "Measure": [

                "Test observations",

                "Actual churners",

                "Top-risk observations targeted",

                "Churners captured",

                "Churners captured percentage",

                "Overall churn rate",

                "Top 10% churn rate",

                "Lift"
            ],

            "Result": [

                "11,645",

                "188",

                "1,165",

                "60",

                "31.91%",

                "1.61%",

                "5.15%",

                "3.19x"
            ]
        }
    )


    st.dataframe(
        retention_results,
        hide_index=True,
        use_container_width=True
    )


    # ========================================================
    # 10. REVENUE AT RISK
    # ========================================================

    st.subheader("10. Revenue-at-Risk Calculation")


    st.code(
        """
Expected Monthly Revenue at Risk
=
Predicted Churn Probability
x
Current Monthly Recurring Revenue
        """,
        language="text"
    )


    st.write(
        """
        Across the out-of-time test observations:

        Expected monthly revenue at risk:
        $3,036.17

        Expected monthly revenue at risk in the high-priority
        retention segment:
        $1,200.78
        """
    )


    # ========================================================
    # 11. MODEL PIPELINE
    # ========================================================

    st.subheader("11. Machine Learning Pipeline")


    st.code(
        """
Raw customer and event data
        |
        v
28-day behavioral aggregation
        |
        v
Behavioral feature engineering
        |
        v
Subscription feature engineering
        |
        v
Categorical one-hot encoding
        |
        v
Extended XGBoost classifier
        |
        v
Predicted churn probability
        |
        v
Top-10% risk threshold
        |
        v
Retention priority
        |
        v
Probability x MRR
        |
        v
Expected revenue at risk
        """,
        language="text"
    )


    # ========================================================
    # 12. DEPLOYMENT ARCHITECTURE
    # ========================================================

    st.subheader("12. Deployment Architecture")


    st.code(
        """
Production customer systems
        |
        +-- Customer profile
        |
        +-- Recent behavioral events
        |
        +-- Subscription history
        |
        v
Automated feature generation
        |
        v
Saved preprocessing pipeline
        |
        v
Saved XGBoost model
        |
        v
Churn probability
        |
        +----------------------+
        |                      |
        v                      v
Risk priority             Revenue at risk
        |                      |
        +----------+-----------+
                   |
                   v
          Retention workflow
        """,
        language="text"
    )


    st.write(
        """
        This portfolio application uses manual inputs to demonstrate
        model inference.

        In a real production environment, the customer information
        would normally be retrieved automatically from operational
        databases or data pipelines.
        """
    )


    # ========================================================
    # 13. LIMITATIONS
    # ========================================================

    st.subheader("13. Limitations")


    st.markdown(
        """
        - The underlying customer behavior is simulated using
          ChurnSim/SocialNet.

        - The richer subscription layer is a synthetic project
          extension.

        - The model identifies predictive associations rather than
          causal effects.

        - Upgrade and downsell variables were constructed from
          behavioral information and therefore should not be
          interpreted as causal treatment effects.

        - Model performance would need to be retrained and validated
          before use with real production customers.

        - The risk threshold should ultimately be selected using
          business capacity, intervention cost, and retention value.
        """
    )


    # ========================================================
    # 14. TECHNICAL CONCLUSION
    # ========================================================

    st.subheader("14. Technical Conclusion")


    st.write(
        """
        The project demonstrates an end-to-end churn analytics
        workflow: data preparation, behavioral and subscription
        feature engineering, exploratory analysis, temporal
        validation, Logistic Regression benchmarking, XGBoost
        modeling, customer risk ranking, and revenue-based retention
        prioritization.

        The Extended XGBoost model produced the strongest
        out-of-time performance and was therefore selected as the
        final model for deployment.
        """
    )


# ============================================================
# GLOBAL PROJECT DISCLAIMER
# ============================================================

st.divider()

st.caption(
    """
    Portfolio demonstration using simulated ChurnSim/SocialNet
    customer behavior and a synthetic subscription extension.
    Model predictions represent estimated risk rather than certainty
    that an individual customer will churn.
    """
)