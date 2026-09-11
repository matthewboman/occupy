# Occupy Data Pipeline Runbook

This project combines historical Reddit discussion data with historical market data so we can analyze whether social activity predicts future stock behavior.

The current workflow has four main stages:

```text
1. Collect Reddit history
2. Extract ticker mentions
3. Backfill market data
4. Build analysis datasets and outcomes
```

---

# 1. Historical Reddit ingestion

Run from:

```bash
cd occupy/python/historical_reddit
source .venv/bin/activate
```

## Download and import Reddit history

Use:

```bash
python download_reddit_history.py \
  --subreddit wallstreetbets \
  --start 2024-02-01 \
  --end 2024-02-28 \
  --type both \
  --delete-raw
```

Arguments:

```text
--subreddit
    Reddit board to download.
    Example: wallstreetbets, stocks, investing

--start
    First day to download.
    Inclusive.

--end
    End boundary.
    Exclusive.

--type
    submission
    comment
    both

--delete-raw
    Deletes the downloaded raw JSONL after a successful import.
```

Example for one day:

```bash
python download_reddit_history.py \
  --subreddit wallstreetbets \
  --start 2024-02-10 \
  --end 2024-02-11 \
  --type both \
  --delete-raw
```

## What this script does

```text
Arctic Shift
    ↓
downloads submissions/comments
    ↓
raw JSONL
    ↓
normalize_reddit_archive.py
    ↓
normalized CSV
    ↓
Rails historical importer
    ↓
SocialPost
    ↓
SecurityMention extraction
    ↓
checkpoint
```

It also:

* retries Arctic Shift timeouts
* slows down when the archive asks it to
* resumes partially downloaded files
* skips completed day/type combinations
* continues past failed routes
* deletes raw files only after successful processing

Download checkpoint:

```text
data/reddit/download_history_state.json
```

Archive-processing checkpoint:

```text
data/reddit/archive_import_state.json
```

You can rerun the same command safely.

Completed routes should print:

```text
Skipping completed r/wallstreetbets comment 2024-02-01
```

---

# 2. Reddit normalization and import

Normally you do not need to run these manually because `download_reddit_history.py` calls them for you.

## Normalize an archive file manually

```bash
python normalize_reddit_archive.py \
  --input ../../data/reddit/raw/comments/wallstreetbets/2024/02/file.jsonl \
  --output ../../data/reddit/normalized/output.csv \
  --type comment \
  --subreddit wallstreetbets
```

For submissions:

```bash
python normalize_reddit_archive.py \
  --input ../../data/reddit/raw/submissions/wallstreetbets/2024/02/file.jsonl \
  --output ../../data/reddit/normalized/output.csv \
  --type submission \
  --subreddit wallstreetbets
```

Purpose:

```text
raw Arctic Shift format
→ common CSV format used by Rails
```

Normalized fields include:

```text
external_id
subreddit
record_type
submission_external_id
parent_external_id
author
body
posted_at
score
url
```

## Process already-downloaded archive files

```bash
python process_reddit_archive.py \
  --subreddit wallstreetbets \
  --type comment \
  --input-dir ../../data/reddit/raw/comments/wallstreetbets/2024/02
```

Optional:

```bash
--delete-raw
```

Purpose:

```text
existing JSONL files
→ normalize
→ Rails import
→ checkpoint
```

---

# 3. Historical Reddit Rails importer

Run from the Rails root.

Normally this is called automatically by Python.

Manual usage:

```bash
bin/rails historical_reddit:import \
  FILE=data/reddit/normalized/example.csv
```

Purpose:

```text
normalized CSV
→ bulk upsert SocialPost
→ extract SecurityMention
```

The importer uses bulk `upsert_all`, so rerunning the same records does not create duplicates.

It also prints coverage information such as:

```text
Records
Submissions
Comments
With security mentions
Without security mentions
Unique securities mentioned
```

---

# 4. Security universe

The `Security` table is the canonical stock/ticker universe.

Import/update it with:

```bash
bin/rails security_universe:import
```

Purpose:

```text
Nasdaq Trader symbol directory
→ Security
```

This provides the list against which Reddit ticker-like tokens are checked.

Run this occasionally when you want to refresh the current listed-security universe.

