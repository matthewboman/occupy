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


def prepare_dataset(data):
    required = (
        SOCIAL_FEATURES
        + MARKET_FEATURES
        + [TARGET]
    )

    usable = data.dropna(
        subset=required
    ).copy()

    train = usable[
        usable["date"] <= TRAIN_END
    ].copy()

    test = usable[
        usable["date"] >= TEST_START
    ].copy()

    return train, test


def evaluate_model(
    name,
    model,
    train,
    test,
    features,
):
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

    mae = mean_absolute_error(
        y_test,
        predictions,
    )

    r2 = r2_score(
        y_test,
        predictions,
    )

    spearman = spearmanr(
        y_test,
        predictions,
    ).statistic

    print()
    print(name)
    print("-" * len(name))
    print(f"MAE:      {mae:.4f}")
    print(f"R²:       {r2:.4f}")
    print(f"Spearman: {spearman:.4f}")

    return predictions


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

    for name, data in [
        ("Training", train),
        ("Test", test),
    ]:
        target = data[TARGET]

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

    path = Path(args.input)

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

    market_model = LinearRegression()

    evaluate_model(
        "MARKET-ONLY LINEAR REGRESSION",
        market_model,
        train,
        test,
        MARKET_FEATURES,
    )

    social_model = LinearRegression()

    evaluate_model(
        "SOCIAL-ONLY LINEAR REGRESSION",
        social_model,
        train,
        test,
        SOCIAL_FEATURES,
    )

    combined_model = LinearRegression()

    evaluate_model(
        "MARKET + SOCIAL LINEAR REGRESSION",
        combined_model,
        train,
        test,
        MARKET_FEATURES + SOCIAL_FEATURES,
    )


if __name__ == "__main__":
    main()