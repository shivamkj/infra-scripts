-- Table: ch_migration_locks
CREATE TABLE uptrace.ch_migration_locks
(
    `a` Int8
)
ENGINE = MergeTree
ORDER BY tuple()
SETTINGS index_granularity = 8192

-- Table: ch_migrations
CREATE TABLE uptrace.ch_migrations
(
    `name` String,
    `group_id` Int64,
    `migrated_at` DateTime,
    `sign` Int8
)
ENGINE = CollapsingMergeTree(sign)
ORDER BY name
SETTINGS index_granularity = 8192

-- Table: datapoints
CREATE TABLE uptrace.datapoints
(
    `project_id` UInt32 CODEC(DoubleDelta, ZSTD(1)),
    `instrument` Enum8('' = 0, 'counter' = 1, 'summary' = 2, 'histogram' = 3, 'gauge' = 4, 'additive' = 5, 'prom-counter' = 6) CODEC(ZSTD(1)),
    `metric` LowCardinality(String) CODEC(ZSTD(1)),
    `fingerprint` UInt64 CODEC(Delta(8), ZSTD(1)),
    `time` DateTime CODEC(Delta(4), ZSTD(1)),
    `min` SimpleAggregateFunction(min, Float32) CODEC(Delta(4), ZSTD(1)),
    `max` SimpleAggregateFunction(max, Float32) CODEC(Delta(4), ZSTD(1)),
    `sum` SimpleAggregateFunction(sumWithOverflow, Float32) CODEC(Delta(4), ZSTD(1)),
    `count` SimpleAggregateFunction(sum, UInt64) CODEC(T64, ZSTD(1)),
    `gauge` SimpleAggregateFunction(any, Float32) CODEC(Delta(4), ZSTD(1)),
    `histogram` AggregateFunction(quantilesTDigest(0.5), Float32) CODEC(ZSTD(1))
)
ENGINE = AggregatingMergeTree
PARTITION BY toDate(time)
ORDER BY (project_id, instrument, metric, fingerprint, time)
SETTINGS storage_policy = 'default', ttl_only_drop_parts = 1, index_granularity = 8192

-- Table: event_group_hours
CREATE TABLE uptrace.event_group_hours
(
    `project_id` UInt32 CODEC(DoubleDelta, ZSTD(1)),
    `group_id` UInt64 CODEC(Delta(8), ZSTD(1)),
    `type` LowCardinality(String) CODEC(ZSTD(1)),
    `system` LowCardinality(String) CODEC(ZSTD(1)),
    `name` LowCardinality(String) CODEC(ZSTD(1)),
    `event_name` LowCardinality(String) CODEC(ZSTD(1)),
    `display_name` String CODEC(ZSTD(1)),
    `time` DateTime CODEC(Delta(4), ZSTD(1)),
    `max_time` SimpleAggregateFunction(max, DateTime64(6)) CODEC(ZSTD(1)),
    `count` UInt64 CODEC(Delta(8), ZSTD(1)),
    `all_keys` AggregateFunction(groupUniqArrayArray(1000), Array(String)) CODEC(ZSTD(1)),
    `service_namespace` LowCardinality(String) CODEC(ZSTD(1)),
    `deployment_environment_name` LowCardinality(String) CODEC(ZSTD(1)),
    `service_name` LowCardinality(String) CODEC(ZSTD(1)),
    `service_version` LowCardinality(String) CODEC(ZSTD(1)),
    `host_name` LowCardinality(String) CODEC(ZSTD(1))
)
ENGINE = SummingMergeTree
PARTITION BY toDate(time)
PRIMARY KEY (project_id, type, system, group_id, time)
ORDER BY (project_id, type, system, group_id, time, deployment_environment_name, service_namespace, service_name, service_version, host_name)
SETTINGS storage_policy = 'default', index_granularity = 8192

-- Table: event_group_hours_mv
CREATE MATERIALIZED VIEW uptrace.event_group_hours_mv TO uptrace.event_group_hours
(
    `project_id` UInt32,
    `type` LowCardinality(String),
    `system` LowCardinality(String),
    `group_id` UInt64,
    `name` String,
    `event_name` String,
    `display_name` String,
    `time` DateTime,
    `max_time` SimpleAggregateFunction(max, DateTime64(6)),
    `count` UInt32,
    `all_keys` AggregateFunction(groupUniqArrayArray(1000), Array(String)),
    `deployment_environment_name` LowCardinality(String),
    `service_namespace` LowCardinality(String),
    `service_name` LowCardinality(String),
    `service_version` LowCardinality(String),
    `host_name` LowCardinality(String)
)
AS SELECT
    s.project_id,
    s.type,
    s.system,
    s.group_id,
    any(s.name) AS name,
    any(s.event_name) AS event_name,
    any(s.display_name) AS display_name,
    toStartOfHour(s.time) AS time,
    max(s.max_time) AS max_time,
    sumWithOverflow(s.count) AS count,
    groupUniqArrayArrayMergeState(1000)(s.all_keys) AS all_keys,
    s.deployment_environment_name,
    s.service_namespace,
    s.service_name,
    s.service_version,
    s.host_name
FROM uptrace.event_group_minutes AS s
GROUP BY
    s.project_id,
    s.type,
    s.system,
    s.group_id,
    toStartOfHour(s.time),
    s.deployment_environment_name,
    s.service_namespace,
    s.service_name,
    s.service_version,
    s.host_name

-- Table: event_group_minutes
CREATE TABLE uptrace.event_group_minutes
(
    `project_id` UInt32 CODEC(DoubleDelta, ZSTD(1)),
    `type` LowCardinality(String) CODEC(ZSTD(1)),
    `system` LowCardinality(String) CODEC(ZSTD(1)),
    `group_id` UInt64 CODEC(Delta(8), ZSTD(1)),
    `name` LowCardinality(String) CODEC(ZSTD(1)),
    `event_name` LowCardinality(String) CODEC(ZSTD(1)),
    `display_name` String CODEC(ZSTD(1)),
    `time` DateTime CODEC(Delta(4), ZSTD(1)),
    `max_time` SimpleAggregateFunction(max, DateTime64(6)) CODEC(ZSTD(1)),
    `count` UInt32 CODEC(Delta(4), ZSTD(1)),
    `all_keys` AggregateFunction(groupUniqArrayArray(1000), Array(String)) CODEC(ZSTD(1)),
    `deployment_environment_name` LowCardinality(String) CODEC(ZSTD(1)),
    `service_namespace` LowCardinality(String) CODEC(ZSTD(1)),
    `service_name` LowCardinality(String) CODEC(ZSTD(1)),
    `service_version` LowCardinality(String) CODEC(ZSTD(1)),
    `host_name` LowCardinality(String) CODEC(ZSTD(1))
)
ENGINE = SummingMergeTree
PARTITION BY toDate(time)
PRIMARY KEY (project_id, type, system, group_id, time)
ORDER BY (project_id, type, system, group_id, time, deployment_environment_name, service_namespace, service_name, service_version, host_name)
SETTINGS storage_policy = 'default', index_granularity = 8192

-- Table: event_group_minutes_mv
CREATE MATERIALIZED VIEW uptrace.event_group_minutes_mv TO uptrace.tracing_group_minutes
(
    `project_id` UInt32,
    `type` LowCardinality(String),
    `system` LowCardinality(String),
    `group_id` UInt64,
    `name` String,
    `event_name` String,
    `display_name` String,
    `time` DateTime,
    `max_time` DateTime64(6),
    `count` UInt32,
    `all_keys` AggregateFunction(groupUniqArrayArray(1000), Array(String)),
    `deployment_environment` LowCardinality(String),
    `service_namespace` LowCardinality(String),
    `service_name` LowCardinality(String),
    `service_version` LowCardinality(String),
    `host_name` LowCardinality(String)
)
AS SELECT
    s.project_id,
    s.type,
    s.system,
    s.group_id,
    any(s.name) AS name,
    any(s.event_name) AS event_name,
    any(s.display_name) AS display_name,
    toStartOfMinute(s.time) AS time,
    max(s.time) AS max_time,
    toUInt32(sumWithOverflow(s.count_x100) / 100) AS count,
    groupUniqArrayArrayState(1000)(s.all_keys) AS all_keys,
    s.deployment_environment,
    s.service_namespace,
    s.service_name,
    s.service_version,
    s.host_name
FROM uptrace.events_index AS s
GROUP BY
    s.project_id,
    s.type,
    s.system,
    s.group_id,
    toStartOfMinute(s.time),
    s.deployment_environment,
    s.service_namespace,
    s.service_name,
    s.service_version,
    s.host_name

