from pathlib import Path
import argparse

import pandas as pd


BASE_FEATURES = [
    "mention_count",
    "submission_count",
    "comment_count",
    "unique_author_count",
    "total_score",
    "average_score",
]

SPIKE_FEATURES = [
    "mention_spike_7d",
    "mention_spike_30d",
]

VELOCITY_FEATURES = [
    "mention_change_1d",
    "mention_change_3d",
    "submission_change_1d",
    "submission_change_3d",
    "unique_author_change_1d",
    "unique_author_change_3d",
]

FEATURES = (
    BASE_FEATURES
    + SPIKE_FEATURES
    + VELOCITY_FEATURES
)

OUTCOMES = [
    "return_1d",
    "return_3d",
    "return_5d",
    "return_10d",
    "excess_return_1d",
    "excess_return_3d",
    "excess_return_5d",
    "excess_return_10d",
    "max_gain_10d",
    "max_drawdown_10d",
    "future_range_10d",
    "abnormal_range_10d",
]


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

        social["mention_avg_30d"] = (
            social["mention_count"]
            .shift(1)
            .rolling(
                window=30,
                min_periods=30,
            )
            .mean()
        )

        social["mention_spike_7d"] = (
            social["mention_count"]
            / social["mention_avg_7d"]
        )

        social["mention_spike_30d"] = (
            social["mention_count"]
            / social["mention_avg_30d"]
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
            "mention_spike_30d",
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


def add_spy_relative_returns(data):
    for days in [
        1,
        3,
        5,
        10,
    ]:
        data[
            f"excess_return_{days}d"
        ] = (
            data[f"return_{days}d"]
            - data[f"spy_return_{days}d"]
        )

    return data


def add_future_range(data):
    data[
        "future_range_10d"
    ] = (
        data["max_gain_10d"]
        - data["max_drawdown_10d"]
    )

    data[
        "abnormal_range_10d"
    ] = (
        data["future_range_10d"]
        / data["past_range_10d"]
    )

    return data


def clean_for_analysis(data):
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


def print_summary(data):
    print()
    print("DATASET")
    print("-------")
    print(f"Rows: {len(data):,}")
    print(
        f"Securities: "
        f"{data['symbol'].nunique():,}"
    )
    print(
        f"Date range: "
        f"{data['date'].min().date()} "
        f"to "
        f"{data['date'].max().date()}"
    )


def print_monthly_coverage(data):
    print()
    print("MONTHLY COVERAGE")
    print("----------------")

    monthly = (
        data.groupby(
            data["date"].dt.to_period("M")
        )
        .size()
    )

    for month, count in monthly.items():
        print(
            f"{month}: {count:,} rows"
        )


def print_benchmark_coverage(data):
    print()
    print("SPY BENCHMARK COVERAGE")
    print("----------------------")

    for days in [
        1,
        3,
        5,
        10,
    ]:
        column = f"spy_return_{days}d"

        available = (
            data[column]
            .notna()
            .sum()
        )

        print(
            f"{days}d: "
            f"{available:,} / "
            f"{len(data):,}"
        )


def print_spike_coverage(data):
    print()
    print("MENTION SPIKE COVERAGE")
    print("----------------------")

    for column in SPIKE_FEATURES:
        available = (
            data[column]
            .notna()
            .sum()
        )

        print(
            f"{column}: "
            f"{available:,} / "
            f"{len(data):,}"
        )


def print_velocity_coverage(data):
    print()
    print("VELOCITY COVERAGE")
    print("-----------------")

    for column in VELOCITY_FEATURES:
        available = (
            data[column]
            .notna()
            .sum()
        )

        print(
            f"{column}: "
            f"{available:,} / "
            f"{len(data):,}"
        )


def print_range_coverage(data):
    print()
    print("RANGE BASELINE COVERAGE")
    print("-----------------------")

    for column in [
        "past_range_10d",
        "future_range_10d",
        "abnormal_range_10d",
    ]:
        available = (
            data[column]
            .notna()
            .sum()
        )

        print(
            f"{column}: "
            f"{available:,} / "
            f"{len(data):,}"
        )


def print_correlations(
    data,
    method,
    title,
):
    print()
    print(title)
    print("-" * len(title))

    correlations = (
        data[
            FEATURES
            + OUTCOMES
        ]
        .corr(method=method)
        .loc[
            FEATURES,
            OUTCOMES,
        ]
    )

    print(
        correlations
        .round(4)
        .to_string()
    )


def print_velocity_relationships(data):
    print()
    print("ATTENTION VELOCITY")
    print("------------------")

    correlations = (
        data[
            VELOCITY_FEATURES
            + [
                "future_range_10d",
                "abnormal_range_10d",
                "excess_return_1d",
                "excess_return_5d",
                "excess_return_10d",
            ]
        ]
        .corr(method="spearman")
        .loc[
            VELOCITY_FEATURES,
            [
                "future_range_10d",
                "abnormal_range_10d",
                "excess_return_1d",
                "excess_return_5d",
                "excess_return_10d",
            ],
        ]
    )

    print(
        correlations
        .round(4)
        .to_string()
    )


def print_velocity_buckets(
    data,
    column,
):
    title = (
        column
        .replace("_", " ")
        .upper()
        + " QUINTILES"
    )

    print()
    print(title)
    print("-" * len(title))

    usable = data.dropna(
        subset=[
            column,
            "abnormal_range_10d",
        ]
    ).copy()

    if usable.empty:
        print("No usable rows")
        return

    usable["bucket"] = pd.qcut(
        usable[column].rank(
            method="first"
        ),
        5,
        labels=[
            "Q1 lowest",
            "Q2",
            "Q3",
            "Q4",
            "Q5 highest",
        ],
    )

    grouped = usable.groupby(
        "bucket",
        observed=True,
    )[
        [
            column,
            "past_range_10d",
            "future_range_10d",
            "abnormal_range_10d",
            "excess_return_1d",
            "excess_return_5d",
            "excess_return_10d",
        ]
    ].mean()

    print(
        grouped
        .round(4)
        .to_string()
    )


def print_strongest_relationships(data):
    print()
    print(
        "STRONGEST ABSOLUTE SPEARMAN RELATIONSHIPS"
    )
    print(
        "-----------------------------------------"
    )

    correlations = (
        data[
            FEATURES
            + OUTCOMES
        ]
        .corr(method="spearman")
        .loc[
            FEATURES,
            OUTCOMES,
        ]
    )

    rows = []

    for feature in FEATURES:
        for outcome in OUTCOMES:
            value = correlations.loc[
                feature,
                outcome,
            ]

            if pd.isna(value):
                continue

            rows.append(
                {
                    "feature": feature,
                    "outcome": outcome,
                    "correlation": value,
                    "absolute": abs(value),
                }
            )

    result = (
        pd.DataFrame(rows)
        .sort_values(
            "absolute",
            ascending=False,
        )
        .head(25)
    )

    print(
        result[
            [
                "feature",
                "outcome",
                "correlation",
            ]
        ]
        .round(4)
        .to_string(index=False)
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

    data = add_spy_relative_returns(
        data
    )

    data = add_future_range(
        data
    )

    data = clean_for_analysis(
        data
    )

    print_summary(
        data
    )

    print_monthly_coverage(
        data
    )

    print_benchmark_coverage(
        data
    )

    print_spike_coverage(
        data
    )

    print_velocity_coverage(
        data
    )

    print_range_coverage(
        data
    )

    print_correlations(
        data,
        method="pearson",
        title="PEARSON CORRELATIONS",
    )

    print_correlations(
        data,
        method="spearman",
        title="SPEARMAN CORRELATIONS",
    )

    print_velocity_relationships(
        data
    )

    for column in VELOCITY_FEATURES:
        print_velocity_buckets(
            data,
            column,
        )

    print_strongest_relationships(
        data
    )


if __name__ == "__main__":
    main()