---

# 5. Ticker extraction

Normally new Reddit imports run ticker extraction automatically.

To rebuild all ticker mentions manually:

```bash
bin/rails security_mentions:extract
```

Purpose:

```text
SocialPost body
→ detect ticker symbols
→ SecurityMention
```

The current extractor:

* accepts known securities
* supports `$NVDA`
* supports normal bare tickers like `NVDA`
* rejects known ambiguous bare tokens such as `AI`, `IT`, `FOR`, etc.
* preserves the full `SecurityMention` dataset even if a security is not yet selected for market-data backfill

If you intentionally change ticker-extraction rules and want a clean rebuild:

```bash
bin/rails runner 'SecurityMention.delete_all'
bin/rails security_mentions:extract
```

Do not do this casually because derived mention outcomes may also need rebuilding afterward.

---

# 6. Historical market-data backfill

Run:

```bash
bin/rails market_data:backfill_mentioned
```

Purpose:

```text
SecurityMention
    ↓
securities with at least 5 distinct mentions
    ↓
StashGamma historical EOD API
    ↓
MarketBar
```

The current backfill:

* starts at December 1, 2023
* processes securities with at least 5 distinct social mentions
* stores daily OHLCV in `MarketBar`
* waits between API requests
* checkpoints completed symbols
* skips completed symbols on rerun
* marks provider 404 symbols as unavailable
* stops on HTTP 429 rate-limit errors

Checkpoint:

```text
data/market_data/backfill_state.json
```

Example state:

```json
{
  "completed_symbols": [
    "AAPL",
    "GME",
    "NVDA"
  ],
  "unavailable_symbols": [
    "AIP"
  ]
}
```

A 404 does not mean the ticker should be deleted.

It means:

```text
StashGamma has no EOD data for this symbol
```

On rerun:

```text
Skipping completed NVDA
Skipping unavailable AIP
```

If StashGamma returns a daily rate-limit error:

```text
429
```

the task stops.

Run it again after the provider's quota resets.

As new Reddit history is imported, additional securities may cross the 5-mention threshold. Rerun the same task periodically:

```bash
bin/rails market_data:backfill_mentioned
```

Existing completed symbols will be skipped.

---

# 7. Per-mention market outcomes

Run:

```bash
bin/rails security_mention_outcomes:calculate
```

Purpose:

```text
one SecurityMention
    ↓
associated MarketBar history
    ↓
SecurityMentionOutcome
```

Each outcome can contain:

```text
market_date
price_at_mention
return_1d
return_3d
return_5d
return_10d
max_gain_10d
max_drawdown_10d
```

Timing rule:

```text
mention before market close
→ same trading day where available

mention after market close
→ next trading day

weekend / holiday
→ next available trading day
```

This task can be run repeatedly.

Mentions without sufficient `MarketBar` data remain without an outcome and can be picked up on a later run.

---

# 8. Daily social signals

Run:

```bash
bin/rails security_daily_signals:build
```

Purpose:

```text
SecurityMention + SocialPost
    ↓
group by ticker + date
    ↓
SecurityDailySignal
```

Each row contains:

```text
security_id
date
mention_count
submission_count
comment_count
unique_author_count
total_score
average_score
```

This turns thousands of individual comments into one useful daily feature row per security.

Example:

```text
NVDA
2024-01-10
mention_count: 184
submission_count: 14
comment_count: 170
unique_author_count: 121
```

This task is safe to run repeatedly.

It uses upserts, so:

```text
new ticker/day
→ create

existing ticker/day
→ update
```

Run this whenever significant new Reddit data has been imported.

---

# 9. Daily market outcomes

Run:

```bash
bin/rails security_daily_outcomes:calculate
```

Purpose:

```text
SecurityDailySignal
    ↓
MarketBar
    ↓
SecurityDailyOutcome
```

Each row contains:

```text
security_id
date
market_date
price_at_signal
return_1d
return_3d
return_5d
return_10d
max_gain_10d
max_drawdown_10d
```

The join key between the social feature layer and market outcome layer is:

```text
security_id + date
```

Run this repeatedly as market data and Reddit history grow.

---

# 10. Export the analysis dataset

Run:

```bash
bin/rails analysis:export_daily_signals
```