-- Table: event_group_minutes_mv2
CREATE MATERIALIZED VIEW uptrace.event_group_minutes_mv2 TO uptrace.event_group_minutes
(
    `project_id` UInt32,
    `type` LowCardinality(String),
    `system` LowCardinality(String),
    `group_id` UInt64,
    `name` String,
    `event_name` String,
    `display_name` String,
    `time` DateTime,
    `max_time` DateTime64(6),
    `count` UInt32,
    `all_keys` AggregateFunction(groupUniqArrayArray(1000), Array(String)),
    `deployment_environment_name` LowCardinality(String),
    `service_namespace` LowCardinality(String),
    `service_name` LowCardinality(String),
    `service_version` LowCardinality(String),
    `host_name` LowCardinality(String)
)
AS SELECT
    s.project_id,
    s.type,
    s.system,
    s.group_id,
    any(s.name) AS name,
    any(s.event_name) AS event_name,
    any(s.display_name) AS display_name,
    toStartOfMinute(s.time) AS time,
    max(s.time) AS max_time,
    toUInt32(sumWithOverflow(s.count_x100) / 100) AS count,
    groupUniqArrayArrayState(1000)(s.all_keys) AS all_keys,
    s.deployment_environment_name,
    s.service_namespace,
    s.service_name,
    s.service_version,
    s.host_name
FROM uptrace.events_index AS s
GROUP BY
    s.project_id,
    s.type,
    s.system,
    s.group_id,
    toStartOfMinute(s.time),
    s.deployment_environment_name,
    s.service_namespace,
    s.service_name,
    s.service_version,
    s.host_name

-- Table: events_data
CREATE TABLE uptrace.events_data
(
    `project_id` UInt32 CODEC(DoubleDelta, ZSTD(1)),
    `type` LowCardinality(String) CODEC(ZSTD(1)),
    `id` UInt64 CODEC(T64, ZSTD(1)),
    `parent_id` UInt64 CODEC(ZSTD(1)),
    `trace_id_low` UInt64 CODEC(DoubleDelta, ZSTD(1)),
    `trace_id_high` UInt64 CODEC(Delta(8), ZSTD(1)),
    `time` DateTime64(6) CODEC(T64, ZSTD(1)),
    `data` String CODEC(ZSTD(1))
)
ENGINE = MergeTree
PARTITION BY toDate(time)
ORDER BY (project_id, trace_id_low, trace_id_high, id)
SETTINGS storage_policy = 'default', ttl_only_drop_parts = 1, index_granularity = 2048

-- Table: events_index
CREATE TABLE uptrace.events_index
(
    `id` UInt64 CODEC(T64, ZSTD(1)),
    `parent_id` UInt64 CODEC(ZSTD(1)),
    `trace_id_low` UInt64 CODEC(Delta(8), ZSTD(1)),
    `trace_id_high` UInt64 CODEC(Delta(8), ZSTD(1)),
    `project_id` UInt32 CODEC(DoubleDelta, ZSTD(1)),
    `group_id` UInt64 CODEC(Delta(8), ZSTD(1)),
    `merged_group_id` UInt64 CODEC(Delta(8), ZSTD(1)),
    `type` LowCardinality(String) CODEC(ZSTD(1)),
    `system` LowCardinality(String) CODEC(ZSTD(1)),
    `name` LowCardinality(String) CODEC(ZSTD(1)),
    `event_name` LowCardinality(String) CODEC(ZSTD(1)),
    `display_name` String CODEC(ZSTD(1)),
    `time` DateTime64(6) CODEC(Delta(8), ZSTD(1)),
    `count_x100` UInt32 CODEC(T64, ZSTD(1)),
    `bytes` UInt32 CODEC(T64, Default),
    `all_keys` Array(LowCardinality(String)) CODEC(ZSTD(1)),
    `attrs` JSON CODEC(ZSTD(1)),
    `deployment_environment` LowCardinality(String) CODEC(ZSTD(1)),
    `deployment_environment_name` LowCardinality(String) CODEC(Default),
    `service_namespace` LowCardinality(String) CODEC(ZSTD(1)),
    `service_name` LowCardinality(String) CODEC(ZSTD(1)),
    `service_version` LowCardinality(String) CODEC(ZSTD(1)),
    `host_name` LowCardinality(String) CODEC(ZSTD(1)),
    `telemetry_sdk_name` LowCardinality(String) CODEC(ZSTD(1)),
    `telemetry_sdk_language` LowCardinality(String) CODEC(ZSTD(1)),
    `telemetry_sdk_version` LowCardinality(String) CODEC(ZSTD(1)),
    `telemetry_auto_version` LowCardinality(String) CODEC(ZSTD(1)),
    `otel_library_name` LowCardinality(String) CODEC(ZSTD(1)),
    `otel_library_version` LowCardinality(String) CODEC(ZSTD(1)),
    `process_pid` Int32 CODEC(T64, ZSTD(1)),
    `process_command` LowCardinality(String) CODEC(ZSTD(1)),
    `process_runtime_name` LowCardinality(String) CODEC(ZSTD(1)),
    `process_runtime_version` LowCardinality(String) CODEC(ZSTD(1)),
    `process_runtime_description` LowCardinality(String) CODEC(ZSTD(1)),
    `messaging_message_id` String CODEC(ZSTD(1)),
    `messaging_message_type` LowCardinality(String) CODEC(ZSTD(1)),
    `messaging_message_payload_size_bytes` Int32 CODEC(T64, ZSTD(1)),
    INDEX display_name_ngrambf lower(display_name) TYPE ngrambf_v1(3, 10240, 2, 0) GRANULARITY 4
)
ENGINE = MergeTree
PARTITION BY toDate(time)
ORDER BY (project_id, type, system, group_id, time)
SETTINGS storage_policy = 'default', ttl_only_drop_parts = 1, index_granularity = 8192

-- Table: found_spans
CREATE TABLE uptrace.found_spans
(
    `project_id` UInt32 CODEC(DoubleDelta, ZSTD(1)),
    `source` Enum8('spans' = 1, 'logs' = 2, 'events' = 3) CODEC(ZSTD(1)),
    `query_id` UInt64 CODEC(Delta(8), ZSTD(1)),
    `time` DateTime CODEC(Delta(4), ZSTD(1)),
    `system` LowCardinality(String) CODEC(ZSTD(1)),
    `trace_id_low` UInt64 CODEC(Delta(8), ZSTD(1)),
    `trace_id_high` UInt64 CODEC(Delta(8), ZSTD(1)),
    `id` UInt64 CODEC(T64, ZSTD(1)),
    `count_x100` UInt32 CODEC(T64, ZSTD(1)),
    `duration` Int64 CODEC(T64, ZSTD(1)),
    `status_code` Enum8('unset' = 0, 'error' = 1, 'ok' = 2) CODEC(ZSTD(1))
)
ENGINE = MergeTree
PARTITION BY toDate(time)
ORDER BY (project_id, source, query_id, time)
SETTINGS storage_policy = 'default', ttl_only_drop_parts = 1, index_granularity = 8192

-- Table: log_group_hours
CREATE TABLE uptrace.log_group_hours
(
    `project_id` UInt32 CODEC(DoubleDelta, ZSTD(1)),
    `group_id` UInt64 CODEC(Delta(8), ZSTD(1)),
    `type` LowCardinality(String) CODEC(ZSTD(1)),
    `system` LowCardinality(String) CODEC(ZSTD(1)),
    `name` LowCardinality(String) CODEC(ZSTD(1)),
    `event_name` LowCardinality(String) CODEC(ZSTD(1)),
    `display_name` String CODEC(ZSTD(1)),
    `time` DateTime CODEC(Delta(4), ZSTD(1)),
    `max_time` SimpleAggregateFunction(max, DateTime64(6)) CODEC(ZSTD(1)),
    `count` UInt64 CODEC(Delta(8), ZSTD(1)),
    `all_keys` AggregateFunction(groupUniqArrayArray(1000), Array(String)) CODEC(ZSTD(1)),
    `service_namespace` LowCardinality(String) CODEC(ZSTD(1)),
    `deployment_environment_name` LowCardinality(String) CODEC(ZSTD(1)),
    `service_name` LowCardinality(String) CODEC(ZSTD(1)),
    `service_version` LowCardinality(String) CODEC(ZSTD(1)),
    `host_name` LowCardinality(String) CODEC(ZSTD(1))
)
ENGINE = SummingMergeTree
PARTITION BY toDate(time)
PRIMARY KEY (project_id, type, system, group_id, time)
ORDER BY (project_id, type, system, group_id, time, deployment_environment_name, service_namespace, service_name, service_version, host_name)
SETTINGS storage_policy = 'default', index_granularity = 8192

