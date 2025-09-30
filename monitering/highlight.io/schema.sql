-- Table: .inner_id.4faaaed7-631c-4da1-80eb-35f8e72c8987

-- Table: .inner_id.d08c67f2-343f-409f-908d-db47ad0feac0

-- Table: alert_state_changes
CREATE TABLE default.alert_state_changes
(
    `Timestamp` DateTime64(6),
    `ProjectID` UInt32,
    `AlertID` UInt32,
    `State` LowCardinality(String),
    `PreviousState` LowCardinality(String),
    `Title` String,
    `GroupByKey` String
)
ENGINE = MergeTree
ORDER BY (ProjectID, AlertID, toUnixTimestamp(Timestamp))
SETTINGS index_granularity = 8192

-- Table: error_groups
CREATE TABLE default.error_groups
(
    `ProjectID` Int32,
    `CreatedAt` DateTime64(6),
    `UpdatedAt` DateTime64(6),
    `ID` Int64,
    `Event` String,
    `Status` LowCardinality(String),
    `Type` LowCardinality(String),
    `ErrorTagID` Nullable(Int64),
    `ErrorTagTitle` Nullable(String),
    `ErrorTagDescription` Nullable(String),
    `SecureID` String
)
ENGINE = ReplacingMergeTree(UpdatedAt)
ORDER BY (ProjectID, CreatedAt, ID)
SETTINGS index_granularity = 8192

-- Table: error_objects
CREATE TABLE default.error_objects
(
    `ProjectID` Int32,
    `Timestamp` DateTime64(6),
    `ID` Int64,
    `ErrorGroupID` Int64,
    `Browser` String,
    `Environment` String,
    `OSName` String,
    `VisitedURL` String,
    `ServiceName` String,
    `ServiceVersion` String,
    `ClientID` String,
    `HasSession` Bool,
    `TraceID` String,
    `SecureSessionID` String
)
ENGINE = ReplacingMergeTree
ORDER BY (ProjectID, Timestamp, ID)
SETTINGS index_granularity = 8192

-- Table: errors_joined_vw
CREATE VIEW default.errors_joined_vw
(
    `ProjectId` Int32,
    `ProjectID` Int32,
    `Timestamp` DateTime64(6),
    `ID` Int64,
    `ErrorGroupID` Int64,
    `Browser` String,
    `Environment` String,
    `OSName` String,
    `VisitedURL` String,
    `ServiceName` String,
    `ServiceVersion` String,
    `ClientID` String,
    `HasSession` Bool,
    `TraceID` String,
    `SecureSessionID` String,
    `eg.ProjectID` Int32,
    `CreatedAt` DateTime64(6),
    `UpdatedAt` DateTime64(6),
    `eg.ID` Int64,
    `Event` String,
    `Status` LowCardinality(String),
    `Type` LowCardinality(String),
    `ErrorTagID` Nullable(Int64),
    `ErrorTagTitle` Nullable(String),
    `ErrorTagDescription` Nullable(String),
    `SecureID` String
)
AS SELECT
    ProjectID AS ProjectId,
    *
FROM default.error_objects AS eo
FINAL
INNER JOIN
(
    SELECT *
    FROM default.error_groups
    FINAL
) AS eg ON (eg.ID = eo.ErrorGroupID) AND (eg.ProjectID = eo.ProjectID)

-- Table: event_attributes_new_mv
CREATE MATERIALIZED VIEW default.event_attributes_new_mv TO default.event_key_values_new
(
    `ProjectId` UInt32,
    `Event` String,
    `Key` String,
    `Day` DateTime,
    `Value` String,
    `Count` UInt64
)
AS SELECT
    ProjectID AS ProjectId,
    Event,
    arrayJoin(Attributes).1 AS Key,
    toStartOfDay(Timestamp) AS Day,
    arrayJoin(Attributes).2 AS Value,
    count() AS Count
FROM default.session_events
WHERE (Key NOT IN ('browser_name', 'browser_version', 'city', 'country', 'environment', 'event', 'first_session', 'identified', 'identifier', 'ip', 'os_name', 'os_version', 'secure_session_id', 'service_version', 'session_active_length', 'session_length', 'session_pages_visited', 'state')) AND (Value != '')
GROUP BY
    ProjectId,
    Event,
    Key,
    Day,
    Value

-- Table: event_event_name_new_mv
CREATE MATERIALIZED VIEW default.event_event_name_new_mv TO default.event_key_values_new
(
    `ProjectId` Int32,
    `Event` String,
    `Key` LowCardinality(String),
    `Day` DateTime,
    `Value` String,
    `Count` UInt64
)
AS SELECT
    ProjectID AS ProjectId,
    Event,
    'event' AS Key,
    toStartOfDay(Timestamp) AS Day,
    Event AS Value,
    count() AS Count
FROM default.session_events
WHERE Event != ''
GROUP BY
    ProjectId,
    Event,
    Key,
    Day,
    Value

-- Table: event_key_values_new
CREATE TABLE default.event_key_values_new
(
    `ProjectId` Int32,
    `Event` LowCardinality(String),
    `Key` LowCardinality(String),
    `Day` DateTime,
    `Value` String,
    `Count` UInt64
)
ENGINE = SummingMergeTree
ORDER BY (ProjectId, Event, Key, Day, Value)
SETTINGS index_granularity = 8192

-- Table: event_keys_new
CREATE TABLE default.event_keys_new
(
    `ProjectId` Int32,
    `Event` LowCardinality(String),
    `Key` LowCardinality(String),
    `Day` DateTime,
    `Count` UInt64,
    `Type` String
)
ENGINE = SummingMergeTree
ORDER BY (ProjectId, Event, Key, Day)
SETTINGS index_granularity = 8192

-- Table: event_keys_new_mv
CREATE MATERIALIZED VIEW default.event_keys_new_mv TO default.event_keys_new
(
    `ProjectId` Int32,
    `Event` LowCardinality(String),
    `Key` LowCardinality(String),
    `Day` DateTime,
    `Type` LowCardinality(String),
    `Count` UInt64
)
AS SELECT
    ProjectId,
    Event,
    Key,
    Day,
    if(toFloat64OrNull(Value) IS NULL, 'String', 'Numeric') AS Type,
    sum(Count) AS Count
FROM default.event_key_values_new
GROUP BY
    ProjectId,
    Event,
    Key,
    Day,
    Type

-- Table: event_session_fields_new_mv
CREATE MATERIALIZED VIEW default.event_session_fields_new_mv TO default.event_key_values_new
(
    `ProjectId` Int32,
    `Event` String,
    `Key` LowCardinality(String),
    `Day` DateTime,
    `Value` String,
    `Count` UInt64
)
AS SELECT
    ProjectID AS ProjectId,
    '' AS Event,
    Name AS Key,
    toStartOfDay(SessionCreatedAt) AS Day,
    Value AS Value,
    count() AS Count
FROM default.fields
WHERE Name IN ('browser_name', 'browser_version', 'city', 'country', 'environment', 'identifier', 'ip', 'os_name', 'os_version', 'secure_session_id', 'service_version')
GROUP BY
    ProjectId,
    Event,
    Key,
    Day,
    Value

-- Table: fields
CREATE TABLE default.fields
(
    `ProjectID` Int32,
    `Type` LowCardinality(String),
    `Name` LowCardinality(String),
    `SessionCreatedAt` DateTime64(6),
    `SessionID` Int64,
    `Value` String,
    `Timestamp` DateTime64(6)
)
ENGINE = ReplacingMergeTree
ORDER BY (ProjectID, Type, Name, SessionCreatedAt, SessionID, Value)
SETTINGS index_granularity = 8192

-- Table: log_attributes
CREATE TABLE default.log_attributes
(
    `ProjectId` Int32,
    `Key` LowCardinality(String),
    `LogTimestamp` DateTime,
    `LogUUID` UUID,
    `Value` String
)
ENGINE = ReplacingMergeTree
ORDER BY (ProjectId, Key, LogTimestamp, LogUUID, Value)
TTL LogTimestamp + toIntervalDay(30)
SETTINGS index_granularity = 8192

