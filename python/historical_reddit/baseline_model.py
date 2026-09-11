from pathlib import Path
import argparse

import pandas as pd
from scipy.stats import spearmanr
from sklearn.linear_model import LinearRegression
from sklearn.metrics import mean_absolute_error, r2_score


SOCIAL_FEATURES = [
    "mention_count",
    "submission_count",
    "comment_count",
    "unique_author_count",
    "total_score",
    "average_score",
    "mention_spike_7d",
    "mention_change_1d",
    "mention_change_3d",
    "submission_change_1d",
    "submission_change_3d",
    "unique_author_change_1d",
    "unique_author_change_3d",
]

MARKET_FEATURES = [
    "past_range_10d",
]

TARGET = "abnormal_range_10d"

TRAIN_END = pd.Timestamp("2024-01-31")
TEST_START = pd.Timestamp("2024-02-01")

# The target looks forward 10 trading days.
# Exclude the final 21 calendar days of each training
# window so training outcomes cannot overlap the test period.
PURGE_DAYS = 21

MIN_TRAIN_ROWS = 500


def load_dataset(path):
    data = pd.read_csv(
        path,
        parse_dates=[
            "date",
            "market_date",
        ],
    )

    numeric_columns = [
        "mention_count",
        "submission_count",
        "comment_count",
        "unique_author_count",
        "total_score",
        "average_score",
        "return_1d",
        "return_3d",
        "return_5d",
        "return_10d",
        "spy_return_1d",
        "spy_return_3d",
        "spy_return_5d",
        "spy_return_10d",
        "past_range_10d",
        "max_gain_10d",
        "max_drawdown_10d",
    ]

    for column in numeric_columns:
        data[column] = pd.to_numeric(
            data[column],
            errors="coerce",
        )

    return data


def build_daily_social_panel(data):
    start_date = data["date"].min()
    end_date = data["date"].max()

    calendar = pd.date_range(
        start=start_date,
        end=end_date,
        freq="D",
    )

    panels = []

    for symbol, group in data.groupby("symbol"):
        social = (
            group[
                [
                    "date",
                    "mention_count",
                    "submission_count",
                    "unique_author_count",
                ]
            ]
            .drop_duplicates(subset=["date"])
            .set_index("date")
            .reindex(calendar)
        )

        social.index.name = "date"

        zero_columns = [
            "mention_count",
            "submission_count",
            "unique_author_count",
        ]

        social[zero_columns] = (
            social[zero_columns]
            .fillna(0)
        )

        social["symbol"] = symbol

        social["mention_avg_7d"] = (
            social["mention_count"]
            .shift(1)
            .rolling(
                window=7,
                min_periods=7,
            )
            .mean()
        )

        social["mention_spike_7d"] = (
            social["mention_count"]
            / social["mention_avg_7d"]
        )

        social["mention_change_1d"] = (
            social["mention_count"]
            - social["mention_count"].shift(1)
        )

        social["mention_change_3d"] = (
            social["mention_count"]
            - social["mention_count"].shift(3)
        )

        social["submission_change_1d"] = (
            social["submission_count"]
            - social["submission_count"].shift(1)
        )

        social["submission_change_3d"] = (
            social["submission_count"]
            - social["submission_count"].shift(3)
        )

        social["unique_author_change_1d"] = (
            social["unique_author_count"]
            - social["unique_author_count"].shift(1)
        )

        social["unique_author_change_3d"] = (
            social["unique_author_count"]
            - social["unique_author_count"].shift(3)
        )

        panels.append(
            social.reset_index()
        )

    return pd.concat(
        panels,
        ignore_index=True,
    )


def add_social_features(data):
    panel = build_daily_social_panel(
        data
    )

    derived = panel[
        [
            "symbol",
            "date",
            "mention_spike_7d",
            "mention_change_1d",
            "mention_change_3d",
            "submission_change_1d",
            "submission_change_3d",
            "unique_author_change_1d",
            "unique_author_change_3d",
        ]
    ]

    return data.merge(
        derived,
        on=[
            "symbol",
            "date",
        ],
        how="left",
    )


def add_target(data):
    data["future_range_10d"] = (
        data["max_gain_10d"]
        - data["max_drawdown_10d"]
    )

    data[TARGET] = (
        data["future_range_10d"]
        / data["past_range_10d"]
    )

    return data


def clean_dataset(data):
    data = data.copy()

    data.replace(
        [
            float("inf"),
            float("-inf"),
        ],
        float("nan"),
        inplace=True,
    )

    return data


def usable_dataset(data):
    required = (
        SOCIAL_FEATURES
        + MARKET_FEATURES
        + [TARGET]
    )

    return data.dropna(
        subset=required
    ).copy()


def prepare_dataset(data):
    usable = usable_dataset(
        data
    )

    train = usable[
        usable["date"] <= TRAIN_END
    ].copy()

    test = usable[
        usable["date"] >= TEST_START
    ].copy()

    return train, test


def model_metrics(
    train,
    test,
    features,
):
    model = LinearRegression()

    x_train = train[features]
    y_train = train[TARGET]

    x_test = test[features]
    y_test = test[TARGET]

    model.fit(
        x_train,
        y_train,
    )

    predictions = model.predict(
        x_test
    )

    return {
        "mae": mean_absolute_error(
            y_test,
            predictions,
        ),
        "r2": r2_score(
            y_test,
            predictions,
        ),
        "spearman": spearmanr(
            y_test,
            predictions,
        ).statistic,
    }