-- Table: log_group_hours_mv
CREATE MATERIALIZED VIEW uptrace.log_group_hours_mv TO uptrace.log_group_hours
(
    `project_id` UInt32,
    `type` LowCardinality(String),
    `system` LowCardinality(String),
    `group_id` UInt64,
    `name` String,
    `event_name` String,
    `display_name` String,
    `time` DateTime,
    `max_time` SimpleAggregateFunction(max, DateTime64(6)),
    `count` UInt32,
    `all_keys` AggregateFunction(groupUniqArrayArray(1000), Array(String)),
    `deployment_environment_name` LowCardinality(String),
    `service_namespace` LowCardinality(String),
    `service_name` LowCardinality(String),
    `service_version` LowCardinality(String),
    `host_name` LowCardinality(String)
)
AS SELECT
    s.project_id,
    s.type,
    s.system,
    s.group_id,
    any(s.name) AS name,
    any(s.event_name) AS event_name,
    any(s.display_name) AS display_name,
    toStartOfHour(s.time) AS time,
    max(s.max_time) AS max_time,
    sumWithOverflow(s.count) AS count,
    groupUniqArrayArrayMergeState(1000)(s.all_keys) AS all_keys,
    s.deployment_environment_name,
    s.service_namespace,
    s.service_name,
    s.service_version,
    s.host_name
FROM uptrace.log_group_minutes AS s
GROUP BY
    s.project_id,
    s.type,
    s.system,
    s.group_id,
    toStartOfHour(s.time),
    s.deployment_environment_name,
    s.service_namespace,
    s.service_name,
    s.service_version,
    s.host_name

-- Table: log_group_minutes
CREATE TABLE uptrace.log_group_minutes
(
    `project_id` UInt32 CODEC(DoubleDelta, ZSTD(1)),
    `type` LowCardinality(String) CODEC(ZSTD(1)),
    `system` LowCardinality(String) CODEC(ZSTD(1)),
    `group_id` UInt64 CODEC(Delta(8), ZSTD(1)),
    `name` LowCardinality(String) CODEC(ZSTD(1)),
    `event_name` LowCardinality(String) CODEC(ZSTD(1)),
    `display_name` String CODEC(ZSTD(1)),
    `time` DateTime CODEC(Delta(4), ZSTD(1)),
    `max_time` SimpleAggregateFunction(max, DateTime64(6)) CODEC(ZSTD(1)),
    `count` UInt32 CODEC(Delta(4), ZSTD(1)),
    `all_keys` AggregateFunction(groupUniqArrayArray(1000), Array(String)) CODEC(ZSTD(1)),
    `deployment_environment_name` LowCardinality(String) CODEC(ZSTD(1)),
    `service_namespace` LowCardinality(String) CODEC(ZSTD(1)),
    `service_name` LowCardinality(String) CODEC(ZSTD(1)),
    `service_version` LowCardinality(String) CODEC(ZSTD(1)),
    `host_name` LowCardinality(String) CODEC(ZSTD(1))
)
ENGINE = SummingMergeTree
PARTITION BY toDate(time)
PRIMARY KEY (project_id, type, system, group_id, time)
ORDER BY (project_id, type, system, group_id, time, deployment_environment_name, service_namespace, service_name, service_version, host_name)
SETTINGS storage_policy = 'default', index_granularity = 8192

-- Table: log_group_minutes_mv
CREATE MATERIALIZED VIEW uptrace.log_group_minutes_mv TO uptrace.tracing_group_minutes
(
    `project_id` UInt32,
    `type` LowCardinality(String),
    `system` LowCardinality(String),
    `group_id` UInt64,
    `name` String,
    `event_name` String,
    `display_name` String,
    `time` DateTime,
    `max_time` DateTime64(6),
    `count` UInt32,
    `all_keys` AggregateFunction(groupUniqArrayArray(1000), Array(String)),
    `deployment_environment` LowCardinality(String),
    `service_namespace` LowCardinality(String),
    `service_name` LowCardinality(String),
    `service_version` LowCardinality(String),
    `host_name` LowCardinality(String)
)
AS SELECT
    s.project_id,
    s.type,
    s.system,
    s.group_id,
    any(s.name) AS name,
    any(s.event_name) AS event_name,
    any(s.display_name) AS display_name,
    toStartOfMinute(s.time) AS time,
    max(s.time) AS max_time,
    toUInt32(sumWithOverflow(s.count_x100) / 100) AS count,
    groupUniqArrayArrayState(1000)(s.all_keys) AS all_keys,
    s.deployment_environment,
    s.service_namespace,
    s.service_name,
    s.service_version,
    s.host_name
FROM uptrace.logs_index AS s
GROUP BY
    s.project_id,
    s.type,
    s.system,
    s.group_id,
    toStartOfMinute(s.time),
    s.deployment_environment,
    s.service_namespace,
    s.service_name,
    s.service_version,
    s.host_name

-- Table: log_group_minutes_mv2
CREATE MATERIALIZED VIEW uptrace.log_group_minutes_mv2 TO uptrace.log_group_minutes
(
    `project_id` UInt32,
    `type` LowCardinality(String),
    `system` LowCardinality(String),
    `group_id` UInt64,
    `name` String,
    `event_name` String,
    `display_name` String,
    `time` DateTime,
    `max_time` DateTime64(6),
    `count` UInt32,
    `all_keys` AggregateFunction(groupUniqArrayArray(1000), Array(String)),
    `deployment_environment_name` LowCardinality(String),
    `service_namespace` LowCardinality(String),
    `service_name` LowCardinality(String),
    `service_version` LowCardinality(String),
    `host_name` LowCardinality(String)
)
AS SELECT
    s.project_id,
    s.type,
    s.system,
    s.group_id,
    any(s.name) AS name,
    any(s.event_name) AS event_name,
    any(s.display_name) AS display_name,
    toStartOfMinute(s.time) AS time,
    max(s.time) AS max_time,
    toUInt32(sumWithOverflow(s.count_x100) / 100) AS count,
    groupUniqArrayArrayState(1000)(s.all_keys) AS all_keys,
    s.deployment_environment_name,
    s.service_namespace,
    s.service_name,
    s.service_version,
    s.host_name
FROM uptrace.logs_index AS s
GROUP BY
    s.project_id,
    s.type,
    s.system,
    s.group_id,
    toStartOfMinute(s.time),
    s.deployment_environment_name,
    s.service_namespace,
    s.service_name,
    s.service_version,
    s.host_name

-- Table: logs_data
CREATE TABLE uptrace.logs_data
(
    `project_id` UInt32 CODEC(DoubleDelta, ZSTD(1)),
    `type` LowCardinality(String) CODEC(ZSTD(1)),
    `id` UInt64 CODEC(T64, ZSTD(1)),
    `parent_id` UInt64 CODEC(ZSTD(1)),
    `trace_id_low` UInt64 CODEC(DoubleDelta, ZSTD(1)),
    `trace_id_high` UInt64 CODEC(Delta(8), ZSTD(1)),
    `time` DateTime64(6) CODEC(T64, ZSTD(1)),
    `data` String CODEC(ZSTD(1))
)
ENGINE = MergeTree
PARTITION BY toDate(time)
ORDER BY (project_id, trace_id_low, trace_id_high, id)
SETTINGS storage_policy = 'default', ttl_only_drop_parts = 1, index_granularity = 2048