-- Table: log_attributes_mv
CREATE MATERIALIZED VIEW default.log_attributes_mv TO default.log_attributes
(
    `ProjectId` UInt32,
    `Key` String,
    `LogTimestamp` DateTime,
    `LogUUID` UUID,
    `Value` String
)
AS SELECT
    ProjectId AS ProjectId,
    arrayJoin(LogAttributes).1 AS Key,
    Timestamp AS LogTimestamp,
    UUID AS LogUUID,
    arrayJoin(LogAttributes).2 AS Value
FROM default.logs
WHERE (Key NOT IN ('level', 'secure_session_id', 'service_name', 'service_version', 'source', 'span_id', 'trace_id', 'message')) AND (Value != '')

-- Table: log_count_daily_mv
CREATE MATERIALIZED VIEW default.log_count_daily_mv
(
    `ProjectId` UInt32,
    `Day` DateTime,
    `Count` UInt64
)
ENGINE = SummingMergeTree
PARTITION BY toDate(Day)
ORDER BY (ProjectId, Day)
SETTINGS index_granularity = 8192
AS SELECT
    ProjectId,
    toStartOfDay(Timestamp) AS Day,
    count() AS Count
FROM default.logs
GROUP BY
    ProjectId,
    Day

-- Table: log_environment_mv
CREATE MATERIALIZED VIEW default.log_environment_mv TO default.log_attributes
(
    `ProjectId` UInt32,
    `Key` String,
    `LogTimestamp` DateTime,
    `LogUUID` UUID,
    `Value` String
)
AS SELECT
    ProjectId AS ProjectId,
    'environment' AS Key,
    Timestamp AS LogTimestamp,
    UUID AS LogUUID,
    Environment AS Value
FROM default.logs
WHERE Environment != ''

-- Table: log_key_values
CREATE TABLE default.log_key_values
(
    `ProjectId` Int32,
    `Key` LowCardinality(String),
    `Day` DateTime,
    `Value` String,
    `Count` UInt64
)
ENGINE = SummingMergeTree
ORDER BY (ProjectId, Key, Day, Value)
TTL Day + toIntervalDay(31)
SETTINGS index_granularity = 8192

-- Table: log_key_values_mv
CREATE MATERIALIZED VIEW default.log_key_values_mv TO default.log_key_values
(
    `ProjectId` Int32,
    `Key` LowCardinality(String),
    `Day` DateTime,
    `Value` String,
    `Count` UInt64
)
AS SELECT
    ProjectId AS ProjectId,
    Key,
    toStartOfDay(LogTimestamp) AS Day,
    Value,
    count() AS Count
FROM default.log_attributes
GROUP BY
    ProjectId,
    Key,
    Day,
    Value

-- Table: log_keys
CREATE TABLE default.log_keys
(
    `ProjectId` Int32,
    `Key` LowCardinality(String),
    `Day` DateTime,
    `Count` UInt64,
    `Type` LowCardinality(String)
)
ENGINE = SummingMergeTree
ORDER BY (ProjectId, Key, Day)
TTL Day + toIntervalDay(31)
SETTINGS index_granularity = 8192

-- Table: log_keys_mv
CREATE MATERIALIZED VIEW default.log_keys_mv TO default.log_keys
(
    `ProjectId` Int32,
    `Key` LowCardinality(String),
    `Day` DateTime,
    `Count` UInt64,
    `Type` String
)
AS SELECT
    ProjectId,
    Key,
    Day,
    sum(Count) AS Count,
    if(toFloat64OrNull(Value) IS NULL, 'String', 'Numeric') AS Type
FROM default.log_key_values
GROUP BY
    ProjectId,
    Key,
    Day,
    toFloat64OrNull(Value) IS NULL

-- Table: log_service_name_mv
CREATE MATERIALIZED VIEW default.log_service_name_mv TO default.log_attributes
(
    `ProjectId` UInt32,
    `Key` String,
    `LogTimestamp` DateTime,
    `LogUUID` UUID,
    `Value` String
)
AS SELECT
    ProjectId AS ProjectId,
    'service_name' AS Key,
    Timestamp AS LogTimestamp,
    UUID AS LogUUID,
    ServiceName AS Value
FROM default.logs
WHERE ServiceName != ''

-- Table: log_service_version_mv
CREATE MATERIALIZED VIEW default.log_service_version_mv TO default.log_attributes
(
    `ProjectId` UInt32,
    `Key` String,
    `LogTimestamp` DateTime,
    `LogUUID` UUID,
    `Value` String
)
AS SELECT
    ProjectId AS ProjectId,
    'service_version' AS Key,
    Timestamp AS LogTimestamp,
    UUID AS LogUUID,
    ServiceVersion AS Value
FROM default.logs
WHERE ServiceVersion != ''

-- Table: log_severity_text_mv
CREATE MATERIALIZED VIEW default.log_severity_text_mv TO default.log_attributes
(
    `ProjectId` UInt32,
    `Key` String,
    `LogTimestamp` DateTime,
    `LogUUID` UUID,
    `Value` String
)
AS SELECT
    ProjectId AS ProjectId,
    'level' AS Key,
    Timestamp AS LogTimestamp,
    UUID AS LogUUID,
    SeverityText AS Value
FROM default.logs
WHERE SeverityText != ''

-- Table: log_source_mv
CREATE MATERIALIZED VIEW default.log_source_mv TO default.log_attributes
(
    `ProjectId` UInt32,
    `Key` String,
    `LogTimestamp` DateTime,
    `LogUUID` UUID,
    `Value` String
)
AS SELECT
    ProjectId AS ProjectId,
    'source' AS Key,
    Timestamp AS LogTimestamp,
    UUID AS LogUUID,
    Source AS Value
FROM default.logs
WHERE Source != ''

-- Table: logs
CREATE TABLE default.logs
(
    `Timestamp` DateTime,
    `UUID` UUID,
    `TraceId` String,
    `SpanId` String,
    `TraceFlags` UInt32,
    `SeverityText` LowCardinality(String),
    `SeverityNumber` Int32,
    `ServiceName` LowCardinality(String),
    `Body` String,
    `LogAttributes` Map(LowCardinality(String), String),
    `ProjectId` UInt32,
    `SecureSessionId` String,
    `Source` String,
    `ServiceVersion` String,
    `Environment` String,
    INDEX idx_trace_id TraceId TYPE bloom_filter GRANULARITY 1,
    INDEX idx_secure_session_id SecureSessionId TYPE bloom_filter GRANULARITY 1,
    INDEX idx_log_attr_key mapKeys(LogAttributes) TYPE bloom_filter GRANULARITY 1,
    INDEX idx_log_attr_value mapValues(LogAttributes) TYPE bloom_filter GRANULARITY 1,
    INDEX idx_body Body TYPE tokenbf_v1(32768, 3, 0) GRANULARITY 1
)
ENGINE = MergeTree
PARTITION BY toDate(Timestamp)
ORDER BY (ProjectId, Timestamp, UUID)
TTL Timestamp + toIntervalDay(30)
SETTINGS ttl_only_drop_parts = 1, index_granularity = 8192, allow_experimental_block_number_column = true

-- Table: logs_sampling
CREATE TABLE default.logs_sampling
(
    `Timestamp` DateTime,
    `UUID` UUID,
    `TraceId` String,
    `SpanId` String,
    `TraceFlags` UInt32,
    `SeverityText` LowCardinality(String),
    `SeverityNumber` Int32,
    `ServiceName` LowCardinality(String),
    `Body` String,
    `LogAttributes` Map(LowCardinality(String), String),
    `ProjectId` UInt32,
    `SecureSessionId` String,
    `Source` String,
    `ServiceVersion` String,
    `Environment` String
)
ENGINE = MergeTree
ORDER BY (ProjectId, toStartOfDay(Timestamp), cityHash64(UUID))
SAMPLE BY cityHash64(UUID)
TTL Timestamp + toIntervalDay(30)
SETTINGS index_granularity = 8192

-- Table: logs_sampling_mv
CREATE MATERIALIZED VIEW default.logs_sampling_mv TO default.logs_sampling
(
    `Timestamp` DateTime,
    `UUID` UUID,
    `TraceId` String,
    `SpanId` String,
    `TraceFlags` UInt32,
    `SeverityText` LowCardinality(String),
    `SeverityNumber` Int32,
    `ServiceName` LowCardinality(String),
    `Body` String,
    `LogAttributes` Map(LowCardinality(String), String),
    `ProjectId` UInt32,
    `SecureSessionId` String,
    `Source` String,
    `ServiceVersion` String
)
AS SELECT *
FROM default.logs

