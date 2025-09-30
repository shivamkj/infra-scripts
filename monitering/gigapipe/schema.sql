-- Table: metrics_15s
CREATE TABLE qryn.metrics_15s
(
    `fingerprint` UInt64,
    `timestamp_ns` Int64 CODEC(DoubleDelta),
    `last` AggregateFunction(argMax, Float64, Int64),
    `max` SimpleAggregateFunction(max, Float64),
    `min` SimpleAggregateFunction(min, Float64),
    `count` AggregateFunction(count),
    `sum` SimpleAggregateFunction(sum, Float64),
    `bytes` SimpleAggregateFunction(sum, Float64),
    `type` UInt8,
    `type_v2` UInt8 ALIAS type
)
ENGINE = AggregatingMergeTree
PARTITION BY toDate(toDateTime(intDiv(timestamp_ns, 1000000000)))
PRIMARY KEY (fingerprint, timestamp_ns)
ORDER BY (fingerprint, timestamp_ns, type)
TTL toDateTime(timestamp_ns / 1000000000) + toIntervalDay(7)
SETTINGS index_granularity = 8192, ttl_only_drop_parts = 1, merge_with_ttl_timeout = 3600

-- Table: metrics_15s_mv
CREATE MATERIALIZED VIEW qryn.metrics_15s_mv TO qryn.metrics_15s
(
    `fingerprint` UInt64,
    `timestamp_ns` Int64,
    `last` AggregateFunction(argMax, Float64, Int64),
    `max` SimpleAggregateFunction(max, Float64),
    `min` SimpleAggregateFunction(min, Float64),
    `count` AggregateFunction(count),
    `sum` SimpleAggregateFunction(sum, Float64),
    `bytes` SimpleAggregateFunction(sum, UInt64),
    `type` UInt8
)
AS SELECT
    fingerprint,
    intDiv(samples.timestamp_ns, 15000000000) * 15000000000 AS timestamp_ns,
    argMaxState(value, samples.timestamp_ns) AS last,
    maxSimpleState(value) AS max,
    minSimpleState(value) AS min,
    countState() AS count,
    sumSimpleState(value) AS sum,
    sumSimpleState(length(string)) AS bytes,
    type
FROM qryn.samples_v3 AS samples
GROUP BY
    fingerprint,
    timestamp_ns,
    type

-- Table: patterns
CREATE TABLE qryn.patterns
(
    `timestamp_10m` UInt32,
    `fingerprint` UInt64,
    `timestamp_s` UInt32,
    `tokens` Array(String),
    `classes` Array(UInt32),
    `overall_cost` UInt32,
    `generalized_cost` UInt32,
    `samples_count` UInt32,
    `pattern_id` UInt64,
    `iteration_id` UInt64
)
ENGINE = MergeTree
PARTITION BY toDate(fromUnixTimestamp(timestamp_10m * 600))
ORDER BY (timestamp_10m, fingerprint)
TTL toDateTime(timestamp_10m * 600) + toIntervalDay(7)
SETTINGS index_granularity = 8192, ttl_only_drop_parts = 1, merge_with_ttl_timeout = 3600

-- Table: profiles
CREATE TABLE qryn.profiles
(
    `timestamp_ns` UInt64 CODEC(DoubleDelta, ZSTD(1)),
    `fingerprint` UInt64 CODEC(DoubleDelta, ZSTD(1)),
    `type_id` LowCardinality(String) CODEC(ZSTD(1)),
    `sample_types_units` Array(Tuple(
        String,
        String)) CODEC(ZSTD(1)),
    `service_name` LowCardinality(String) CODEC(ZSTD(1)),
    `duration_ns` UInt64 CODEC(DoubleDelta, ZSTD(1)),
    `payload_type` LowCardinality(String) CODEC(ZSTD(1)),
    `payload` String CODEC(ZSTD(1)),
    `values_agg` Array(Tuple(
        String,
        Int64,
        Int32)) CODEC(ZSTD(1)),
    `tree` Array(Tuple(
        UInt64,
        UInt64,
        UInt64,
        Array(Tuple(
            String,
            Int64,
            Int64)))),
    `functions` Array(Tuple(
        UInt64,
        String))
)
ENGINE = MergeTree
PARTITION BY toDate(fromUnixTimestamp(intDiv(timestamp_ns, 1000000000)))
ORDER BY (type_id, service_name, timestamp_ns)
SETTINGS index_granularity = 8192