-- Table: logs_index
CREATE TABLE uptrace.logs_index
(
    `id` UInt64 CODEC(T64, ZSTD(1)),
    `parent_id` UInt64 CODEC(ZSTD(1)),
    `trace_id_low` UInt64 CODEC(Delta(8), ZSTD(1)),
    `trace_id_high` UInt64 CODEC(Delta(8), ZSTD(1)),
    `project_id` UInt32 CODEC(DoubleDelta, ZSTD(1)),
    `group_id` UInt64 CODEC(Delta(8), ZSTD(1)),
    `merged_group_id` UInt64 CODEC(Delta(8), ZSTD(1)),
    `type` LowCardinality(String) CODEC(ZSTD(1)),
    `system` LowCardinality(String) CODEC(ZSTD(1)),
    `name` LowCardinality(String) CODEC(ZSTD(1)),
    `event_name` LowCardinality(String) CODEC(ZSTD(1)),
    `display_name` String CODEC(ZSTD(1)),
    `time` DateTime64(6) CODEC(Delta(8), ZSTD(1)),
    `count_x100` UInt32 CODEC(T64, ZSTD(1)),
    `bytes` UInt32 CODEC(T64, Default),
    `grouping_rule_id` UInt64 CODEC(Delta(8), ZSTD(1)),
    `grouping_pattern` LowCardinality(String) CODEC(ZSTD(1)),
    `all_keys` Array(LowCardinality(String)) CODEC(ZSTD(1)),
    `attrs` JSON CODEC(ZSTD(1)),
    `deployment_environment` LowCardinality(String) CODEC(ZSTD(1)),
    `deployment_environment_name` LowCardinality(String) CODEC(Default),
    `service_namespace` LowCardinality(String) CODEC(ZSTD(1)),
    `service_name` LowCardinality(String) CODEC(ZSTD(1)),
    `service_version` LowCardinality(String) CODEC(ZSTD(1)),
    `host_name` LowCardinality(String) CODEC(ZSTD(1)),
    `telemetry_sdk_name` LowCardinality(String) CODEC(ZSTD(1)),
    `telemetry_sdk_language` LowCardinality(String) CODEC(ZSTD(1)),
    `telemetry_sdk_version` LowCardinality(String) CODEC(ZSTD(1)),
    `telemetry_auto_version` LowCardinality(String) CODEC(ZSTD(1)),
    `otel_library_name` LowCardinality(String) CODEC(ZSTD(1)),
    `otel_library_version` LowCardinality(String) CODEC(ZSTD(1)),
    `log_severity` Enum8('' = 0, 'TRACE' = 1, 'TRACE2' = 2, 'TRACE3' = 3, 'TRACE4' = 4, 'DEBUG' = 5, 'DEBUG2' = 6, 'DEBUG3' = 7, 'DEBUG4' = 8, 'INFO' = 9, 'INFO2' = 10, 'INFO3' = 11, 'INFO4' = 12, 'WARN' = 13, 'WARN2' = 14, 'WARN3' = 15, 'WARN4' = 16, 'ERROR' = 17, 'ERROR2' = 18, 'ERROR3' = 19, 'ERROR4' = 20, 'FATAL' = 21, 'FATAL2' = 22, 'FATAL3' = 23, 'FATAL4' = 24) CODEC(ZSTD(1)),
    `log_file_path` LowCardinality(String) CODEC(ZSTD(1)),
    `log_file_name` LowCardinality(String) CODEC(ZSTD(1)),
    `log_iostream` LowCardinality(String) CODEC(ZSTD(1)),
    `log_source` LowCardinality(String) CODEC(ZSTD(1)),
    `exception_type` LowCardinality(String) CODEC(ZSTD(1)),
    `exception_stacktrace` String CODEC(ZSTD(1)),
    INDEX display_name_ngrambf lower(display_name) TYPE ngrambf_v1(3, 10240, 2, 0) GRANULARITY 4
)
ENGINE = MergeTree
PARTITION BY toDate(time)
ORDER BY (project_id, type, system, group_id, time)
SETTINGS storage_policy = 'default', ttl_only_drop_parts = 1, index_granularity = 8192

-- Table: notifications
CREATE TABLE uptrace.notifications
(
    `project_id` UInt32 CODEC(DoubleDelta, ZSTD(1)),
    `monitor_id` UInt64 CODEC(Delta(8), ZSTD(1)),
    `alert_id` UInt64 CODEC(Delta(8), ZSTD(1)),
    `time` DateTime64(3) CODEC(Delta(8), ZSTD(1)),
    `status` LowCardinality(String) CODEC(ZSTD(1)),
    `request` String CODEC(ZSTD(1)),
    `response` String CODEC(ZSTD(1))
)
ENGINE = MergeTree
PARTITION BY toDate(time)
ORDER BY (project_id, monitor_id, alert_id, time)
TTL toDate(time) + toIntervalDay(30)
SETTINGS index_granularity = 8192

-- Table: preagg_datapoints
CREATE TABLE uptrace.preagg_datapoints
(
    `project_id` UInt32 CODEC(DoubleDelta, ZSTD(1)),
    `instrument` Enum8('' = 0, 'counter' = 1, 'summary' = 2, 'histogram' = 3, 'gauge' = 4, 'additive' = 5, 'prom-counter' = 6) CODEC(ZSTD(1)),
    `metric` LowCardinality(String) CODEC(ZSTD(1)),
    `fingerprint` UInt64 CODEC(Delta(8), ZSTD(1)),
    `time` DateTime CODEC(Delta(4), ZSTD(1)),
    `min` SimpleAggregateFunction(min, Float32) CODEC(Delta(4), ZSTD(1)),
    `max` SimpleAggregateFunction(max, Float32) CODEC(Delta(4), ZSTD(1)),
    `sum` SimpleAggregateFunction(sumWithOverflow, Float32) CODEC(Delta(4), ZSTD(1)),
    `count` SimpleAggregateFunction(sum, UInt64) CODEC(T64, ZSTD(1)),
    `gauge` SimpleAggregateFunction(any, Float32) CODEC(Delta(4), ZSTD(1)),
    `histogram` AggregateFunction(quantilesTDigest(0.5), Float32) CODEC(ZSTD(1))
)
ENGINE = AggregatingMergeTree
PARTITION BY toDate(time)
ORDER BY (project_id, instrument, metric, fingerprint, time)
SETTINGS storage_policy = 'default', ttl_only_drop_parts = 1, index_granularity = 8192

-- Table: preagg_datapoints_mv
CREATE MATERIALIZED VIEW uptrace.preagg_datapoints_mv TO uptrace.preagg_datapoints
(
    `project_id` UInt32,
    `instrument` Enum8('' = 0, 'counter' = 1, 'summary' = 2, 'histogram' = 3, 'gauge' = 4, 'additive' = 5, 'prom-counter' = 6),
    `metric` LowCardinality(String),
    `fingerprint` UInt64,
    `time` DateTime,
    `min` SimpleAggregateFunction(min, Float32),
    `max` SimpleAggregateFunction(max, Float32),
    `sum` Float32,
    `count` UInt64,
    `gauge` SimpleAggregateFunction(any, Float32),
    `histogram` AggregateFunction(quantilesTDigest(0.5), Float32)
)
AS SELECT
    d.project_id,
    d.instrument,
    d.metric,
    d.fingerprint,
    toStartOfTenMinutes(d.time) AS time,
    min(d.min) AS min,
    max(d.max) AS max,
    sumWithOverflow(d.sum) AS sum,
    sum(d.count) AS count,
    any(d.gauge) AS gauge,
    quantilesTDigestMergeState(0.5)(d.histogram) AS histogram
FROM uptrace.datapoints AS d
GROUP BY
    d.project_id,
    d.instrument,
    d.metric,
    d.fingerprint,
    toStartOfTenMinutes(d.time)

-- Table: preagg_datapoints_uniq_timeseries_mv
CREATE MATERIALIZED VIEW uptrace.preagg_datapoints_uniq_timeseries_mv TO uptrace.project_metrics
(
    `project_id` UInt32,
    `time` DateTime,
    `uniq_timeseries` AggregateFunction(uniqCombined64(12), UInt64)
)
AS SELECT
    d.project_id,
    toStartOfHour(d.time) AS time,
    uniqCombined64State(12)(d.fingerprint) AS uniq_timeseries
FROM uptrace.preagg_datapoints AS d
GROUP BY
    d.project_id,
    toStartOfHour(d.time)

-- Table: project_metrics
CREATE TABLE uptrace.project_metrics
(
    `project_id` UInt32 CODEC(Delta(4), ZSTD(1)),
    `time` DateTime CODEC(Delta(4), ZSTD(1)),
    `span_sampled_num` UInt32 CODEC(Delta(4), ZSTD(1)),
    `span_sampled_bytes` UInt32 CODEC(Delta(4), ZSTD(1)),
    `span_dropped_num` UInt32 CODEC(Delta(4), ZSTD(1)),
    `datapoint_sampled_num` UInt32 CODEC(Delta(4), ZSTD(1)),
    `datapoint_dropped_num` UInt32 CODEC(Delta(4), ZSTD(1)),
    `uniq_timeseries` AggregateFunction(uniqCombined64(12), UInt64) CODEC(ZSTD(1))
)
ENGINE = SummingMergeTree
PARTITION BY toDate(time)
ORDER BY (project_id, time)
TTL toDate(time) + toIntervalDay(365)
SETTINGS index_granularity = 8192

-- Table: service_graph_client_duration_datapoints_mv
CREATE MATERIALIZED VIEW uptrace.service_graph_client_duration_datapoints_mv TO uptrace.datapoints
(
    `project_id` UInt32,
    `instrument` String,
    `metric` String,
    `fingerprint` UInt32,
    `time` DateTime,
    `min` SimpleAggregateFunction(min, Float32),
    `max` SimpleAggregateFunction(max, Float32),
    `sum` Float64,
    `count` UInt64
)
AS SELECT
    e.project_id,
    'summary' AS instrument,
    'uptrace_service_graph_client_duration' AS metric,
    xxHash32(e.project_id, e.type, e.client_name, e.server_name, e.deployment_environment, e.service_namespace) AS fingerprint,
    e.time,
    min(e.client_duration_min) AS min,
    min(e.client_duration_max) AS max,
    sum(e.client_duration_sum) AS sum,
    sum(e.count) AS count