-- Table: metric_attributes_mv
CREATE MATERIALIZED VIEW default.metric_attributes_mv TO default.metric_key_values
(
    `ProjectId` UInt32,
    `Key` String,
    `Day` DateTime,
    `Value` String,
    `Count` UInt64
)
AS SELECT
    ProjectId,
    Attributes.1 AS Key,
    toStartOfDay(Timestamp) AS Day,
    Attributes.2 AS Value,
    count() AS Count
FROM default.metrics
ARRAY JOIN Attributes
WHERE (Key NOT IN ('metric_name', 'service_name', 'secure_session_id', 'trace_id', 'span_id')) AND (Value != '')
GROUP BY ALL

-- Table: metric_count_daily_mv
CREATE TABLE default.metric_count_daily_mv
(
    `ProjectId` UInt32,
    `Day` DateTime,
    `ServiceName` LowCardinality(String),
    `MetricName` String,
    `Count` UInt64
)
ENGINE = SummingMergeTree
ORDER BY (ProjectId, Day, ServiceName, MetricName)
SETTINGS index_granularity = 8192

-- Table: metric_count_daily_mv_histogram
CREATE MATERIALIZED VIEW default.metric_count_daily_mv_histogram TO default.metric_count_daily_mv
(
    `ProjectId` UInt32,
    `Day` DateTime,
    `ServiceName` LowCardinality(String),
    `MetricName` String,
    `Count` UInt64
)
AS SELECT
    ProjectId,
    toStartOfDay(Timestamp) AS Day,
    ServiceName,
    MetricName,
    count() AS Count
FROM default.metrics_histogram
GROUP BY
    ProjectId,
    Day,
    ServiceName,
    MetricName

-- Table: metric_count_daily_mv_sum
CREATE MATERIALIZED VIEW default.metric_count_daily_mv_sum TO default.metric_count_daily_mv
(
    `ProjectId` UInt32,
    `Day` DateTime,
    `ServiceName` LowCardinality(String),
    `MetricName` String,
    `Count` UInt64
)
AS SELECT
    ProjectId,
    toStartOfDay(Timestamp) AS Day,
    ServiceName,
    MetricName,
    count() AS Count
FROM default.metrics_sum
GROUP BY
    ProjectId,
    Day,
    ServiceName,
    MetricName

-- Table: metric_count_daily_mv_summary
CREATE MATERIALIZED VIEW default.metric_count_daily_mv_summary TO default.metric_count_daily_mv
(
    `ProjectId` UInt32,
    `Day` DateTime,
    `ServiceName` LowCardinality(String),
    `MetricName` String,
    `Count` UInt64
)
AS SELECT
    ProjectId,
    toStartOfDay(Timestamp) AS Day,
    ServiceName,
    MetricName,
    count() AS Count
FROM default.metrics_summary
GROUP BY
    ProjectId,
    Day,
    ServiceName,
    MetricName

-- Table: metric_history
CREATE TABLE default.metric_history
(
    `MetricId` UUID,
    `Timestamp` DateTime,
    `GroupByKey` String,
    `MaxBlockNumberState` AggregateFunction(max, UInt64),
    `CountState` AggregateFunction(count, UInt64),
    `UniqState` AggregateFunction(uniq, String),
    `MinState` AggregateFunction(min, Float64),
    `AvgState` AggregateFunction(avg, Float64),
    `MaxState` AggregateFunction(max, Float64),
    `SumState` AggregateFunction(sum, Float64),
    `P50State` AggregateFunction(quantile(0.5), Float64),
    `P90State` AggregateFunction(quantile(0.9), Float64),
    `P95State` AggregateFunction(quantile(0.95), Float64),
    `P99State` AggregateFunction(quantile(0.99), Float64)
)
ENGINE = AggregatingMergeTree
ORDER BY (MetricId, Timestamp, GroupByKey)
SETTINGS index_granularity = 8192

-- Table: metric_key_values
CREATE TABLE default.metric_key_values
(
    `ProjectId` Int32,
    `Key` LowCardinality(String),
    `Day` DateTime,
    `Value` String,
    `Count` UInt64
)
ENGINE = SummingMergeTree
ORDER BY (ProjectId, Key, Day, Value)
TTL Day + toIntervalDay(31)
SETTINGS index_granularity = 8192

-- Table: metric_keys
CREATE TABLE default.metric_keys
(
    `ProjectId` Int32,
    `Key` LowCardinality(String),
    `Day` DateTime,
    `Type` LowCardinality(String),
    `Count` UInt64
)
ENGINE = SummingMergeTree
ORDER BY (ProjectId, Key, Day, Type)
TTL Day + toIntervalDay(31)
SETTINGS index_granularity = 8192

-- Table: metric_keys_mv
CREATE MATERIALIZED VIEW default.metric_keys_mv TO default.metric_keys
(
    `ProjectId` Int32,
    `Key` LowCardinality(String),
    `Day` DateTime,
    `Type` String,
    `Count` UInt64
)
AS SELECT
    ProjectId,
    Key,
    Day,
    if(toFloat64OrNull(Value) IS NULL, 'String', 'Numeric') AS Type,
    sum(Count) AS Count
FROM default.metric_key_values
GROUP BY ALL

-- Table: metric_metric_name_mv
CREATE MATERIALIZED VIEW default.metric_metric_name_mv TO default.metric_key_values
(
    `ProjectId` UInt32,
    `Key` String,
    `Day` DateTime,
    `Value` String,
    `Count` UInt64
)
AS SELECT
    ProjectId,
    'metric_name' AS Key,
    toStartOfDay(Timestamp) AS Day,
    MetricName AS Value,
    count() AS Count
FROM default.metrics
WHERE MetricName != ''
GROUP BY ALL

-- Table: metric_secure_session_id_mv
CREATE MATERIALIZED VIEW default.metric_secure_session_id_mv TO default.metric_key_values
(
    `ProjectId` UInt32,
    `Key` String,
    `Day` DateTime,
    `Value` String,
    `Count` UInt64
)
AS SELECT
    ProjectId,
    'secure_session_id' AS Key,
    toStartOfDay(Timestamp) AS Day,
    Exemplars.SecureSessionID AS Value,
    count() AS Count
FROM default.metrics
ARRAY JOIN `Exemplars.SecureSessionID`
WHERE `Exemplars.SecureSessionID` != ''
GROUP BY ALL

-- Table: metric_service_name_mv
CREATE MATERIALIZED VIEW default.metric_service_name_mv TO default.metric_key_values
(
    `ProjectId` UInt32,
    `Key` String,
    `Day` DateTime,
    `Value` String,
    `Count` UInt64
)
AS SELECT
    ProjectId,
    'service_name' AS Key,
    toStartOfDay(Timestamp) AS Day,
    ServiceName AS Value,
    count() AS Count
FROM default.metrics
WHERE ServiceName != ''
GROUP BY ALL

-- Table: metric_span_id_mv
CREATE MATERIALIZED VIEW default.metric_span_id_mv TO default.metric_key_values
(
    `ProjectId` UInt32,
    `Key` String,
    `Day` DateTime,
    `Value` String,
    `Count` UInt64
)
AS SELECT
    ProjectId,
    'span_id' AS Key,
    toStartOfDay(Timestamp) AS Day,
    `Exemplars.SpanID` AS Value,
    count() AS Count
FROM default.metrics
ARRAY JOIN `Exemplars.SpanID`
WHERE `Exemplars.SpanID` != ''
GROUP BY ALL

-- Table: metric_trace_id_mv
CREATE MATERIALIZED VIEW default.metric_trace_id_mv TO default.metric_key_values
(
    `ProjectId` UInt32,
    `Key` String,
    `Day` DateTime,
    `Value` String,
    `Count` UInt64
)
AS SELECT
    ProjectId,
    'trace_id' AS Key,
    toStartOfDay(Timestamp) AS Day,
    `Exemplars.TraceID` AS Value,
    count() AS Count
FROM default.metrics
ARRAY JOIN `Exemplars.TraceID`
WHERE `Exemplars.TraceID` != ''
GROUP BY ALL