-- Table: profiles_input
CREATE TABLE qryn.profiles_input
(
    `timestamp_ns` UInt64,
    `type` LowCardinality(String),
    `service_name` LowCardinality(String),
    `sample_types_units` Array(Tuple(
        String,
        String)),
    `period_type` LowCardinality(String),
    `period_unit` LowCardinality(String),
    `tags` Array(Tuple(
        String,
        String)),
    `duration_ns` UInt64,
    `payload_type` LowCardinality(String),
    `payload` String,
    `values_agg` Array(Tuple(
        String,
        Int64,
        Int32)) CODEC(ZSTD(1)),
    `tree` Array(Tuple(
        UInt64,
        UInt64,
        UInt64,
        Array(Tuple(
            String,
            Int64,
            Int64)))),
    `functions` Array(Tuple(
        UInt64,
        String))
)
ENGINE = Null

-- Table: profiles_mv
CREATE MATERIALIZED VIEW qryn.profiles_mv TO qryn.profiles
(
    `timestamp_ns` UInt64,
    `fingerprint` UInt64,
    `type_id` String,
    `sample_types_units` Array(Tuple(
        String,
        String)),
    `service_name` LowCardinality(String),
    `duration_ns` UInt64,
    `payload_type` LowCardinality(String),
    `payload` String,
    `values_agg` Array(Tuple(
        String,
        Int64,
        Int32)),
    `tree` Array(Tuple(
        UInt64,
        UInt64,
        UInt64,
        Array(Tuple(
            String,
            Int64,
            Int64)))),
    `functions` Array(Tuple(
        UInt64,
        String))
)
AS SELECT
    timestamp_ns,
    cityHash64(arraySort(arrayConcat(profiles_input.tags, [('__type__', concatWithSeparator(':', type, period_type, period_unit) AS _type_id), ('__sample_types_units__', arrayStringConcat(arrayMap(x -> concat(x.1, ':', x.2), arraySort(sample_types_units)), ';')), ('service_name', service_name)])) AS _tags) AS fingerprint,
    _type_id AS type_id,
    sample_types_units,
    service_name,
    duration_ns,
    payload_type,
    payload,
    values_agg,
    tree,
    functions
FROM qryn.profiles_input

-- Table: profiles_series
CREATE TABLE qryn.profiles_series
(
    `date` Date CODEC(ZSTD(1)),
    `type_id` LowCardinality(String) CODEC(ZSTD(1)),
    `sample_types_units` Array(Tuple(
        String,
        String)) CODEC(ZSTD(1)),
    `service_name` LowCardinality(String) CODEC(ZSTD(1)),
    `fingerprint` UInt64 CODEC(DoubleDelta, ZSTD(1)),
    `tags` Array(Tuple(
        String,
        String)) CODEC(ZSTD(1))
)
ENGINE = ReplacingMergeTree
PARTITION BY date
ORDER BY (date, type_id, fingerprint)
SETTINGS index_granularity = 8192

-- Table: profiles_series_gin
CREATE TABLE qryn.profiles_series_gin
(
    `date` Date CODEC(ZSTD(1)),
    `key` String CODEC(ZSTD(1)),
    `val` String CODEC(ZSTD(1)),
    `type_id` LowCardinality(String) CODEC(ZSTD(1)),
    `sample_types_units` Array(Tuple(
        String,
        String)),
    `service_name` LowCardinality(String) CODEC(ZSTD(1)),
    `fingerprint` UInt64 CODEC(DoubleDelta, ZSTD(1))
)
ENGINE = ReplacingMergeTree
PARTITION BY date
ORDER BY (date, key, val, type_id, fingerprint)
SETTINGS index_granularity = 8192

-- Table: profiles_series_gin_mv
CREATE MATERIALIZED VIEW qryn.profiles_series_gin_mv TO qryn.profiles_series_gin
(
    `date` Date,
    `key` String,
    `val` String,
    `type_id` LowCardinality(String),
    `sample_types_units` Array(Tuple(
        String,
        String)),
    `service_name` LowCardinality(String),
    `fingerprint` UInt64
)
AS SELECT
    date,
    kv.1 AS key,
    kv.2 AS val,
    type_id,
    sample_types_units,
    service_name,
    fingerprint
FROM qryn.profiles_series
ARRAY JOIN tags AS kv

-- Table: profiles_series_keys
CREATE TABLE qryn.profiles_series_keys
(
    `date` Date,
    `key` String,
    `val` String,
    `val_id` UInt64
)
ENGINE = ReplacingMergeTree
PARTITION BY date
ORDER BY (date, key, val_id)
SETTINGS index_granularity = 8192

-- Table: profiles_series_keys_mv
CREATE MATERIALIZED VIEW qryn.profiles_series_keys_mv TO qryn.profiles_series_keys
(
    `date` Date,
    `key` String,
    `val` String,
    `val_id` UInt16
)
AS SELECT
    date,
    key,
    val,
    cityHash64(val) % 50000 AS val_id