def evaluate_model(
    name,
    train,
    test,
    features,
):
    metrics = model_metrics(
        train,
        test,
        features,
    )

    print()
    print(name)
    print("-" * len(name))
    print(f"MAE:      {metrics['mae']:.4f}")
    print(f"R²:       {metrics['r2']:.4f}")
    print(f"Spearman: {metrics['spearman']:.4f}")

    return metrics


def print_dataset_summary(
    train,
    test,
):
    print()
    print("MODEL DATASET")
    print("-------------")

    print(
        f"Training rows: {len(train):,}"
    )

    print(
        f"Training dates: "
        f"{train['date'].min().date()} "
        f"to "
        f"{train['date'].max().date()}"
    )

    print()

    print(
        f"Test rows: {len(test):,}"
    )

    print(
        f"Test dates: "
        f"{test['date'].min().date()} "
        f"to "
        f"{test['date'].max().date()}"
    )


def print_target_distribution(
    train,
    test,
):
    print()
    print("TARGET DISTRIBUTION")
    print("-------------------")

    for name, dataset in [
        ("Training", train),
        ("Test", test),
    ]:
        target = dataset[TARGET]

        print()
        print(name)

        print(
            target.describe(
                percentiles=[
                    0.01,
                    0.05,
                    0.25,
                    0.50,
                    0.75,
                    0.90,
                    0.95,
                    0.99,
                ]
            ).round(4)
        )


def rolling_monthly_validation(data):
    usable = usable_dataset(
        data
    )

    first_date = usable["date"].min()
    last_date = usable["date"].max()

    month_starts = pd.date_range(
        start=first_date.to_period("M").start_time,
        end=last_date.to_period("M").start_time,
        freq="MS",
    )

    results = []

    for test_start in month_starts:
        test_end = (
            test_start
            + pd.offsets.MonthEnd(0)
        )

        train_end = (
            test_start
            - pd.Timedelta(days=PURGE_DAYS)
        )

        train = usable[
            usable["date"] <= train_end
        ].copy()

        test = usable[
            (usable["date"] >= test_start)
            & (usable["date"] <= test_end)
        ].copy()

        if len(train) < MIN_TRAIN_ROWS:
            continue

        if test.empty:
            continue

        market = model_metrics(
            train,
            test,
            MARKET_FEATURES,
        )

        social = model_metrics(
            train,
            test,
            SOCIAL_FEATURES,
        )

        combined = model_metrics(
            train,
            test,
            MARKET_FEATURES + SOCIAL_FEATURES,
        )

        results.append(
            {
                "test_month": test_start.strftime(
                    "%Y-%m"
                ),
                "train_end": train_end.date(),
                "train_rows": len(train),
                "test_rows": len(test),
                "market_spearman": market[
                    "spearman"
                ],
                "social_spearman": social[
                    "spearman"
                ],
                "combined_spearman": combined[
                    "spearman"
                ],
                "social_improvement": (
                    combined["spearman"]
                    - market["spearman"]
                ),
            }
        )

    print()
    print("ROLLING MONTHLY VALIDATION")
    print("--------------------------")
    print(
        f"Purged days before each test month: "
        f"{PURGE_DAYS}"
    )

    if not results:
        print()
        print(
            "Not enough data for a rolling "
            "monthly validation window yet."
        )
        return

    result_data = pd.DataFrame(
        results
    )

    print()
    print(
        result_data.to_string(
            index=False,
            float_format=lambda value: (
                f"{value:.4f}"
            ),
        )
    )

    print()
    print("ROLLING SUMMARY")
    print("---------------")

    print(
        "Average market Spearman:   "
        f"{result_data['market_spearman'].mean():.4f}"
    )

    print(
        "Average social Spearman:   "
        f"{result_data['social_spearman'].mean():.4f}"
    )

    print(
        "Average combined Spearman: "
        f"{result_data['combined_spearman'].mean():.4f}"
    )

    print(
        "Average social improvement: "
        f"{result_data['social_improvement'].mean():.4f}"
    )

    wins = (
        result_data["combined_spearman"]
        > result_data["market_spearman"]
    ).sum()

    print(
        "Combined beats market-only: "
        f"{wins} / {len(result_data)} months"
    )


def main():
    parser = argparse.ArgumentParser()

    parser.add_argument(
        "--input",
        default=(
            "../../data/analysis/"
            "security_daily_dataset.csv"
        ),
    )

    args = parser.parse_args()

    path = Path(
        args.input
    )

    if not path.exists():
        raise RuntimeError(
            f"Dataset not found: {path}"
        )

    data = load_dataset(
        path
    )

    data = add_social_features(
        data
    )

    data = add_target(
        data
    )

    data = clean_dataset(
        data
    )

    train, test = prepare_dataset(
        data
    )

    print_dataset_summary(
        train,
        test,
    )

    print_target_distribution(
        train,
        test,
    )

    evaluate_model(
        "MARKET-ONLY LINEAR REGRESSION",
        train,
        test,
        MARKET_FEATURES,
    )

    evaluate_model(
        "SOCIAL-ONLY LINEAR REGRESSION",
        train,
        test,
        SOCIAL_FEATURES,
    )

    evaluate_model(
        "MARKET + SOCIAL LINEAR REGRESSION",
        train,
        test,
        MARKET_FEATURES + SOCIAL_FEATURES,
    )

    rolling_monthly_validation(
        data
    )


if __name__ == "__main__":
    main()