-- Table: metrics
CREATE TABLE default.metrics
(
    `ProjectId` UInt32,
    `ServiceName` String,
    `MetricName` String,
    `MetricType` Enum8('Empty' = 0, 'Gauge' = 1, 'Sum' = 2, 'Histogram' = 3, 'ExponentialHistogram' = 4, 'Summary' = 5),
    `Attributes` Map(LowCardinality(String), String),
    `Timestamp` DateTime CODEC(Delta(4), ZSTD(1)),
    `MetricDescription` SimpleAggregateFunction(anyLast, String),
    `MetricUnit` SimpleAggregateFunction(anyLast, String),
    `StartTimestamp` SimpleAggregateFunction(min, DateTime64(9)) CODEC(Delta(8), ZSTD(1)),
    `RetentionDays` SimpleAggregateFunction(max, UInt8) DEFAULT 30,
    `Exemplars.Attributes` SimpleAggregateFunction(groupArrayArray, Array(Map(String, String))),
    `Exemplars.Timestamp` SimpleAggregateFunction(groupArrayArray, Array(DateTime64(9))),
    `Exemplars.Value` SimpleAggregateFunction(groupArrayArray, Array(Float64)),
    `Exemplars.SpanID` SimpleAggregateFunction(groupArrayArray, Array(String)),
    `Exemplars.TraceID` SimpleAggregateFunction(groupArrayArray, Array(String)),
    `Exemplars.SecureSessionID` SimpleAggregateFunction(groupArrayArray, Array(String)),
    `Min` SimpleAggregateFunction(min, Float64),
    `Max` SimpleAggregateFunction(max, Float64),
    `BucketCounts` SimpleAggregateFunction(groupArrayArray, Array(UInt64)),
    `ExplicitBounds` SimpleAggregateFunction(groupArrayArray, Array(Float64)),
    `ValueAtQuantiles.Quantile` SimpleAggregateFunction(groupArrayArray, Array(Float64)),
    `ValueAtQuantiles.Value` SimpleAggregateFunction(groupArrayArray, Array(Float64)),
    `Count` SimpleAggregateFunction(sum, UInt64),
    `Sum` SimpleAggregateFunction(sum, Float64)
)
ENGINE = AggregatingMergeTree
PARTITION BY toStartOfDay(Timestamp)
ORDER BY (ProjectId, ServiceName, MetricName, MetricType, Attributes, toUnixTimestamp(Timestamp))
TTL toDateTime(Timestamp) + toIntervalDay(RetentionDays)
SETTINGS index_granularity = 8192

-- Table: metrics_histogram
CREATE TABLE default.metrics_histogram
(
    `ProjectId` UInt32,
    `ServiceName` LowCardinality(String),
    `MetricName` String,
    `MetricDescription` String,
    `MetricUnit` String,
    `Attributes` Map(LowCardinality(String), String),
    `StartTimestamp` DateTime64(9) CODEC(Delta(8), ZSTD(1)),
    `Timestamp` DateTime64(9) CODEC(Delta(8), ZSTD(1)),
    `RetentionDays` UInt8 DEFAULT 30,
    `Flags` UInt32,
    `Exemplars.Attributes` Array(Map(LowCardinality(String), String)),
    `Exemplars.Timestamp` Array(DateTime64(9)),
    `Exemplars.Value` Array(Float64),
    `Exemplars.SpanID` Array(String),
    `Exemplars.TraceID` Array(String),
    `Exemplars.SecureSessionID` Array(String),
    `Count` UInt64 CODEC(Delta(8), ZSTD(1)),
    `Sum` Float64,
    `BucketCounts` Array(UInt64),
    `ExplicitBounds` Array(Float64),
    `Min` Float64,
    `Max` Float64,
    `AggregationTemporality` Int32 CODEC(ZSTD(1))
)
ENGINE = MergeTree
PARTITION BY toStartOfDay(Timestamp)
ORDER BY (ProjectId, ServiceName, MetricName, toUnixTimestamp64Nano(Timestamp))
TTL toDateTime(Timestamp) + toIntervalHour(1)
SETTINGS min_rows_for_wide_part = 0, min_bytes_for_wide_part = 0, ttl_only_drop_parts = 1, min_bytes_for_full_part_storage = 4294967296, max_bytes_to_merge_at_min_space_in_pool = 10485760, number_of_free_entries_in_pool_to_lower_max_size_of_merge = 6, index_granularity = 8192

-- Table: metrics_histogram_mv
CREATE MATERIALIZED VIEW default.metrics_histogram_mv TO default.metrics
(
    `ProjectId` UInt32,
    `ServiceName` LowCardinality(String),
    `MetricName` String,
    `MetricType` String,
    `Attributes` Map(LowCardinality(String), String),
    `Timestamp` DateTime,
    `MetricDescription` SimpleAggregateFunction(anyLast, String),
    `MetricUnit` SimpleAggregateFunction(anyLast, String),
    `StartTimestamp` SimpleAggregateFunction(min, DateTime64(9)),
    `RetentionDays` SimpleAggregateFunction(max, UInt8),
    `Exemplars.Attributes` SimpleAggregateFunction(groupArrayArray, Array(Map(String, String))),
    `Exemplars.Timestamp` SimpleAggregateFunction(groupArrayArray, Array(DateTime64(9))),
    `Exemplars.Value` SimpleAggregateFunction(groupArrayArray, Array(Float64)),
    `Exemplars.SpanID` SimpleAggregateFunction(groupArrayArray, Array(String)),
    `Exemplars.TraceID` SimpleAggregateFunction(groupArrayArray, Array(String)),
    `Exemplars.SecureSessionID` SimpleAggregateFunction(groupArrayArray, Array(String)),
    `Min` SimpleAggregateFunction(min, Float64),
    `Max` SimpleAggregateFunction(min, Float64),
    `BucketCounts` SimpleAggregateFunction(groupArrayArray, Array(UInt64)),
    `ExplicitBounds` SimpleAggregateFunction(groupArrayArray, Array(Float64)),
    `Count` SimpleAggregateFunction(sum, UInt64),
    `Sum` SimpleAggregateFunction(sum, Float64)
)
AS SELECT
    ProjectId,
    ServiceName,
    MetricName,
    'Histogram' AS MetricType,
    Attributes,
    toDateTime(toStartOfSecond(Timestamp)) AS Timestamp,
    anyLastSimpleState(MetricDescription) AS MetricDescription,
    anyLastSimpleState(MetricUnit) AS MetricUnit,
    minSimpleState(StartTimestamp) AS StartTimestamp,
    maxSimpleState(RetentionDays) AS RetentionDays,
    groupArrayArraySimpleState(Exemplars.Attributes) AS `Exemplars.Attributes`,
    groupArrayArraySimpleState(Exemplars.Timestamp) AS `Exemplars.Timestamp`,
    groupArrayArraySimpleState(Exemplars.Value) AS `Exemplars.Value`,
    groupArrayArraySimpleState(Exemplars.SpanID) AS `Exemplars.SpanID`,
    groupArrayArraySimpleState(Exemplars.TraceID) AS `Exemplars.TraceID`,
    groupArrayArraySimpleState(Exemplars.SecureSessionID) AS `Exemplars.SecureSessionID`,
    minSimpleState(Min) AS Min,
    minSimpleState(Max) AS Max,
    groupArrayArraySimpleState(BucketCounts) AS BucketCounts,
    groupArrayArraySimpleState(ExplicitBounds) AS ExplicitBounds,
    sumSimpleState(Count) AS Count,
    sumSimpleState(Sum) AS Sum
FROM default.metrics_histogram
GROUP BY ALL

