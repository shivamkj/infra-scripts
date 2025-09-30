-- Table: distributed_samples
CREATE TABLE signoz_meter.distributed_samples
(
    `temporality` LowCardinality(String) DEFAULT 'Unspecified',
    `metric_name` LowCardinality(String),
    `description` LowCardinality(String) DEFAULT 'default',
    `unit` LowCardinality(String) DEFAULT 'default',
    `type` LowCardinality(String) DEFAULT 'default',
    `is_monotonic` Bool DEFAULT false,
    `labels` String CODEC(ZSTD(5)),
    `fingerprint` UInt64 CODEC(Delta(8), ZSTD(1)),
    `unix_milli` Int64 CODEC(DoubleDelta, ZSTD(1)),
    `value` Float64 CODEC(Gorilla(8), ZSTD(1))
)
ENGINE = Distributed('cluster', 'signoz_meter', 'samples', cityHash64(temporality, metric_name, fingerprint))

-- Table: distributed_samples_agg_1d
CREATE TABLE signoz_meter.distributed_samples_agg_1d
(
    `temporality` LowCardinality(String) DEFAULT 'Unspecified',
    `metric_name` LowCardinality(String),
    `description` LowCardinality(String) DEFAULT 'default',
    `unit` LowCardinality(String) DEFAULT 'default',
    `type` LowCardinality(String) DEFAULT 'default',
    `is_monotonic` Bool DEFAULT false,
    `labels` String CODEC(ZSTD(5)),
    `fingerprint` UInt64 CODEC(Delta(8), ZSTD(1)),
    `unix_milli` Int64 CODEC(DoubleDelta, ZSTD(1)),
    `last` SimpleAggregateFunction(anyLast, Float64) CODEC(ZSTD(1)),
    `min` SimpleAggregateFunction(min, Float64) CODEC(ZSTD(1)),
    `max` SimpleAggregateFunction(max, Float64) CODEC(ZSTD(1)),
    `sum` SimpleAggregateFunction(sum, Float64) CODEC(ZSTD(1)),
    `count` SimpleAggregateFunction(sum, UInt64) CODEC(ZSTD(1))
)
ENGINE = Distributed('cluster', 'signoz_meter', 'samples_agg_1d', cityHash64(temporality, metric_name, fingerprint))

-- Table: distributed_schema_migrations_v2
CREATE TABLE signoz_meter.distributed_schema_migrations_v2
(
    `migration_id` UInt64,
    `status` String,
    `error` String,
    `created_at` DateTime64(9),
    `updated_at` DateTime64(9)
)
ENGINE = Distributed('cluster', 'signoz_meter', 'schema_migrations_v2', rand())

-- Table: samples
CREATE TABLE signoz_meter.samples
(
    `temporality` LowCardinality(String) DEFAULT 'Unspecified',
    `metric_name` LowCardinality(String),
    `description` LowCardinality(String) DEFAULT 'default',
    `unit` LowCardinality(String) DEFAULT 'default',
    `type` LowCardinality(String) DEFAULT 'default',
    `is_monotonic` Bool DEFAULT false,
    `labels` String CODEC(ZSTD(5)),
    `fingerprint` UInt64 CODEC(Delta(8), ZSTD(1)),
    `unix_milli` Int64 CODEC(DoubleDelta, ZSTD(1)),
    `value` Float64 CODEC(Gorilla(8), ZSTD(1))
)
ENGINE = MergeTree
PARTITION BY toYYYYMM(toDateTime(intDiv(unix_milli, 1000)))
ORDER BY (temporality, metric_name, fingerprint, toDayOfMonth(toDateTime(intDiv(unix_milli, 1000))))
TTL toDateTime(intDiv(unix_milli, 1000)) + toIntervalYear(1)
SETTINGS index_granularity = 8192, ttl_only_drop_parts = 1

-- Table: samples_agg_1d
CREATE TABLE signoz_meter.samples_agg_1d
(
    `temporality` LowCardinality(String) DEFAULT 'Unspecified',
    `metric_name` LowCardinality(String),
    `description` LowCardinality(String) DEFAULT 'default',
    `unit` LowCardinality(String) DEFAULT 'default',
    `type` LowCardinality(String) DEFAULT 'default',
    `is_monotonic` Bool DEFAULT false,
    `labels` String CODEC(ZSTD(5)),
    `fingerprint` UInt64 CODEC(Delta(8), ZSTD(1)),
    `unix_milli` Int64 CODEC(DoubleDelta, ZSTD(1)),
    `last` SimpleAggregateFunction(anyLast, Float64) CODEC(ZSTD(1)),
    `min` SimpleAggregateFunction(min, Float64) CODEC(ZSTD(1)),
    `max` SimpleAggregateFunction(max, Float64) CODEC(ZSTD(1)),
    `sum` SimpleAggregateFunction(sum, Float64) CODEC(ZSTD(1)),
    `count` SimpleAggregateFunction(sum, UInt64) CODEC(ZSTD(1))
)
ENGINE = AggregatingMergeTree
PARTITION BY toYYYYMM(toDateTime(intDiv(unix_milli, 1000)))
ORDER BY (temporality, metric_name, fingerprint, toDayOfMonth(toDateTime(intDiv(unix_milli, 1000))))
TTL toDateTime(intDiv(unix_milli, 1000)) + toIntervalYear(1)
SETTINGS index_granularity = 8192, ttl_only_drop_parts = 1

-- Table: samples_agg_1d_mv
CREATE MATERIALIZED VIEW signoz_meter.samples_agg_1d_mv TO signoz_meter.samples_agg_1d
(
    `temporality` LowCardinality(String) DEFAULT 'Unspecified',
    `metric_name` LowCardinality(String),
    `description` LowCardinality(String) DEFAULT 'default',
    `unit` LowCardinality(String) DEFAULT 'default',
    `type` LowCardinality(String) DEFAULT 'default',
    `is_monotonic` Bool DEFAULT false,
    `labels` String CODEC(ZSTD(5)),
    `fingerprint` UInt64 CODEC(Delta(8), ZSTD(1)),
    `unix_milli` Int64 CODEC(DoubleDelta, ZSTD(1)),
    `last` SimpleAggregateFunction(anyLast, Float64) CODEC(ZSTD(1)),
    `min` SimpleAggregateFunction(min, Float64) CODEC(ZSTD(1)),
    `max` SimpleAggregateFunction(max, Float64) CODEC(ZSTD(1)),
    `sum` SimpleAggregateFunction(sum, Float64) CODEC(ZSTD(1)),
    `count` SimpleAggregateFunction(sum, UInt64) CODEC(ZSTD(1))
)
AS SELECT
    temporality,
    metric_name,
    description,
    unit,
    type,
    is_monotonic,
    labels,
    fingerprint,
    intDiv(unix_milli, 86400000) * 86400000 AS unix_milli,
    anyLast(value) AS last,
    min(value) AS min,
    max(value) AS max,
    sum(value) AS sum,
    count(*) AS count
FROM signoz_meter.samples
GROUP BY
    temporality,
    metric_name,
    fingerprint,
    description,
    unit,
    type,
    is_monotonic,
    labels,
    unix_milli

-- Table: schema_migrations_v2
CREATE TABLE signoz_meter.schema_migrations_v2
(
    `migration_id` UInt64,
    `status` String,
    `error` String,
    `created_at` DateTime64(9),
    `updated_at` DateTime64(9)
)
ENGINE = ReplacingMergeTree
PRIMARY KEY migration_id
ORDER BY migration_id
SETTINGS index_granularity = 8192