FROM uptrace.service_graph_edges AS e
GROUP BY
    e.project_id,
    e.type,
    e.client_name,
    e.server_name,
    e.deployment_environment,
    e.service_namespace,
    e.time

-- Table: service_graph_client_duration_timeseries_mv
CREATE MATERIALIZED VIEW uptrace.service_graph_client_duration_timeseries_mv TO uptrace.timeseries
(
    `project_id` UInt32,
    `metric` String,
    `fingerprint` UInt32,
    `time` DateTime,
    `min_time` DateTime,
    `max_time` DateTime,
    `instrument` String,
    `library_name` String,
    `all_keys` Array(String),
    `all_values` Array(String),
    `attrs` String
)
AS SELECT
    e.project_id,
    'uptrace_service_graph_client_duration' AS metric,
    xxHash32(e.project_id, e.type, e.client_name, e.server_name, e.deployment_environment, e.service_namespace) AS fingerprint,
    toStartOfDay(e.time) AS time,
    min(e.time) AS min_time,
    max(e.time) AS max_time,
    'summary' AS instrument,
    'uptrace.dev' AS library_name,
    arrayConcat(['type', 'client', 'server'], if(e.deployment_environment != '', ['deployment_environment'], []), if(e.service_namespace != '', ['service_namespace'], [])) AS all_keys,
    arrayConcat([e.type, e.client_name, e.server_name], if(e.deployment_environment != '', [e.deployment_environment], []), if(e.service_namespace != '', [e.service_namespace], [])) AS all_values,
    concat('{', '"type": "', e.type, '",', '"client": "', e.client_name, '",', '"server": "', e.server_name, '",', '"deployment_environment": "', e.deployment_environment, '",', '"service_namespace": "', e.service_namespace, '"', '}') AS attrs
FROM uptrace.service_graph_edges AS e
GROUP BY
    e.project_id,
    e.type,
    e.client_name,
    e.server_name,
    e.deployment_environment,
    e.service_namespace,
    toStartOfDay(e.time)

-- Table: service_graph_edges
CREATE TABLE uptrace.service_graph_edges
(
    `project_id` UInt32 CODEC(DoubleDelta, ZSTD(1)),
    `type` Enum8('unset' = 0, 'http' = 1, 'db' = 2, 'messaging' = 3) CODEC(ZSTD(1)),
    `time` DateTime CODEC(T64, ZSTD(1)),
    `client_attr` LowCardinality(String) CODEC(ZSTD(1)),
    `client_name` LowCardinality(String) CODEC(ZSTD(1)),
    `server_attr` LowCardinality(String) CODEC(ZSTD(1)),
    `server_name` LowCardinality(String) CODEC(ZSTD(1)),
    `deployment_environment` LowCardinality(String) CODEC(ZSTD(1)),
    `service_namespace` LowCardinality(String) CODEC(ZSTD(1)),
    `client_duration_min` SimpleAggregateFunction(min, Float32) CODEC(ZSTD(1)),
    `client_duration_max` SimpleAggregateFunction(max, Float32) CODEC(ZSTD(1)),
    `client_duration_sum` SimpleAggregateFunction(sumWithOverflow, Float32) CODEC(ZSTD(1)),
    `server_duration_min` SimpleAggregateFunction(min, Float32) CODEC(ZSTD(1)),
    `server_duration_max` SimpleAggregateFunction(max, Float32) CODEC(ZSTD(1)),
    `server_duration_sum` SimpleAggregateFunction(sumWithOverflow, Float32) CODEC(ZSTD(1)),
    `count` SimpleAggregateFunction(sumWithOverflow, UInt32) CODEC(Delta(4), ZSTD(1)),
    `error_count` SimpleAggregateFunction(sumWithOverflow, UInt32) CODEC(Delta(4), ZSTD(1))
)
ENGINE = AggregatingMergeTree
PARTITION BY toDate(time)
PRIMARY KEY (project_id, time, type, client_name, server_name)
ORDER BY (project_id, time, type, client_name, server_name, deployment_environment, service_namespace)
SETTINGS storage_policy = 'default', ttl_only_drop_parts = 1, index_granularity = 8192

-- Table: service_graph_failed_calls_datapoints_mv
CREATE MATERIALIZED VIEW uptrace.service_graph_failed_calls_datapoints_mv TO uptrace.datapoints
(
    `project_id` UInt32,
    `instrument` String,
    `metric` String,
    `fingerprint` UInt32,
    `time` DateTime,
    `sum` UInt64
)
AS SELECT
    e.project_id,
    'counter' AS instrument,
    'uptrace_service_graph_failed_calls' AS metric,
    xxHash32(e.project_id, e.type, e.client_name, e.server_name, e.deployment_environment, e.service_namespace) AS fingerprint,
    e.time,
    sum(e.error_count) AS sum
FROM uptrace.service_graph_edges AS e
GROUP BY
    e.project_id,
    e.type,
    e.client_name,
    e.server_name,
    e.deployment_environment,
    e.service_namespace,
    e.time

-- Table: service_graph_failed_calls_timeseries_mv
CREATE MATERIALIZED VIEW uptrace.service_graph_failed_calls_timeseries_mv TO uptrace.timeseries
(
    `project_id` UInt32,
    `metric` String,
    `fingerprint` UInt32,
    `time` DateTime,
    `min_time` DateTime,
    `max_time` DateTime,
    `instrument` String,
    `library_name` String,
    `all_keys` Array(String),
    `all_values` Array(String),
    `attrs` String
)
AS SELECT
    e.project_id,
    'uptrace_service_graph_failed_calls' AS metric,
    xxHash32(e.project_id, e.type, e.client_name, e.server_name, e.deployment_environment, e.service_namespace) AS fingerprint,
    toStartOfDay(e.time) AS time,
    min(e.time) AS min_time,
    max(e.time) AS max_time,
    'counter' AS instrument,
    'uptrace.dev' AS library_name,
    arrayConcat(['type', 'client', 'server'], if(e.deployment_environment != '', ['deployment_environment'], []), if(e.service_namespace != '', ['service_namespace'], [])) AS all_keys,
    arrayConcat([e.type, e.client_name, e.server_name], if(e.deployment_environment != '', [e.deployment_environment], []), if(e.service_namespace != '', [e.service_namespace], [])) AS all_values,
    concat('{', '"type": "', e.type, '",', '"client": "', e.client_name, '",', '"server": "', e.server_name, '",', '"deployment_environment": "', e.deployment_environment, '",', '"service_namespace": "', e.service_namespace, '"', '}') AS attrs
FROM uptrace.service_graph_edges AS e
GROUP BY
    e.project_id,
    e.type,
    e.client_name,
    e.server_name,
    e.deployment_environment,
    e.service_namespace,
    toStartOfDay(e.time)

-- Table: service_graph_server_duration_datapoints_mv
CREATE MATERIALIZED VIEW uptrace.service_graph_server_duration_datapoints_mv TO uptrace.datapoints
(
    `project_id` UInt32,
    `instrument` String,
    `metric` String,
    `fingerprint` UInt32,
    `time` DateTime,
    `min` SimpleAggregateFunction(min, Float32),
    `max` SimpleAggregateFunction(max, Float32),
    `sum` Float64,
    `count` UInt64
)
AS SELECT
    e.project_id,
    'summary' AS instrument,
    'uptrace_service_graph_server_duration' AS metric,
    xxHash32(e.project_id, e.type, e.client_name, e.server_name, e.deployment_environment, e.service_namespace) AS fingerprint,
    e.time,
    min(e.server_duration_min) AS min,
    min(e.server_duration_max) AS max,
    sum(e.server_duration_sum) AS sum,
    sum(e.count) AS count
FROM uptrace.service_graph_edges AS e
GROUP BY
    e.project_id,
    e.type,
    e.client_name,
    e.server_name,
    e.deployment_environment,
    e.service_namespace,
    e.time

-- Table: service_graph_server_duration_timeseries_mv
CREATE MATERIALIZED VIEW uptrace.service_graph_server_duration_timeseries_mv TO uptrace.timeseries
(
    `project_id` UInt32,
    `metric` String,
    `fingerprint` UInt32,
    `time` DateTime,
    `min_time` DateTime,
    `max_time` DateTime,
    `instrument` String,
    `library_name` String,
    `all_keys` Array(String),
    `all_values` Array(String),
    `attrs` String
)
AS SELECT
    e.project_id,
    'uptrace_service_graph_server_duration' AS metric,
    xxHash32(e.project_id, e.type, e.client_name, e.server_name, e.deployment_environment, e.service_namespace) AS fingerprint,
    toStartOfDay(e.time) AS time,
    min(e.time) AS min_time,
    max(e.time) AS max_time,
    'summary' AS instrument,
    'uptrace.dev' AS library_name,
    arrayConcat(['type', 'client', 'server'], if(e.deployment_environment != '', ['deployment_environment'], []), if(e.service_namespace != '', ['service_namespace'], [])) AS all_keys,
    arrayConcat([e.type, e.client_name, e.server_name], if(e.deployment_environment != '', [e.deployment_environment], []), if(e.service_namespace != '', [e.service_namespace], [])) AS all_values,
    concat('{', '"type": "', e.type, '",', '"client": "', e.client_name, '",', '"server": "', e.server_name, '",', '"deployment_environment": "', e.deployment_environment, '",', '"service_namespace": "', e.service_namespace, '"', '}') AS attrs