-- Table: metrics_sum
CREATE TABLE default.metrics_sum
(
    `ProjectId` UInt32,
    `ServiceName` LowCardinality(String),
    `MetricName` String,
    `MetricDescription` String,
    `MetricUnit` String,
    `Attributes` Map(LowCardinality(String), String),
    `StartTimestamp` DateTime64(9) CODEC(Delta(8), ZSTD(1)),
    `Timestamp` DateTime64(9) CODEC(Delta(8), ZSTD(1)),
    `RetentionDays` UInt8 DEFAULT 30,
    `MetricType` Enum8('Empty' = 0, 'Gauge' = 1, 'Sum' = 2, 'Histogram' = 3, 'ExponentialHistogram' = 4, 'Summary' = 5),
    `Flags` UInt32,
    `Exemplars.Attributes` Array(Map(LowCardinality(String), String)),
    `Exemplars.Timestamp` Array(DateTime64(9)),
    `Exemplars.Value` Array(Float64),
    `Exemplars.SpanID` Array(String),
    `Exemplars.TraceID` Array(String),
    `Exemplars.SecureSessionID` Array(String),
    `Value` Float64,
    `AggregationTemporality` Int32 CODEC(ZSTD(1)),
    `IsMonotonic` Bool CODEC(Delta(1), ZSTD(1))
)
ENGINE = MergeTree
PARTITION BY toStartOfDay(Timestamp)
ORDER BY (ProjectId, ServiceName, MetricName, toUnixTimestamp64Nano(Timestamp))
TTL toDateTime(Timestamp) + toIntervalHour(1)
SETTINGS min_rows_for_wide_part = 0, min_bytes_for_wide_part = 0, ttl_only_drop_parts = 1, min_bytes_for_full_part_storage = 4294967296, max_bytes_to_merge_at_min_space_in_pool = 10485760, number_of_free_entries_in_pool_to_lower_max_size_of_merge = 6, index_granularity = 8192

-- Table: metrics_sum_mv
CREATE MATERIALIZED VIEW default.metrics_sum_mv TO default.metrics
(
    `ProjectId` UInt32,
    `ServiceName` LowCardinality(String),
    `MetricName` String,
    `MetricType` Enum8('Empty' = 0, 'Gauge' = 1, 'Sum' = 2, 'Histogram' = 3, 'ExponentialHistogram' = 4, 'Summary' = 5),
    `Attributes` Map(LowCardinality(String), String),
    `Timestamp` DateTime,
    `MetricDescription` SimpleAggregateFunction(anyLast, String),
    `MetricUnit` SimpleAggregateFunction(anyLast, String),
    `StartTimestamp` SimpleAggregateFunction(min, DateTime64(9)),
    `RetentionDays` SimpleAggregateFunction(max, UInt8),
    `Exemplars.Attributes` SimpleAggregateFunction(groupArrayArray, Array(Map(String, String))),
    `Exemplars.Timestamp` SimpleAggregateFunction(groupArrayArray, Array(DateTime64(9))),
    `Exemplars.Value` SimpleAggregateFunction(groupArrayArray, Array(Float64)),
    `Exemplars.SpanID` SimpleAggregateFunction(groupArrayArray, Array(String)),
    `Exemplars.TraceID` SimpleAggregateFunction(groupArrayArray, Array(String)),
    `Exemplars.SecureSessionID` SimpleAggregateFunction(groupArrayArray, Array(String)),
    `Count` SimpleAggregateFunction(sum, UInt64),
    `Sum` SimpleAggregateFunction(sum, Float64)
)
AS SELECT
    ProjectId,
    ServiceName,
    MetricName,
    MetricType,
    Attributes,
    toDateTime(toStartOfSecond(Timestamp)) AS Timestamp,
    anyLastSimpleState(MetricDescription) AS MetricDescription,
    anyLastSimpleState(MetricUnit) AS MetricUnit,
    minSimpleState(StartTimestamp) AS StartTimestamp,
    maxSimpleState(RetentionDays) AS RetentionDays,
    groupArrayArraySimpleState(Exemplars.Attributes) AS `Exemplars.Attributes`,
    groupArrayArraySimpleState(Exemplars.Timestamp) AS `Exemplars.Timestamp`,
    groupArrayArraySimpleState(Exemplars.Value) AS `Exemplars.Value`,
    groupArrayArraySimpleState(Exemplars.SpanID) AS `Exemplars.SpanID`,
    groupArrayArraySimpleState(Exemplars.TraceID) AS `Exemplars.TraceID`,
    groupArrayArraySimpleState(Exemplars.SecureSessionID) AS `Exemplars.SecureSessionID`,
    sumSimpleState(1) AS Count,
    sumSimpleState(Value) AS Sum
FROM default.metrics_sum
GROUP BY ALL

-- Table: metrics_summary
CREATE TABLE default.metrics_summary
(
    `ProjectId` UInt32,
    `ServiceName` LowCardinality(String),
    `MetricName` String,
    `MetricDescription` String,
    `MetricUnit` String,
    `Attributes` Map(LowCardinality(String), String),
    `StartTimestamp` DateTime64(9) CODEC(Delta(8), ZSTD(1)),
    `Timestamp` DateTime64(9) CODEC(Delta(8), ZSTD(1)),
    `RetentionDays` UInt8 DEFAULT 30,
    `Flags` UInt32,
    `Count` Float64,
    `Sum` Float64,
    `ValueAtQuantiles.Quantile` Array(Float64),
    `ValueAtQuantiles.Value` Array(Float64)
)
ENGINE = MergeTree
PARTITION BY toStartOfDay(Timestamp)
ORDER BY (ProjectId, ServiceName, MetricName, toUnixTimestamp64Nano(Timestamp))
TTL toDateTime(Timestamp) + toIntervalHour(1)
SETTINGS min_rows_for_wide_part = 0, min_bytes_for_wide_part = 0, ttl_only_drop_parts = 1, min_bytes_for_full_part_storage = 4294967296, max_bytes_to_merge_at_min_space_in_pool = 10485760, number_of_free_entries_in_pool_to_lower_max_size_of_merge = 6, index_granularity = 8192

-- Table: metrics_summary_mv
CREATE MATERIALIZED VIEW default.metrics_summary_mv TO default.metrics
(
    `ProjectId` UInt32,
    `ServiceName` LowCardinality(String),
    `MetricName` String,
    `MetricType` String,
    `Attributes` Map(LowCardinality(String), String),
    `Timestamp` DateTime,
    `MetricDescription` SimpleAggregateFunction(anyLast, String),
    `MetricUnit` SimpleAggregateFunction(anyLast, String),
    `StartTimestamp` SimpleAggregateFunction(min, DateTime64(9)),
    `RetentionDays` SimpleAggregateFunction(max, UInt8),
    `ValueAtQuantiles.Quantile` SimpleAggregateFunction(groupArrayArray, Array(Float64)),
    `ValueAtQuantiles.Value` SimpleAggregateFunction(groupArrayArray, Array(Float64)),
    `Count` SimpleAggregateFunction(sum, Float64),
    `Sum` SimpleAggregateFunction(sum, Float64)
)
AS SELECT
    ProjectId,
    ServiceName,
    MetricName,
    'Summary' AS MetricType,
    Attributes,
    toDateTime(toStartOfSecond(Timestamp)) AS Timestamp,
    anyLastSimpleState(MetricDescription) AS MetricDescription,
    anyLastSimpleState(MetricUnit) AS MetricUnit,
    minSimpleState(StartTimestamp) AS StartTimestamp,
    maxSimpleState(RetentionDays) AS RetentionDays,
    groupArrayArraySimpleState(ValueAtQuantiles.Quantile) AS `ValueAtQuantiles.Quantile`,
    groupArrayArraySimpleState(ValueAtQuantiles.Value) AS `ValueAtQuantiles.Value`,
    sumSimpleState(Count) AS Count,
    sumSimpleState(Sum) AS Sum
FROM default.metrics_summary
GROUP BY ALL

-- Table: phonehome
CREATE TABLE default.phonehome
(
    `Timestamp` DateTime64(9),
    `UUID` UUID,
    `SpanName` LowCardinality(String),
    `ServiceName` LowCardinality(String),
    `ServiceVersion` String,
    `TraceAttributes` Map(LowCardinality(String), String)
)
ENGINE = ReplacingMergeTree
ORDER BY (SpanName, Timestamp, UUID)
SETTINGS index_granularity = 8192

-- Table: phonehome_logs_mv
CREATE MATERIALIZED VIEW default.phonehome_logs_mv TO default.phonehome
(
    `Timestamp` DateTime,
    `UUID` UUID,
    `ServiceName` LowCardinality(String),
    `ServiceVersion` String,
    `SpanName` String,
    `TraceAttributes` Map(LowCardinality(String), String)
)
AS SELECT
    Timestamp,
    UUID,
    ServiceName,
    ServiceVersion,
    Body AS SpanName,
    LogAttributes AS TraceAttributes