FROM qryn.profiles_series_gin

-- Table: profiles_series_mv
CREATE MATERIALIZED VIEW qryn.profiles_series_mv TO qryn.profiles_series
(
    `date` Date,
    `type_id` String,
    `sample_types_units` Array(Tuple(
        String,
        String)),
    `service_name` LowCardinality(String),
    `fingerprint` UInt64,
    `tags` Array(Tuple(
        String,
        String))
)
AS SELECT
    toDate(intDiv(timestamp_ns, 1000000000)) AS date,
    concatWithSeparator(':', type, period_type, period_unit) AS type_id,
    sample_types_units,
    service_name,
    cityHash64(arraySort(arrayConcat(profiles_input.tags, [('__type__', type_id), ('__sample_types_units__', arrayStringConcat(arrayMap(x -> concat(x.1, ':', x.2), arraySort(sample_types_units)), ';')), ('service_name', service_name)])) AS _tags) AS fingerprint,
    arrayConcat(profiles_input.tags, [('service_name', service_name)]) AS tags
FROM qryn.profiles_input

-- Table: samples_read
CREATE TABLE qryn.samples_read
(
    `fingerprint` UInt64,
    `timestamp_ms` Int64,
    `value` Float64,
    `string` String
)
ENGINE = Merge('qryn', '^(samples|samples_v2)$')

-- Table: samples_read_v2_1
CREATE VIEW qryn.samples_read_v2_1
(
    `fingerprint` UInt64,
    `timestamp_ns` Int64,
    `value` Float64,
    `string` String
)
AS SELECT
    fingerprint,
    timestamp_ms * 1000000 AS timestamp_ns,
    value,
    string
FROM qryn.samples_read

-- Table: samples_read_v2_2
CREATE TABLE qryn.samples_read_v2_2
(
    `fingerprint` UInt64,
    `timestamp_ns` Int64,
    `value` Float64,
    `string` String
)
ENGINE = Merge('qryn', '^(samples_read_v2_1|samples_v3)$')

-- Table: samples_v3
CREATE TABLE qryn.samples_v3
(
    `fingerprint` UInt64,
    `timestamp_ns` Int64 CODEC(DoubleDelta),
    `value` Float64 CODEC(Gorilla),
    `string` String,
    `type` UInt8,
    `type_v2` UInt8 ALIAS type
)
ENGINE = MergeTree
PARTITION BY toStartOfDay(toDateTime(timestamp_ns / 1000000000))
ORDER BY timestamp_ns
TTL toDateTime(timestamp_ns / 1000000000) + toIntervalDay(7)
SETTINGS index_granularity = 8192, ttl_only_drop_parts = 1, merge_with_ttl_timeout = 3600

-- Table: settings
CREATE TABLE qryn.settings
(
    `fingerprint` UInt64,
    `type` String,
    `name` String,
    `value` String,
    `inserted_at` DateTime64(9, 'UTC')
)
ENGINE = ReplacingMergeTree(inserted_at)
ORDER BY fingerprint
SETTINGS index_granularity = 8192

-- Table: tempo_traces
CREATE TABLE qryn.tempo_traces
(
    `oid` String DEFAULT '0',
    `trace_id` FixedString(16),
    `span_id` FixedString(8),
    `parent_id` String,
    `name` String,
    `timestamp_ns` Int64 CODEC(DoubleDelta),
    `duration_ns` Int64,
    `service_name` String,
    `payload_type` Int8,
    `payload` String
)
ENGINE = MergeTree
PARTITION BY (oid, toDate(fromUnixTimestamp(intDiv(timestamp_ns, 1000000000))))
ORDER BY (oid, trace_id, timestamp_ns)
TTL toDateTime(timestamp_ns / 1000000000) + toIntervalDay(7)
SETTINGS index_granularity = 8192, ttl_only_drop_parts = 1, merge_with_ttl_timeout = 3600

-- Table: tempo_traces_attrs_gin
CREATE TABLE qryn.tempo_traces_attrs_gin
(
    `oid` String,
    `date` Date,
    `key` String,
    `val` String,
    `trace_id` FixedString(16),
    `span_id` FixedString(8),
    `timestamp_ns` Int64,
    `duration` Int64
)
ENGINE = ReplacingMergeTree
PARTITION BY date
ORDER BY (oid, date, key, val, timestamp_ns, trace_id, span_id)
TTL date + toIntervalDay(7)
SETTINGS index_granularity = 8192, ttl_only_drop_parts = 1, merge_with_ttl_timeout = 3600

