-- Table: otel_logs
CREATE TABLE default.otel_logs
(
    `Timestamp` DateTime64(9) CODEC(Delta(8), ZSTD(1)),
    `TraceId` String CODEC(ZSTD(1)),
    `SpanId` String CODEC(ZSTD(1)),
    `TraceFlags` UInt32 CODEC(ZSTD(1)),
    `SeverityText` LowCardinality(String) CODEC(ZSTD(1)),
    `SeverityNumber` Int32 CODEC(ZSTD(1)),
    `ServiceName` LowCardinality(String) CODEC(ZSTD(1)),
    `Body` String CODEC(ZSTD(1)),
    `ResourceAttributes` Map(LowCardinality(String), String) CODEC(ZSTD(1)),
    `LogAttributes` Map(LowCardinality(String), String) CODEC(ZSTD(1)),
    INDEX idx_trace_id TraceId TYPE bloom_filter(0.001) GRANULARITY 1,
    INDEX idx_res_attr_key mapKeys(ResourceAttributes) TYPE bloom_filter(0.01) GRANULARITY 1,
    INDEX idx_res_attr_value mapValues(ResourceAttributes) TYPE bloom_filter(0.01) GRANULARITY 1,
    INDEX idx_log_attr_key mapKeys(LogAttributes) TYPE bloom_filter(0.01) GRANULARITY 1,
    INDEX idx_log_attr_value mapValues(LogAttributes) TYPE bloom_filter(0.01) GRANULARITY 1,
    INDEX idx_body Body TYPE tokenbf_v1(32768, 3, 0) GRANULARITY 1
)
ENGINE = MergeTree
PARTITION BY toDate(Timestamp)
ORDER BY (ServiceName, SeverityText, toUnixTimestamp(Timestamp), TraceId)
TTL toDateTime(Timestamp) + toIntervalSecond(604800)
SETTINGS index_granularity = 8192, ttl_only_drop_parts = 1

-- Table: otel_logs_service_name_severity_text
CREATE TABLE default.otel_logs_service_name_severity_text
(
    `ServiceName` LowCardinality(String) CODEC(ZSTD(1)),
    `SeverityText` LowCardinality(String) CODEC(ZSTD(1)),
    `LastSeen` DateTime64(9) CODEC(Delta(8), ZSTD(1))
)
ENGINE = ReplacingMergeTree
PARTITION BY toDate(LastSeen)
PRIMARY KEY (ServiceName, SeverityText)
ORDER BY (ServiceName, SeverityText)
TTL toDateTime(LastSeen) + toIntervalSecond(604800)
SETTINGS index_granularity = 8192

-- Table: otel_logs_service_name_severity_text_mv
CREATE MATERIALIZED VIEW default.otel_logs_service_name_severity_text_mv TO default.otel_logs_service_name_severity_text
(
    `ServiceName` LowCardinality(String),
    `SeverityText` LowCardinality(String),
    `LastSeen` DateTime64(9)
)
AS SELECT
    ServiceName,
    SeverityText,
    max(Timestamp) AS LastSeen
FROM default.otel_logs
GROUP BY
    ServiceName,
    SeverityText

-- Table: otel_traces
CREATE TABLE default.otel_traces
(
    `Timestamp` DateTime64(9) CODEC(Delta(8), ZSTD(1)),
    `TraceId` String CODEC(ZSTD(1)),
    `SpanId` String CODEC(ZSTD(1)),
    `ParentSpanId` String CODEC(ZSTD(1)),
    `TraceState` String CODEC(ZSTD(1)),
    `SpanName` LowCardinality(String) CODEC(ZSTD(1)),
    `SpanKind` LowCardinality(String) CODEC(ZSTD(1)),
    `ServiceName` LowCardinality(String) CODEC(ZSTD(1)),
    `ResourceAttributes` Map(LowCardinality(String), String) CODEC(ZSTD(1)),
    `SpanAttributes` Map(LowCardinality(String), String) CODEC(ZSTD(1)),
    `Duration` Int64 CODEC(ZSTD(1)),
    `StatusCode` LowCardinality(String) CODEC(ZSTD(1)),
    `StatusMessage` String CODEC(ZSTD(1)),
    `Events.Timestamp` Array(DateTime64(9)) CODEC(ZSTD(1)),
    `Events.Name` Array(LowCardinality(String)) CODEC(ZSTD(1)),
    `Events.Attributes` Array(Map(LowCardinality(String), String)) CODEC(ZSTD(1)),
    `Links.TraceId` Array(String) CODEC(ZSTD(1)),
    `Links.SpanId` Array(String) CODEC(ZSTD(1)),
    `Links.TraceState` Array(String) CODEC(ZSTD(1)),
    `Links.Attributes` Array(Map(LowCardinality(String), String)) CODEC(ZSTD(1)),
    `NetSockPeerAddr` LowCardinality(String) MATERIALIZED SpanAttributes['net.sock.peer.addr'] CODEC(ZSTD(1)),
    INDEX idx_trace_id TraceId TYPE bloom_filter(0.001) GRANULARITY 1,
    INDEX idx_res_attr_key mapKeys(ResourceAttributes) TYPE bloom_filter(0.01) GRANULARITY 1,
    INDEX idx_res_attr_value mapValues(ResourceAttributes) TYPE bloom_filter(0.01) GRANULARITY 1,
    INDEX idx_span_attr_key mapKeys(SpanAttributes) TYPE bloom_filter(0.01) GRANULARITY 1,
    INDEX idx_span_attr_value mapValues(SpanAttributes) TYPE bloom_filter(0.01) GRANULARITY 1,
    INDEX idx_duration Duration TYPE minmax GRANULARITY 1
)
ENGINE = MergeTree
PARTITION BY toDate(Timestamp)
ORDER BY (ServiceName, SpanName, toUnixTimestamp(Timestamp), TraceId)
TTL toDateTime(Timestamp) + toIntervalSecond(604800)
SETTINGS index_granularity = 8192, ttl_only_drop_parts = 1