FROM uptrace.service_graph_edges AS e
GROUP BY
    e.project_id,
    e.type,
    e.client_name,
    e.server_name,
    e.deployment_environment,
    e.service_namespace,
    toStartOfDay(e.time)

-- Table: span_group_hours
CREATE TABLE uptrace.span_group_hours
(
    `project_id` UInt32 CODEC(DoubleDelta, ZSTD(1)),
    `group_id` UInt64 CODEC(Delta(8), ZSTD(1)),
    `type` LowCardinality(String) CODEC(ZSTD(1)),
    `system` LowCardinality(String) CODEC(ZSTD(1)),
    `name` LowCardinality(String) CODEC(ZSTD(1)),
    `display_name` String CODEC(ZSTD(1)),
    `time` DateTime CODEC(Delta(4), ZSTD(1)),
    `max_time` SimpleAggregateFunction(max, DateTime64(6)) CODEC(ZSTD(1)),
    `duration` AggregateFunction(quantilesTDigestWeighted(0.5), Float32, UInt32) CODEC(ZSTD(1)),
    `max_duration` SimpleAggregateFunction(max, Int64) CODEC(ZSTD(1)),
    `count` UInt64 CODEC(Delta(8), ZSTD(1)),
    `all_keys` AggregateFunction(groupUniqArrayArray(1000), Array(String)) CODEC(ZSTD(1)),
    `kind` Enum8('internal' = 0, 'server' = 1, 'client' = 2, 'producer' = 3, 'consumer' = 4) CODEC(ZSTD(1)),
    `status_code` Enum8('unset' = 0, 'error' = 1, 'ok' = 2) CODEC(ZSTD(1)),
    `service_namespace` LowCardinality(String) CODEC(ZSTD(1)),
    `deployment_environment_name` LowCardinality(String) CODEC(ZSTD(1)),
    `service_name` LowCardinality(String) CODEC(ZSTD(1)),
    `service_version` LowCardinality(String) CODEC(ZSTD(1)),
    `host_name` LowCardinality(String) CODEC(ZSTD(1))
)
ENGINE = SummingMergeTree
PARTITION BY toDate(time)
PRIMARY KEY (project_id, type, system, group_id, time)
ORDER BY (project_id, type, system, group_id, time, kind, status_code, deployment_environment_name, service_namespace, service_name, service_version, host_name)
SETTINGS storage_policy = 'default', index_granularity = 8192

-- Table: span_group_hours_mv
CREATE MATERIALIZED VIEW uptrace.span_group_hours_mv TO uptrace.span_group_hours
(
    `project_id` UInt32,
    `type` LowCardinality(String),
    `system` LowCardinality(String),
    `group_id` UInt64,
    `name` String,
    `display_name` String,
    `time` DateTime,
    `max_time` SimpleAggregateFunction(max, DateTime64(6)),
    `duration` AggregateFunction(quantilesTDigestWeighted(0.5), Float32, UInt32),
    `max_duration` SimpleAggregateFunction(max, Int64),
    `count` UInt32,
    `all_keys` AggregateFunction(groupUniqArrayArray(1000), Array(String)),
    `kind` Enum8('internal' = 0, 'server' = 1, 'client' = 2, 'producer' = 3, 'consumer' = 4),
    `status_code` Enum8('unset' = 0, 'error' = 1, 'ok' = 2),
    `deployment_environment_name` LowCardinality(String),
    `service_namespace` LowCardinality(String),
    `service_name` LowCardinality(String),
    `service_version` LowCardinality(String),
    `host_name` LowCardinality(String)
)
AS SELECT
    s.project_id,
    s.type,
    s.system,
    s.group_id,
    any(s.name) AS name,
    any(s.display_name) AS display_name,
    toStartOfHour(s.time) AS time,
    max(s.max_time) AS max_time,
    quantilesTDigestWeightedMergeState(0.5)(s.duration) AS duration,
    max(s.max_duration) AS max_duration,
    sumWithOverflow(s.count) AS count,
    groupUniqArrayArrayMergeState(1000)(s.all_keys) AS all_keys,
    s.kind,
    s.status_code,
    s.deployment_environment_name,
    s.service_namespace,
    s.service_name,
    s.service_version,
    s.host_name
FROM uptrace.span_group_minutes AS s
GROUP BY
    s.project_id,
    s.type,
    s.system,
    s.group_id,
    toStartOfHour(s.time),
    s.kind,
    s.status_code,
    s.deployment_environment_name,
    s.service_namespace,
    s.service_name,
    s.service_version,
    s.host_name

-- Table: span_group_minutes
CREATE TABLE uptrace.span_group_minutes
(
    `project_id` UInt32 CODEC(DoubleDelta, ZSTD(1)),
    `type` LowCardinality(String) CODEC(ZSTD(1)),
    `system` LowCardinality(String) CODEC(ZSTD(1)),
    `group_id` UInt64 CODEC(Delta(8), ZSTD(1)),
    `name` LowCardinality(String) CODEC(ZSTD(1)),
    `display_name` String CODEC(ZSTD(1)),
    `time` DateTime CODEC(Delta(4), ZSTD(1)),
    `max_time` SimpleAggregateFunction(max, DateTime64(6)) CODEC(ZSTD(1)),
    `duration` AggregateFunction(quantilesTDigestWeighted(0.5), Float32, UInt32) CODEC(ZSTD(1)),
    `max_duration` SimpleAggregateFunction(max, Int64) CODEC(ZSTD(1)),
    `count` UInt32 CODEC(Delta(4), ZSTD(1)),
    `all_keys` AggregateFunction(groupUniqArrayArray(1000), Array(String)) CODEC(ZSTD(1)),
    `kind` Enum8('internal' = 0, 'server' = 1, 'client' = 2, 'producer' = 3, 'consumer' = 4) CODEC(ZSTD(1)),
    `status_code` Enum8('unset' = 0, 'error' = 1, 'ok' = 2) CODEC(ZSTD(1)),
    `deployment_environment_name` LowCardinality(String) CODEC(ZSTD(1)),
    `service_namespace` LowCardinality(String) CODEC(ZSTD(1)),
    `service_name` LowCardinality(String) CODEC(ZSTD(1)),
    `service_version` LowCardinality(String) CODEC(ZSTD(1)),
    `host_name` LowCardinality(String) CODEC(ZSTD(1))
)
ENGINE = SummingMergeTree
PARTITION BY toDate(time)
PRIMARY KEY (project_id, type, system, group_id, time)
ORDER BY (project_id, type, system, group_id, time, kind, status_code, deployment_environment_name, service_namespace, service_name, service_version, host_name)
SETTINGS storage_policy = 'default', index_granularity = 8192

-- Table: span_group_minutes_mv
CREATE MATERIALIZED VIEW uptrace.span_group_minutes_mv TO uptrace.tracing_group_minutes
(
    `project_id` UInt32,
    `type` LowCardinality(String),
    `system` LowCardinality(String),
    `group_id` UInt64,
    `name` String,
    `event_name` String,
    `display_name` String,
    `time` DateTime,
    `max_time` DateTime64(6),
    `duration` AggregateFunction(quantilesTDigestWeighted(0.5), Float32, UInt32),
    `max_duration` Float32,
    `count` UInt32,
    `all_keys` AggregateFunction(groupUniqArrayArray(1000), Array(String)),
    `kind` Enum8('internal' = 0, 'server' = 1, 'client' = 2, 'producer' = 3, 'consumer' = 4),
    `status_code` Enum8('unset' = 0, 'error' = 1, 'ok' = 2),
    `deployment_environment` LowCardinality(String),
    `service_namespace` LowCardinality(String),
    `service_name` LowCardinality(String),
    `service_version` LowCardinality(String),
    `host_name` LowCardinality(String)
)
AS SELECT
    s.project_id,
    s.type,
    s.system,
    s.group_id,
    any(s.name) AS name,
    any(s.event_name) AS event_name,
    any(s.display_name) AS display_name,
    toStartOfMinute(s.time) AS time,
    max(s.time) AS max_time,
    quantilesTDigestWeightedStateIf(0.5)(s.duration, toUInt32(s.count_x100 / 100), s.duration_us > 0) AS duration,
    max(s.duration) AS max_duration,
    toUInt32(sumWithOverflow(s.count_x100) / 100) AS count,
    groupUniqArrayArrayState(1000)(s.all_keys) AS all_keys,
    s.kind,
    s.status_code,
    s.deployment_environment,
    s.service_namespace,
    s.service_name,
    s.service_version,
    s.host_name
