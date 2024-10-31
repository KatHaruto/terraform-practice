CREATE EXTERNAL TABLE IF NOT EXISTS ${athena_database_name}.${athena_table_name} (
    source string,
    container_name string,
    container_id string,
    ecs_cluster string,
    ecs_task_arn string,
    ecs_task_definition string,
    remote string,
    host string,
    user string,
    time string,
    method string,
    path string,
    code string,
    size string,
    referer string,
    agent string,
    http_x_forwarded_for string
)
PARTITIONED BY (dt string)

ROW FORMAT  serde 'org.openx.data.jsonserde.JsonSerDe'
LOCATION '${log_s3_path}';