FROM default.logs
WHERE (ProjectId = 1) AND (Body IN ('highlight-about-you', 'highlight-heartbeat', 'highlight-admin-usage', 'highlight-workspace-usage')) AND ((LogAttributes['highlight-doppler-config']) = 'docker')

-- Table: phonehome_mv
CREATE MATERIALIZED VIEW default.phonehome_mv TO default.phonehome
(
    `Timestamp` DateTime64(9),
    `UUID` UUID,
    `SpanName` LowCardinality(String),
    `ServiceName` LowCardinality(String),
    `ServiceVersion` String,
    `TraceAttributes` Map(LowCardinality(String), String)
)
AS SELECT
    Timestamp,
    UUID,
    SpanName,
    ServiceName,
    ServiceVersion,
    TraceAttributes
FROM default.traces
WHERE (ProjectId = 1) AND ((TraceAttributes['highlight.type']) = 'highlight.phonehome') AND ((TraceAttributes['highlight-doppler-config']) LIKE 'docker%')

-- Table: schema_migrations
CREATE TABLE default.schema_migrations
(
    `version` Int64,
    `dirty` UInt8,
    `sequence` UInt64
)
ENGINE = MergeTree
ORDER BY sequence
SETTINGS index_granularity = 8192

-- Table: session_events
CREATE TABLE default.session_events
(
    `UUID` UUID,
    `ProjectID` Int32,
    `SessionID` Int64,
    `SessionCreatedAt` DateTime64(6),
    `Timestamp` DateTime64(6),
    `Event` String,
    `Attributes` Map(LowCardinality(String), String)
)
ENGINE = MergeTree
ORDER BY (ProjectID, SessionCreatedAt, SessionID)
SETTINGS index_granularity = 8192

-- Table: session_events_vw
CREATE VIEW default.session_events_vw
(
    `UUID` UUID,
    `ProjectId` Int32,
    `SessionId` Int64,
    `SessionCreatedAt` DateTime64(6),
    `Timestamp` DateTime64(6),
    `Event` String,
    `Attributes` Map(LowCardinality(String), String),
    `SecureSessionId` String,
    `BrowserName` String,
    `BrowserVersion` String,
    `City` String,
    `Country` String,
    `Environment` String,
    `Excluded` Bool,
    `FirstSession` Bool,
    `Identified` Bool,
    `Identifier` String,
    `OSName` String,
    `OSVersion` String,
    `IP` String,
    `Processed` Bool,
    `SessionActiveLength` Int64,
    `SessionLength` Int64,
    `SessionPagesVisited` Nullable(Int32),
    `ServiceVersion` String,
    `State` String
)
AS SELECT
    session_events.UUID,
    session_events.ProjectID AS ProjectId,
    session_events.SessionID AS SessionId,
    session_events.SessionCreatedAt,
    session_events.Timestamp,
    session_events.Event,
    session_events.Attributes,
    sessions.SecureID AS SecureSessionId,
    sessions.BrowserName,
    sessions.BrowserVersion,
    sessions.City,
    sessions.Country,
    sessions.Environment,
    sessions.Excluded,
    sessions.FirstTime AS FirstSession,
    sessions.Identified,
    sessions.Identifier,
    sessions.OSName,
    sessions.OSVersion,
    sessions.IP,
    sessions.Processed,
    sessions.ActiveLength AS SessionActiveLength,
    sessions.Length AS SessionLength,
    sessions.PagesVisited AS SessionPagesVisited,
    sessions.AppVersion AS ServiceVersion,
    sessions.State
FROM default.session_events
INNER JOIN default.sessions
FINAL ON (sessions.ProjectID = session_events.ProjectID) AND (sessions.CreatedAt = session_events.SessionCreatedAt) AND (sessions.ID = session_events.SessionID)

-- Table: session_keys
CREATE TABLE default.session_keys
(
    `ProjectId` Int32,
    `Key` LowCardinality(String),
    `Day` DateTime,
    `Type` LowCardinality(String),
    `Count` UInt64
)
ENGINE = SummingMergeTree
ORDER BY (ProjectId, Key, Day, Type)
TTL Day + toIntervalDay(1096)
SETTINGS index_granularity = 8192

-- Table: session_keys_mv
CREATE MATERIALIZED VIEW default.session_keys_mv TO default.session_keys
(
    `ProjectId` Int32,
    `Key` LowCardinality(String),
    `Day` DateTime,
    `Type` LowCardinality(String),
    `Count` UInt64
)
AS SELECT
    ProjectID AS ProjectId,
    Name AS Key,
    toStartOfDay(SessionCreatedAt) AS Day,
    if(toFloat64OrNull(Value) IS NULL, 'String', 'Numeric') AS Type,
    count() AS Count
FROM default.fields
GROUP BY
    ProjectId,
    Key,
    Day,
    Type

-- Table: sessions
CREATE TABLE default.sessions
(
    `ID` Int64,
    `CreatedAt` DateTime64(6),
    `UpdatedAt` DateTime64(6),
    `SecureID` String,
    `Identified` Bool,
    `Identifier` String,
    `ProjectID` Int32,
    `City` String,
    `Country` String,
    `OSName` String,
    `OSVersion` String,
    `BrowserName` String,
    `BrowserVersion` String,
    `Processed` Bool,
    `HasRageClicks` Bool,
    `HasErrors` Bool,
    `Length` Int64,
    `ActiveLength` Int64,
    `FieldKeys` Array(String),
    `FieldKeyValues` Array(String),
    `Environment` String,
    `AppVersion` String,
    `FirstTime` Bool,
    `Viewed` Bool,
    `WithinBillingQuota` Bool,
    `EventCounts` String,
    `PagesVisited` Nullable(Int32),
    `Excluded` Bool,
    `ViewedByAdmins` Array(Int32),
    `Normalness` Float64,
    `IP` String,
    `HasComments` Bool,
    `State` String
)
ENGINE = ReplacingMergeTree(UpdatedAt)
ORDER BY (ProjectID, CreatedAt, ID)
SETTINGS index_granularity = 8192

-- Table: sessions_joined_vw
CREATE VIEW default.sessions_joined_vw
(
    `ProjectId` Int32,
    `Timestamp` DateTime64(6),
    `SessionAttributes` Map(String, String),
    `SessionAttributePairs` Array(Tuple(String, String)),
    `ID` Int64,
    `CreatedAt` DateTime64(6),
    `UpdatedAt` DateTime64(6),
    `SecureID` String,
    `Identified` Bool,
    `Fingerprint` Int32,
    `Identifier` String,
    `ProjectID` Int32,
    `City` String,
    `Country` String,
    `OSName` String,
    `OSVersion` String,
    `BrowserName` String,
    `BrowserVersion` String,
    `Processed` Bool,
    `HasRageClicks` Bool,
    `HasErrors` Bool,
    `Length` Int64,
    `ActiveLength` Int64,
    `FieldKeys` Array(String),
    `FieldKeyValues` Array(String),
    `Environment` String,
    `AppVersion` String,
    `FirstTime` Bool,
    `Viewed` Bool,
    `WithinBillingQuota` Bool,
    `EventCounts` String,
    `PagesVisited` Nullable(Int32),
    `Excluded` Bool,
    `ViewedByAdmins` Array(Int32),
    `Normalness` Float64,
    `IP` String,
    `HasComments` Bool,
    `State` String
)
AS SELECT
    ProjectID AS ProjectId,
    CreatedAt AS Timestamp,
    mapFromArrays(arrayMap(x -> (splitByChar('_', x, 2)[2]), FieldKeys), arrayMap((k, kv) -> substring(kv, length(k) + 2), arrayZip(FieldKeys, FieldKeyValues))) AS SessionAttributes,
    arrayMap((k, kv) -> (arrayStringConcat(arraySlice(splitByChar('_', k), 2), '_'), substring(kv, length(k) + 2)), arrayZip(FieldKeys, FieldKeyValues)) AS SessionAttributePairs,
    *
FROM default.sessions
FINAL
SETTINGS splitby_max_substrings_includes_remaining_string = 1