FROM uptrace.spans_index AS s
GROUP BY
    s.project_id,
    s.type,
    s.system,
    s.group_id,
    toStartOfMinute(s.time),
    s.kind,
    s.status_code,
    s.deployment_environment,
    s.service_namespace,
    s.service_name,
    s.service_version,
    s.host_name

-- Table: span_group_minutes_mv2
CREATE MATERIALIZED VIEW uptrace.span_group_minutes_mv2 TO uptrace.span_group_minutes
(
    `project_id` UInt32,
    `type` LowCardinality(String),
    `system` LowCardinality(String),
    `group_id` UInt64,
    `name` String,
    `display_name` String,
    `time` DateTime,
    `max_time` DateTime64(6),
    `duration` AggregateFunction(quantilesTDigestWeighted(0.5), Float32, UInt32),
    `max_duration` Float32,
    `count` UInt32,
    `all_keys` AggregateFunction(groupUniqArrayArray(1000), Array(String)),
    `kind` Enum8('internal' = 0, 'server' = 1, 'client' = 2, 'producer' = 3, 'consumer' = 4),
    `status_code` Enum8('unset' = 0, 'error' = 1, 'ok' = 2),
    `deployment_environment_name` LowCardinality(String),
    `service_namespace` LowCardinality(String),
    `service_name` LowCardinality(String),
    `service_version` LowCardinality(String),
    `host_name` LowCardinality(String)
)
AS SELECT
    s.project_id,
    s.type,
    s.system,
    s.group_id,
    any(s.name) AS name,
    any(s.display_name) AS display_name,
    toStartOfMinute(s.time) AS time,
    max(s.time) AS max_time,
    quantilesTDigestWeightedStateIf(0.5)(s.duration, toUInt32(s.count_x100 / 100), s.duration_us > 0) AS duration,
    max(s.duration) AS max_duration,
    toUInt32(sumWithOverflow(s.count_x100) / 100) AS count,
    groupUniqArrayArrayState(1000)(s.all_keys) AS all_keys,
    s.kind,
    s.status_code,
    s.deployment_environment_name,
    s.service_namespace,
    s.service_name,
    s.service_version,
    s.host_name
FROM uptrace.spans_index AS s
GROUP BY
    s.project_id,
    s.type,
    s.system,
    s.group_id,
    toStartOfMinute(s.time),
    s.kind,
    s.status_code,
    s.deployment_environment_name,
    s.service_namespace,
    s.service_name,
    s.service_version,
    s.host_name

-- Table: span_links
CREATE TABLE uptrace.span_links
(
    `project_id` UInt32 CODEC(DoubleDelta, ZSTD(1)),
    `time` DateTime,
    `src_trace_id` UUID,
    `src_span_id` UInt64 CODEC(Delta(8), ZSTD(1)),
    `dest_trace_id` UUID,
    `dest_span_id` UInt64 CODEC(Delta(8), ZSTD(1)),
    `attrs` String CODEC(ZSTD(1))
)
ENGINE = MergeTree
PARTITION BY toDate(time)
ORDER BY (project_id, src_trace_id, src_span_id)
SETTINGS storage_policy = 'default', ttl_only_drop_parts = 1, index_granularity = 8192

-- Table: spans_data
CREATE TABLE uptrace.spans_data
(
    `project_id` UInt32 CODEC(DoubleDelta, ZSTD(1)),
    `type` LowCardinality(String) CODEC(ZSTD(1)),
    `id` UInt64 CODEC(T64, ZSTD(1)),
    `parent_id` UInt64 CODEC(ZSTD(1)),
    `trace_id_low` UInt64 CODEC(DoubleDelta, ZSTD(1)),
    `trace_id_high` UInt64 CODEC(Delta(8), ZSTD(1)),
    `time` DateTime64(6) CODEC(T64, ZSTD(1)),
    `data` String CODEC(ZSTD(1)),
    `edge_data` String CODEC(ZSTD(1)) TTL toStartOfInterval(time, toIntervalHour(12)) + toIntervalHour(12),
    `has_edge_data` Bool MATERIALIZED edge_data != ''
)
ENGINE = MergeTree
PARTITION BY toDate(time)
ORDER BY (project_id, trace_id_low, trace_id_high, id)
SETTINGS storage_policy = 'default', ttl_only_drop_parts = 1, index_granularity = 2048

-- Table: spans_index
CREATE TABLE uptrace.spans_index
(
    `id` UInt64 CODEC(T64, ZSTD(1)),
    `parent_id` UInt64 CODEC(ZSTD(1)),
    `trace_id_low` UInt64 CODEC(Delta(8), ZSTD(1)),
    `trace_id_high` UInt64 CODEC(Delta(8), ZSTD(1)),
    `project_id` UInt32 CODEC(DoubleDelta, ZSTD(1)),
    `group_id` UInt64 CODEC(Delta(8), ZSTD(1)),
    `merged_group_id` UInt64 CODEC(Delta(8), ZSTD(1)),
    `type` LowCardinality(String) CODEC(ZSTD(1)),
    `system` LowCardinality(String) CODEC(ZSTD(1)),
    `kind` Enum8('internal' = 0, 'server' = 1, 'client' = 2, 'producer' = 3, 'consumer' = 4) CODEC(ZSTD(1)),
    `name` LowCardinality(String) CODEC(ZSTD(1)),
    `event_name` LowCardinality(String) CODEC(ZSTD(1)),
    `display_name` String CODEC(ZSTD(1)),
    `time` DateTime64(6) CODEC(Delta(8), ZSTD(1)),
    `duration_us` Int64 CODEC(T64, ZSTD(1)),
    `duration` Float32 ALIAS duration_us / 1000,
    `count_x100` UInt32 CODEC(T64, ZSTD(1)),
    `bytes` UInt32 CODEC(T64, ZSTD(1)),
    `status_code` Enum8('unset' = 0, 'error' = 1, 'ok' = 2) CODEC(ZSTD(1)),
    `status_message` String CODEC(ZSTD(1)),
    `all_keys` Array(LowCardinality(String)) CODEC(ZSTD(1)),
    `attrs` JSON CODEC(ZSTD(1)),
    `deployment_environment` LowCardinality(String) CODEC(ZSTD(1)),
    `deployment_environment_name` LowCardinality(String) CODEC(Default),
    `service_namespace` LowCardinality(String) CODEC(ZSTD(1)),
    `service_name` LowCardinality(String) CODEC(ZSTD(1)),
    `service_version` LowCardinality(String) CODEC(ZSTD(1)),
    `host_name` LowCardinality(String) CODEC(ZSTD(1)),
    `otel_library_name` LowCardinality(String) CODEC(ZSTD(1)),
    `otel_library_version` LowCardinality(String) CODEC(ZSTD(1)),
    `telemetry_sdk_name` LowCardinality(String) CODEC(ZSTD(1)),
    `telemetry_sdk_language` LowCardinality(String) CODEC(ZSTD(1)),
    `telemetry_sdk_version` LowCardinality(String) CODEC(ZSTD(1)),
    `telemetry_auto_version` LowCardinality(String) CODEC(ZSTD(1)),
    `process_pid` Int32 CODEC(T64, ZSTD(1)),
    `process_command` LowCardinality(String) CODEC(ZSTD(1)),
    `process_runtime_name` LowCardinality(String) CODEC(ZSTD(1)),
    `process_runtime_version` LowCardinality(String) CODEC(ZSTD(1)),
    `process_runtime_description` LowCardinality(String) CODEC(ZSTD(1)),
    INDEX display_name_ngrambf lower(display_name) TYPE ngrambf_v1(3, 10240, 2, 0) GRANULARITY 4
)
ENGINE = MergeTree
PARTITION BY toDate(time)
ORDER BY (project_id, type, system, group_id, time)
SETTINGS storage_policy = 'default', ttl_only_drop_parts = 1, index_granularity = 8192