-- Table: otel_traces_service_name
CREATE TABLE default.otel_traces_service_name
(
    `ServiceName` LowCardinality(String) CODEC(ZSTD(1)),
    `LastSeen` DateTime64(9) CODEC(Delta(8), ZSTD(1))
)
ENGINE = ReplacingMergeTree
PARTITION BY toDate(LastSeen)
PRIMARY KEY ServiceName
ORDER BY ServiceName
TTL toDateTime(LastSeen) + toIntervalSecond(604800)
SETTINGS index_granularity = 8192

-- Table: otel_traces_service_name_mv
CREATE MATERIALIZED VIEW default.otel_traces_service_name_mv TO default.otel_traces_service_name
(
    `ServiceName` LowCardinality(String),
    `LastSeen` DateTime64(9)
)
AS SELECT
    ServiceName,
    max(Timestamp) AS LastSeen
FROM default.otel_traces
GROUP BY ServiceName

-- Table: otel_traces_trace_id_ts
CREATE TABLE default.otel_traces_trace_id_ts
(
    `TraceId` String CODEC(ZSTD(1)),
    `Start` DateTime64(9) CODEC(Delta(8), ZSTD(1)),
    `End` DateTime64(9) CODEC(Delta(8), ZSTD(1)),
    INDEX idx_trace_id TraceId TYPE bloom_filter(0.01) GRANULARITY 1
)
ENGINE = MergeTree
ORDER BY (TraceId, toUnixTimestamp(Start))
TTL toDateTime(Start) + toIntervalSecond(604800)
SETTINGS index_granularity = 8192

-- Table: otel_traces_trace_id_ts_mv
CREATE MATERIALIZED VIEW default.otel_traces_trace_id_ts_mv TO default.otel_traces_trace_id_ts
(
    `TraceId` String,
    `Start` DateTime64(9),
    `End` DateTime64(9)
)
AS SELECT
    TraceId,
    min(Timestamp) AS Start,
    max(Timestamp) AS End
FROM default.otel_traces
WHERE TraceId != ''
GROUP BY TraceId

-- Table: profiling_profiles
CREATE TABLE default.profiling_profiles
(
    `ServiceName` LowCardinality(String) CODEC(ZSTD(1)),
    `Type` LowCardinality(String) CODEC(ZSTD(1)),
    `LastSeen` DateTime64(9) CODEC(Delta(8), ZSTD(1))
)
ENGINE = ReplacingMergeTree
PARTITION BY toDate(LastSeen)
PRIMARY KEY (ServiceName, Type)
ORDER BY (ServiceName, Type)
TTL toDateTime(LastSeen) + toIntervalSecond(604800)
SETTINGS index_granularity = 8192

-- Table: profiling_profiles_mv
CREATE MATERIALIZED VIEW default.profiling_profiles_mv TO default.profiling_profiles
(
    `ServiceName` LowCardinality(String),
    `Type` LowCardinality(String),
    `LastSeen` DateTime64(9)
)
AS SELECT
    ServiceName,
    Type,
    max(End) AS LastSeen
FROM default.profiling_samples
GROUP BY
    ServiceName,
    Type

-- Table: profiling_samples
CREATE TABLE default.profiling_samples
(
    `ServiceName` LowCardinality(String) CODEC(ZSTD(1)),
    `Type` LowCardinality(String) CODEC(ZSTD(1)),
    `Start` DateTime64(9) CODEC(Delta(8), ZSTD(1)),
    `End` DateTime64(9) CODEC(Delta(8), ZSTD(1)),
    `Labels` Map(LowCardinality(String), String) CODEC(ZSTD(1)),
    `StackHash` UInt64 CODEC(ZSTD(1)),
    `Value` Int64 CODEC(ZSTD(1))
)
ENGINE = MergeTree
PARTITION BY toDate(Start)
ORDER BY (ServiceName, Type, toUnixTimestamp(Start), toUnixTimestamp(End))
TTL toDateTime(Start) + toIntervalSecond(604800)
SETTINGS index_granularity = 8192

-- Table: profiling_stacks
CREATE TABLE default.profiling_stacks
(
    `ServiceName` LowCardinality(String) CODEC(ZSTD(1)),
    `Hash` UInt64 CODEC(ZSTD(1)),
    `LastSeen` DateTime64(9) CODEC(Delta(8), ZSTD(1)),
    `Stack` Array(String) CODEC(ZSTD(1))
)
ENGINE = ReplacingMergeTree
PARTITION BY toDate(LastSeen)
PRIMARY KEY (ServiceName, Hash)
ORDER BY (ServiceName, Hash)
TTL toDateTime(LastSeen) + toIntervalSecond(604800)
SETTINGS index_granularity = 8192