-- Table: trace_attributes
CREATE TABLE default.trace_attributes
(
    `ProjectId` Int32,
    `Key` LowCardinality(String),
    `TraceTimestamp` DateTime,
    `TraceUUID` UUID,
    `Value` String
)
ENGINE = ReplacingMergeTree
ORDER BY (ProjectId, Key, TraceTimestamp, TraceUUID, Value)
TTL TraceTimestamp + toIntervalDay(30)
SETTINGS index_granularity = 8192

-- Table: trace_attributes_mv
CREATE MATERIALIZED VIEW default.trace_attributes_mv TO default.trace_key_values
(
    `ProjectId` Int32,
    `Key` LowCardinality(String),
    `Day` DateTime,
    `Value` String,
    `Count` UInt64
)
AS SELECT
    ProjectId,
    arrayJoin(TraceAttributes).1 AS Key,
    toStartOfDay(Timestamp) AS Day,
    arrayJoin(TraceAttributes).2 AS Value,
    count() AS Count
FROM default.traces
WHERE (Key NOT IN ('trace_state', 'span_name', 'span_kind', 'service_name', 'service_version', 'message', 'secure_session_id', 'span_id', 'trace_id', 'parent_span_id', 'duration')) AND (Value != '')
GROUP BY
    ProjectId,
    Key,
    Day,
    Value

-- Table: trace_count_daily_mv
CREATE MATERIALIZED VIEW default.trace_count_daily_mv
(
    `ProjectId` UInt32,
    `Day` DateTime,
    `Count` UInt64
)
ENGINE = SummingMergeTree
ORDER BY (ProjectId, Day)
SETTINGS index_granularity = 8192
AS SELECT
    ProjectId,
    toStartOfDay(Timestamp) AS Day,
    count() AS Count
FROM default.traces
WHERE (TraceAttributes['highlight.type']) NOT IN ('http.request', 'highlight.internal')
GROUP BY
    ProjectId,
    Day

-- Table: trace_environment_mv
CREATE MATERIALIZED VIEW default.trace_environment_mv TO default.trace_key_values
(
    `ProjectId` Int32,
    `Key` LowCardinality(String),
    `Day` DateTime,
    `Value` String,
    `Count` UInt64
)
AS SELECT
    ProjectId,
    'environment' AS Key,
    toStartOfDay(Timestamp) AS Day,
    Environment AS Value,
    count() AS Count
FROM default.traces
WHERE Environment != ''
GROUP BY
    ProjectId,
    Key,
    Day,
    Value

-- Table: trace_has_errors_mv
CREATE MATERIALIZED VIEW default.trace_has_errors_mv TO default.trace_key_values
(
    `ProjectId` Int32,
    `Key` LowCardinality(String),
    `Day` DateTime,
    `Value` String,
    `Count` UInt64
)
AS SELECT
    ProjectId,
    'has_errors' AS Key,
    toStartOfDay(Timestamp) AS Day,
    HasErrors AS Value,
    count() AS Count
FROM default.traces
WHERE HasErrors IS NOT NULL
GROUP BY
    ProjectId,
    Key,
    Day,
    Value

-- Table: trace_key_values
CREATE TABLE default.trace_key_values
(
    `ProjectId` Int32,
    `Key` LowCardinality(String),
    `Day` DateTime,
    `Value` String,
    `Count` UInt64
)
ENGINE = SummingMergeTree
ORDER BY (ProjectId, Key, Day, Value)
TTL Day + toIntervalDay(31)
SETTINGS index_granularity = 8192

-- Table: trace_key_values_mv
CREATE MATERIALIZED VIEW default.trace_key_values_mv TO default.trace_key_values
(
    `ProjectId` Int32,
    `Key` LowCardinality(String),
    `Day` DateTime,
    `Value` String,
    `Count` UInt64
)
AS SELECT
    ProjectId AS ProjectId,
    Key,
    toStartOfDay(TraceTimestamp) AS Day,
    Value,
    count() AS Count
FROM default.trace_attributes
GROUP BY
    ProjectId,
    Key,
    Day,
    Value

-- Table: trace_keys
CREATE TABLE default.trace_keys
(
    `ProjectId` Int32,
    `Key` LowCardinality(String),
    `Day` DateTime,
    `Count` UInt64,
    `Type` LowCardinality(String)
)
ENGINE = SummingMergeTree
ORDER BY (ProjectId, Key, Day)
TTL Day + toIntervalDay(31)
SETTINGS index_granularity = 8192

-- Table: trace_keys_mv
CREATE MATERIALIZED VIEW default.trace_keys_mv TO default.trace_keys
(
    `ProjectId` Int32,
    `Key` LowCardinality(String),
    `Day` DateTime,
    `Count` UInt64,
    `Type` String
)
AS SELECT
    ProjectId,
    Key,
    Day,
    sum(Count) AS Count,
    if(toFloat64OrNull(Value) IS NULL, 'String', 'Numeric') AS Type
FROM default.trace_key_values
GROUP BY
    ProjectId,
    Key,
    Day,
    toFloat64OrNull(Value) IS NULL

-- Table: trace_service_name_mv
CREATE MATERIALIZED VIEW default.trace_service_name_mv TO default.trace_key_values
(
    `ProjectId` Int32,
    `Key` LowCardinality(String),
    `Day` DateTime,
    `Value` String,
    `Count` UInt64
)
AS SELECT
    ProjectId,
    'service_name' AS Key,
    toStartOfDay(Timestamp) AS Day,
    ServiceName AS Value,
    count() AS Count
FROM default.traces
WHERE ServiceName != ''
GROUP BY
    ProjectId,
    Key,
    Day,
    Value

-- Table: trace_service_version_mv
CREATE MATERIALIZED VIEW default.trace_service_version_mv TO default.trace_key_values
(
    `ProjectId` Int32,
    `Key` LowCardinality(String),
    `Day` DateTime,
    `Value` String,
    `Count` UInt64
)
AS SELECT
    ProjectId,
    'service_version' AS Key,
    toStartOfDay(Timestamp) AS Day,
    ServiceVersion AS Value,
    count() AS Count
FROM default.traces
WHERE ServiceVersion != ''
GROUP BY
    ProjectId,
    Key,
    Day,
    Value

-- Table: trace_span_kind_mv
CREATE MATERIALIZED VIEW default.trace_span_kind_mv TO default.trace_key_values
(
    `ProjectId` Int32,
    `Key` LowCardinality(String),
    `Day` DateTime,
    `Value` String,
    `Count` UInt64
)
AS SELECT
    ProjectId,
    'span_kind' AS Key,
    toStartOfDay(Timestamp) AS Day,
    SpanKind AS Value,
    count() AS Count
FROM default.traces
WHERE SpanKind != ''
GROUP BY
    ProjectId,
    Key,
    Day,
    Value

-- Table: trace_span_name_mv
CREATE MATERIALIZED VIEW default.trace_span_name_mv TO default.trace_key_values
(
    `ProjectId` Int32,
    `Key` LowCardinality(String),
    `Day` DateTime,
    `Value` String,
    `Count` UInt64
)
AS SELECT
    ProjectId,
    'span_name' AS Key,
    toStartOfDay(Timestamp) AS Day,
    SpanName AS Value,
    count() AS Count
FROM default.traces
WHERE SpanName != ''
GROUP BY
    ProjectId,
    Key,
    Day,
    Value

-- Table: trace_state_mv
CREATE MATERIALIZED VIEW default.trace_state_mv TO default.trace_key_values
(
    `ProjectId` Int32,
    `Key` LowCardinality(String),
    `Day` DateTime,
    `Value` String,
    `Count` UInt64
)
AS SELECT
    ProjectId,
    'trace_state' AS Key,
    toStartOfDay(Timestamp) AS Day,
    TraceState AS Value,
    count() AS Count
FROM default.traces
WHERE TraceState != ''
GROUP BY
    ProjectId,
    Key,
    Day,
    Value