Output:

```text
data/analysis/security_daily_dataset.csv
```

Purpose:

```text
SecurityDailySignal
+
SecurityDailyOutcome
    ↓
one modeling/analysis CSV
```

The dataset includes:

```text
symbol
date

mention_count
submission_count
comment_count
unique_author_count
total_score
average_score

market_date
price_at_signal
return_1d
return_3d
return_5d
return_10d
max_gain_10d
max_drawdown_10d
```

Run this after rebuilding signals/outcomes.

---

# 11. Run the baseline analysis

From:

```bash
cd occupy/python/historical_reddit
source .venv/bin/activate
```

run:

```bash
python analyze_daily_signals.py
```

Purpose:

```text
security_daily_dataset.csv
    ↓
basic statistical baseline
```

It currently reports:

```text
dataset size
security count
date range

Pearson correlations
Spearman correlations

mention-volume quintiles
author-breadth quintiles

strongest feature/outcome relationships
```

This is the baseline against which future LLM-derived features and ML models will be compared.

---

# Normal ongoing workflow

While expanding historical Reddit coverage, the practical workflow is:

## Terminal 1 — Reddit history

```bash
cd occupy/python/historical_reddit
source .venv/bin/activate

python download_reddit_history.py \
  --subreddit wallstreetbets \
  --start 2024-02-01 \
  --end 2024-03-01 \
  --type both \
  --delete-raw
```

Let this keep filling the historical social dataset.

## Terminal 2 — Market history

From Rails root:

```bash
bin/rails market_data:backfill_mentioned
```

Run until StashGamma hits its daily limit.

Rerun after the quota resets.

## After substantial new Reddit data arrives

Run:

```bash
bin/rails security_daily_signals:build
```

Then:

```bash
bin/rails security_mention_outcomes:calculate
```

Then:

```bash
bin/rails security_daily_outcomes:calculate
```

Then:

```bash
bin/rails analysis:export_daily_signals
```

Finally:

```bash
cd python/historical_reddit
source .venv/bin/activate
python analyze_daily_signals.py
```

---

# Recommended order from a clean state

If rebuilding everything from scratch:

```text
1. bin/rails security_universe:import

2. python download_reddit_history.py ...

3. bin/rails security_mentions:extract
   Only necessary if mentions were not already extracted during import,
   or if extraction rules changed.

4. bin/rails market_data:backfill_mentioned

5. bin/rails security_daily_signals:build

6. bin/rails security_mention_outcomes:calculate

7. bin/rails security_daily_outcomes:calculate

8. bin/rails analysis:export_daily_signals

9. python analyze_daily_signals.py
```

For normal incremental operation, you do not need to rebuild everything every time.

The recurring loop is:

```text
collect more Reddit
    ↓
backfill newly eligible securities
    ↓
rebuild daily signals
    ↓
calculate missing/revised outcomes
    ↓
export dataset
    ↓
analyze
```

---

# Current purpose of the project

The system is currently designed to answer:

```text
Does social activity around a security contain information
about what that security does afterward?
```

The current baseline features are purely deterministic:

```text
mention volume
submission volume
comment volume
unique authors
score
```

The current outcomes measure:

```text
future direction
future return
future upside
future downside
```

The next major analysis improvements are expected to be:

```text
SPY-relative returns
ticker-relative mention spikes
volatility-focused targets
LLM-derived sentiment/catalyst features
predictive ML models
hypothetical options/trading evaluation
```

The deterministic baseline comes first so we can later measure whether the LLM actually adds predictive value rather than assuming that it does.


# Boards
r/wallstreetbets -
r/stocks — broad individual-stock discussion; useful contrast with WSB.
r/options — directly relevant because your eventual goal includes options behavior.
r/StockMarket — broader market chatter, often more news/reactive.
r/pennystocks — useful for extreme attention/volatility cases.
r/ValueInvesting — slower, fundamentals-driven signal.
r/SecurityAnalysis — more research-heavy discussion.
r/Daytrading — short-horizon trading attention.
r/thetagang — options-selling perspective; potentially different volatility expectations.
r/smallstreetbets — smaller speculative community, closer in behavior to WSB.
r/SPACs — historically useful for concentrated speculative attention, especially in earlier periods.