-- Table: tempo_traces_kv
CREATE TABLE qryn.tempo_traces_kv
(
    `oid` String,
    `date` Date,
    `key` String,
    `val_id` UInt64,
    `val` String
)
ENGINE = ReplacingMergeTree
PARTITION BY (oid, date)
ORDER BY (oid, date, key, val_id)
TTL date + toIntervalDay(7)
SETTINGS index_granularity = 8192, ttl_only_drop_parts = 1, merge_with_ttl_timeout = 3600

-- Table: tempo_traces_kv_mv
CREATE MATERIALIZED VIEW qryn.tempo_traces_kv_mv TO qryn.tempo_traces_kv
(
    `oid` String,
    `date` Date,
    `key` String,
    `val_id` UInt16,
    `val` String
)
AS SELECT
    oid,
    date,
    key,
    cityHash64(val) % 10000 AS val_id,
    val
FROM qryn.tempo_traces_attrs_gin

-- Table: time_series
CREATE TABLE qryn.time_series
(
    `date` Date,
    `fingerprint` UInt64,
    `labels` String,
    `name` String,
    `type` UInt8,
    `type_v2` UInt8 ALIAS type
)
ENGINE = ReplacingMergeTree(date)
PARTITION BY date
PRIMARY KEY fingerprint
ORDER BY (fingerprint, type)
TTL date + toIntervalDay(7)
SETTINGS index_granularity = 8192, ttl_only_drop_parts = 1, merge_with_ttl_timeout = 3600

-- Table: time_series_gin
CREATE TABLE qryn.time_series_gin
(
    `date` Date,
    `key` String,
    `val` String,
    `fingerprint` UInt64,
    `type` UInt8,
    `type_v2` UInt8 ALIAS type
)
ENGINE = ReplacingMergeTree
PARTITION BY date
PRIMARY KEY (key, val, fingerprint)
ORDER BY (key, val, fingerprint, type)
TTL date + toIntervalDay(7)
SETTINGS index_granularity = 8192, ttl_only_drop_parts = 1, merge_with_ttl_timeout = 3600

-- Table: time_series_gin_view
CREATE MATERIALIZED VIEW qryn.time_series_gin_view TO qryn.time_series_gin
(
    `date` Date,
    `key` String,
    `val` String,
    `fingerprint` UInt64,
    `type` UInt8
)
AS SELECT
    date,
    pairs.1 AS key,
    pairs.2 AS val,
    fingerprint,
    type
FROM qryn.time_series
ARRAY JOIN JSONExtractKeysAndValues(time_series.labels, 'String') AS pairs

-- Table: traces_input
CREATE TABLE qryn.traces_input
(
    `oid` String DEFAULT '0',
    `trace_id` String,
    `span_id` String,
    `parent_id` String,
    `name` String,
    `timestamp_ns` Int64 CODEC(DoubleDelta),
    `duration_ns` Int64,
    `service_name` String,
    `payload_type` Int8,
    `payload` String,
    `tags` Array(Tuple(
        String,
        String))
)
ENGINE = Null

-- Table: traces_input_tags_mv
CREATE MATERIALIZED VIEW qryn.traces_input_tags_mv TO qryn.tempo_traces_attrs_gin
(
    `oid` String,
    `date` Date,
    `key` String,
    `val` String,
    `trace_id` FixedString(16),
    `span_id` FixedString(8),
    `timestamp_ns` Int64,
    `duration` Int64
)
AS SELECT
    oid,
    toDate(intDiv(timestamp_ns, 1000000000)) AS date,
    tags.1 AS key,
    tags.2 AS val,
    CAST(unhex(trace_id), 'FixedString(16)') AS trace_id,
    CAST(unhex(span_id), 'FixedString(8)') AS span_id,
    timestamp_ns,
    duration_ns AS duration
FROM qryn.traces_input
ARRAY JOIN tags

-- Table: traces_input_traces_mv
CREATE MATERIALIZED VIEW qryn.traces_input_traces_mv TO qryn.tempo_traces
(
    `oid` String,
    `trace_id` FixedString(16),
    `span_id` FixedString(8),
    `parent_id` String,
    `name` String,
    `timestamp_ns` Int64,
    `duration_ns` Int64,
    `service_name` String,
    `payload_type` Int8,
    `payload` String
)
AS SELECT
    oid,
    CAST(unhex(trace_id), 'FixedString(16)') AS trace_id,
    CAST(unhex(span_id), 'FixedString(8)') AS span_id,
    unhex(parent_id) AS parent_id,
    name,
    timestamp_ns,
    duration_ns,
    service_name,
    payload_type,
    payload
FROM qryn.traces_input

-- Table: ver
CREATE TABLE qryn.ver
(
    `k` UInt64,
    `ver` UInt64
)
ENGINE = ReplacingMergeTree(ver)
ORDER BY k
SETTINGS index_granularity = 8192