-- Table: traces
CREATE TABLE default.traces
(
    `Timestamp` DateTime64(9),
    `UUID` UUID,
    `TraceId` String,
    `SpanId` String,
    `ParentSpanId` String,
    `ProjectId` UInt32,
    `SecureSessionId` String,
    `TraceState` String,
    `SpanName` LowCardinality(String),
    `SpanKind` LowCardinality(String),
    `Duration` Int64,
    `ServiceName` LowCardinality(String),
    `ServiceVersion` String,
    `TraceAttributes` Map(LowCardinality(String), String),
    `StatusCode` LowCardinality(String),
    `StatusMessage` String,
    `Events.Timestamp` Array(DateTime64(9)),
    `Events.Name` Array(LowCardinality(String)),
    `Events.Attributes` Array(Map(LowCardinality(String), String)),
    `Links.TraceId` Array(String),
    `Links.SpanId` Array(String),
    `Links.TraceState` Array(String),
    `Links.Attributes` Array(Map(LowCardinality(String), String)),
    `Environment` String,
    `HasErrors` Bool,
    `HighlightType` String,
    `MetricName` Nullable(String) MATERIALIZED (Events.Attributes[1])['metric.name'],
    `MetricValue` Nullable(Float64) MATERIALIZED toFloat64OrNull((Events.Attributes[1])['metric.value']),
    `HttpResponseBody` String,
    `HttpRequestBody` String,
    `HttpUrl` String,
    `HighlightKey` String,
    `HttpAttributes` Map(LowCardinality(String), String),
    `ProcessAttributes` Map(LowCardinality(String), String),
    `OsAttributes` Map(LowCardinality(String), String),
    `TelemetryAttributes` Map(LowCardinality(String), String),
    `WsAttributes` Map(LowCardinality(String), String),
    `EventAttributes` Map(LowCardinality(String), String),
    `DbAttributes` Map(LowCardinality(String), String),
    INDEX idx_trace_id TraceId TYPE bloom_filter(0.001) GRANULARITY 1,
    INDEX idx_res_attr_key mapKeys(TraceAttributes) TYPE bloom_filter(0.01) GRANULARITY 1,
    INDEX idx_res_attr_value mapValues(TraceAttributes) TYPE bloom_filter(0.01) GRANULARITY 1,
    INDEX idx_duration Duration TYPE minmax GRANULARITY 1
)
ENGINE = MergeTree
PARTITION BY toDate(Timestamp)
ORDER BY (ProjectId, Timestamp, UUID)
TTL toDateTime(Timestamp) + toIntervalDay(30)
SETTINGS index_granularity = 8192, ttl_only_drop_parts = 1, min_age_to_force_merge_seconds = 3600, min_rows_for_wide_part = 0, min_bytes_for_wide_part = 0, allow_experimental_block_number_column = true

-- Table: traces_new
CREATE TABLE default.traces_new
(
    `Timestamp` DateTime,
    `UUID` UUID,
    `TraceId` String,
    `SpanId` String,
    `ParentSpanId` String,
    `ProjectId` UInt32,
    `SecureSessionId` String,
    `TraceState` String,
    `SpanName` LowCardinality(String),
    `SpanKind` LowCardinality(String),
    `Duration` Int64,
    `ServiceName` LowCardinality(String),
    `ServiceVersion` String,
    `TraceAttributes` Map(LowCardinality(String), String),
    `StatusCode` LowCardinality(String),
    `StatusMessage` String,
    `Events.Timestamp` Array(DateTime),
    `Events.Name` Array(LowCardinality(String)),
    `Events.Attributes` Array(Map(LowCardinality(String), String)),
    `Links.TraceId` Array(String),
    `Links.SpanId` Array(String),
    `Links.TraceState` Array(String),
    `Links.Attributes` Array(Map(LowCardinality(String), String)),
    INDEX idx_trace_id TraceId TYPE bloom_filter(0.001) GRANULARITY 1,
    INDEX idx_res_attr_key mapKeys(TraceAttributes) TYPE bloom_filter(0.01) GRANULARITY 1,
    INDEX idx_res_attr_value mapValues(TraceAttributes) TYPE bloom_filter(0.01) GRANULARITY 1,
    INDEX idx_duration Duration TYPE minmax GRANULARITY 1
)
ENGINE = MergeTree
ORDER BY (ProjectId, Timestamp, UUID)
TTL toDateTime(Timestamp) + toIntervalDay(30)
SETTINGS index_granularity = 8192, ttl_only_drop_parts = 1

-- Table: traces_sampling_new
CREATE TABLE default.traces_sampling_new
(
    `Timestamp` DateTime64(9),
    `UUID` UUID,
    `TraceId` String,
    `SpanId` String,
    `ParentSpanId` String,
    `ProjectId` UInt32,
    `SecureSessionId` String,
    `TraceState` String,
    `SpanName` LowCardinality(String),
    `SpanKind` LowCardinality(String),
    `Duration` Int64,
    `ServiceName` LowCardinality(String),
    `ServiceVersion` String,
    `TraceAttributes` Map(LowCardinality(String), String),
    `StatusCode` LowCardinality(String),
    `StatusMessage` String,
    `Events.Timestamp` Array(DateTime64(9)),
    `Events.Name` Array(LowCardinality(String)),
    `Events.Attributes` Array(Map(LowCardinality(String), String)),
    `Links.TraceId` Array(String),
    `Links.SpanId` Array(String),
    `Links.TraceState` Array(String),
    `Links.Attributes` Array(Map(LowCardinality(String), String)),
    `Environment` String,
    `HasErrors` Bool,
    `MetricName` Nullable(String) MATERIALIZED (Events.Attributes[1])['metric.name'],
    `MetricValue` Nullable(Float64) MATERIALIZED toFloat64OrNull((Events.Attributes[1])['metric.value']),
    `HighlightType` String,
    `HttpResponseBody` String,
    `HttpRequestBody` String,
    `HttpUrl` String,
    `HighlightKey` String,
    `HttpAttributes` Map(LowCardinality(String), String),
    `ProcessAttributes` Map(LowCardinality(String), String),
    `OsAttributes` Map(LowCardinality(String), String),
    `TelemetryAttributes` Map(LowCardinality(String), String),
    `WsAttributes` Map(LowCardinality(String), String),
    `EventAttributes` Map(LowCardinality(String), String),
    `DbAttributes` Map(LowCardinality(String), String)
)
ENGINE = MergeTree
PARTITION BY toStartOfDay(Timestamp)
ORDER BY (toStartOfHour(Timestamp), ProjectId, farmHash64(TraceId))
SAMPLE BY farmHash64(TraceId)
TTL toDateTime(Timestamp) + toIntervalDay(30)
SETTINGS index_granularity = 8192, min_rows_for_wide_part = 0, min_bytes_for_wide_part = 0, ttl_only_drop_parts = 1, min_bytes_for_full_part_storage = 4294967296, max_bytes_to_merge_at_min_space_in_pool = 10485760, number_of_free_entries_in_pool_to_lower_max_size_of_merge = 6

-- Table: traces_sampling_new_mv
CREATE MATERIALIZED VIEW default.traces_sampling_new_mv TO default.traces_sampling_new
(
    `Timestamp` DateTime64(9),
    `UUID` UUID,
    `TraceId` String,
    `SpanId` String,
    `ParentSpanId` String,
    `ProjectId` UInt32,
    `SecureSessionId` String,
    `TraceState` String,
    `SpanName` LowCardinality(String),
    `SpanKind` LowCardinality(String),
    `Duration` Int64,
    `ServiceName` LowCardinality(String),
    `ServiceVersion` String,
    `TraceAttributes` Map(LowCardinality(String), String),
    `StatusCode` LowCardinality(String),
    `StatusMessage` String,
    `Events.Timestamp` Array(DateTime64(9)),
    `Events.Name` Array(LowCardinality(String)),
    `Events.Attributes` Array(Map(LowCardinality(String), String)),
    `Links.TraceId` Array(String),
    `Links.SpanId` Array(String),
    `Links.TraceState` Array(String),
    `Links.Attributes` Array(Map(LowCardinality(String), String)),
    `Environment` String,
    `HasErrors` Bool,
    `HighlightType` String,
    `HttpResponseBody` String,
    `HttpRequestBody` String,
    `HttpUrl` String,
    `HighlightKey` String,
    `HttpAttributes` Map(LowCardinality(String), String),
    `ProcessAttributes` Map(LowCardinality(String), String),
    `OsAttributes` Map(LowCardinality(String), String),
    `TelemetryAttributes` Map(LowCardinality(String), String),
    `WsAttributes` Map(LowCardinality(String), String),
    `EventAttributes` Map(LowCardinality(String), String),
    `DbAttributes` Map(LowCardinality(String), String)
)
AS SELECT *
FROM default.traces