-- Table: timeseries
CREATE TABLE uptrace.timeseries
(
    `project_id` UInt32 CODEC(DoubleDelta, ZSTD(1)),
    `metric` LowCardinality(String) CODEC(ZSTD(1)),
    `fingerprint` UInt64 CODEC(Delta(8), ZSTD(1)),
    `time` DateTime CODEC(Delta(4), ZSTD(1)),
    `min_time` SimpleAggregateFunction(min, DateTime) CODEC(Delta(4), ZSTD(1)),
    `max_time` SimpleAggregateFunction(max, DateTime) CODEC(Delta(4), ZSTD(1)),
    `instrument` Enum8('' = 0, 'counter' = 1, 'summary' = 2, 'histogram' = 3, 'gauge' = 4, 'additive' = 5, 'prom-counter' = 6) CODEC(ZSTD(1)),
    `description` String CODEC(ZSTD(1)),
    `unit` LowCardinality(String) CODEC(ZSTD(1)),
    `library_name` LowCardinality(String) CODEC(ZSTD(1)),
    `library_version` LowCardinality(String) CODEC(ZSTD(1)),
    `all_keys` Array(LowCardinality(String)) CODEC(ZSTD(1)),
    `all_values` Array(String) CODEC(ZSTD(1)),
    `attrs` JSON CODEC(ZSTD(1)),
    INDEX time_minmax (min_time, max_time) TYPE minmax GRANULARITY 1
)
ENGINE = AggregatingMergeTree
PARTITION BY toDate(time)
ORDER BY (project_id, metric, fingerprint, time)
SETTINGS storage_policy = 'default', ttl_only_drop_parts = 1, index_granularity = 8192

-- Table: tracing_data
CREATE TABLE uptrace.tracing_data
(
    `project_id` UInt32 CODEC(DoubleDelta, ZSTD(1)),
    `type` LowCardinality(String) CODEC(ZSTD(1)),
    `id` UInt64 CODEC(T64, ZSTD(1)),
    `parent_id` UInt64 CODEC(ZSTD(1)),
    `trace_id_low` UInt64 CODEC(DoubleDelta, ZSTD(1)),
    `trace_id_high` UInt64 CODEC(Delta(8), ZSTD(1)),
    `time` DateTime64(6) CODEC(T64, ZSTD(1)),
    `data` String CODEC(ZSTD(1))
)
ENGINE = Merge('uptrace', '^(spans|events|logs)_data$')

-- Table: tracing_group_hours
CREATE TABLE uptrace.tracing_group_hours
(
    `project_id` UInt32 CODEC(DoubleDelta, ZSTD(1)),
    `group_id` UInt64 CODEC(Delta(8), ZSTD(1)),
    `type` LowCardinality(String) CODEC(ZSTD(1)),
    `system` LowCardinality(String) CODEC(ZSTD(1)),
    `name` LowCardinality(String) CODEC(ZSTD(1)),
    `event_name` LowCardinality(String) CODEC(ZSTD(1)),
    `display_name` String CODEC(ZSTD(1)),
    `time` DateTime CODEC(Delta(4), ZSTD(1)),
    `max_time` SimpleAggregateFunction(max, DateTime64(6)) CODEC(ZSTD(1)),
    `duration` AggregateFunction(quantilesTDigestWeighted(0.5, 0.9, 0.99), Float32, UInt32) CODEC(ZSTD(1)),
    `max_duration` SimpleAggregateFunction(max, Int64) CODEC(ZSTD(1)),
    `count` UInt64 CODEC(Delta(8), ZSTD(1)),
    `all_keys` AggregateFunction(groupUniqArrayArray(1000), Array(String)) CODEC(ZSTD(1)),
    `kind` Enum8('internal' = 0, 'server' = 1, 'client' = 2, 'producer' = 3, 'consumer' = 4) CODEC(ZSTD(1)),
    `status_code` Enum8('unset' = 0, 'error' = 1, 'ok' = 2) CODEC(ZSTD(1)),
    `service_namespace` LowCardinality(String) CODEC(ZSTD(1)),
    `deployment_environment` LowCardinality(String) CODEC(ZSTD(1)),
    `service_name` LowCardinality(String) CODEC(ZSTD(1)),
    `service_version` LowCardinality(String) CODEC(ZSTD(1)),
    `host_name` LowCardinality(String) CODEC(ZSTD(1))
)
ENGINE = SummingMergeTree
PARTITION BY toDate(time)
PRIMARY KEY (project_id, type, system, group_id, time)
ORDER BY (project_id, type, system, group_id, time, kind, status_code, deployment_environment, service_namespace, service_name, service_version, host_name)
TTL toDate(time) + toIntervalDay(14)
SETTINGS storage_policy = 'default', ttl_only_drop_parts = 1, index_granularity = 8192

-- Table: tracing_group_hours_mv
CREATE MATERIALIZED VIEW uptrace.tracing_group_hours_mv TO uptrace.tracing_group_hours
(
    `project_id` UInt32,
    `type` LowCardinality(String),
    `system` LowCardinality(String),
    `group_id` UInt64,
    `name` String,
    `event_name` String,
    `display_name` String,
    `time` DateTime,
    `max_time` SimpleAggregateFunction(max, DateTime64(6)),
    `duration` AggregateFunction(quantilesTDigestWeighted(0.5, 0.9, 0.99), Float32, UInt32),
    `max_duration` SimpleAggregateFunction(max, Int64),
    `count` UInt32,
    `all_keys` AggregateFunction(groupUniqArrayArray(1000), Array(String)),
    `kind` Enum8('internal' = 0, 'server' = 1, 'client' = 2, 'producer' = 3, 'consumer' = 4),
    `status_code` Enum8('unset' = 0, 'error' = 1, 'ok' = 2),
    `deployment_environment` LowCardinality(String),
    `service_namespace` LowCardinality(String),
    `service_name` LowCardinality(String),
    `service_version` LowCardinality(String),
    `host_name` LowCardinality(String)
)
AS SELECT
    s.project_id,
    s.type,
    s.system,
    s.group_id,
    any(s.name) AS name,
    any(s.event_name) AS event_name,
    any(s.display_name) AS display_name,
    toStartOfHour(s.time) AS time,
    max(s.max_time) AS max_time,
    quantilesTDigestWeightedMergeState(0.5, 0.9, 0.99)(s.duration) AS duration,
    max(s.max_duration) AS max_duration,
    sumWithOverflow(s.count) AS count,
    groupUniqArrayArrayMergeState(1000)(s.all_keys) AS all_keys,
    s.kind,
    s.status_code,
    s.deployment_environment,
    s.service_namespace,
    s.service_name,
    s.service_version,
    s.host_name
FROM uptrace.tracing_group_minutes AS s
GROUP BY
    s.project_id,
    s.type,
    s.system,
    s.group_id,
    toStartOfHour(s.time),
    s.kind,
    s.status_code,
    s.deployment_environment,
    s.service_namespace,
    s.service_name,
    s.service_version,
    s.host_name

-- Table: tracing_group_minutes
CREATE TABLE uptrace.tracing_group_minutes
(
    `project_id` UInt32 CODEC(DoubleDelta, ZSTD(1)),
    `type` LowCardinality(String) CODEC(ZSTD(1)),
    `system` LowCardinality(String) CODEC(ZSTD(1)),
    `group_id` UInt64 CODEC(Delta(8), ZSTD(1)),
    `name` LowCardinality(String) CODEC(ZSTD(1)),
    `event_name` LowCardinality(String) CODEC(ZSTD(1)),
    `display_name` String CODEC(ZSTD(1)),
    `time` DateTime CODEC(Delta(4), ZSTD(1)),
    `max_time` SimpleAggregateFunction(max, DateTime64(6)) CODEC(ZSTD(1)),
    `duration` AggregateFunction(quantilesTDigestWeighted(0.5, 0.9, 0.99), Float32, UInt32) CODEC(ZSTD(1)),
    `max_duration` SimpleAggregateFunction(max, Int64) CODEC(ZSTD(1)),
    `count` UInt32 CODEC(Delta(4), ZSTD(1)),
    `all_keys` AggregateFunction(groupUniqArrayArray(1000), Array(String)) CODEC(ZSTD(1)),
    `kind` Enum8('internal' = 0, 'server' = 1, 'client' = 2, 'producer' = 3, 'consumer' = 4) CODEC(ZSTD(1)),
    `status_code` Enum8('unset' = 0, 'error' = 1, 'ok' = 2) CODEC(ZSTD(1)),
    `deployment_environment` LowCardinality(String) CODEC(ZSTD(1)),
    `service_namespace` LowCardinality(String) CODEC(ZSTD(1)),
    `service_name` LowCardinality(String) CODEC(ZSTD(1)),
    `service_version` LowCardinality(String) CODEC(ZSTD(1)),
    `host_name` LowCardinality(String) CODEC(ZSTD(1))
)
ENGINE = SummingMergeTree
PARTITION BY toDate(time)
PRIMARY KEY (project_id, type, system, group_id, time)
ORDER BY (project_id, type, system, group_id, time, kind, status_code, deployment_environment, service_namespace, service_name, service_version, host_name)
TTL toDate(time) + toIntervalDay(14)
SETTINGS storage_policy = 'default', ttl_only_drop_parts = 1, index_granularity = 8192

