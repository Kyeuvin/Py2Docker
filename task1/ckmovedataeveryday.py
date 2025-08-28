import pyodbc
import time
from clickhouse_driver import Client
from datetime import datetime, timedelta
import logging
import requests
import sys
import os

# 解决ssl问题
os.environ['OPENSSL_CONF'] = '/etc/ssl/tls1.cnf'

# 配置日志
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    filename='sync_log.log'
)

# 数据库配置
SQLSERVER_CONFIGS = [
    {
        'name': 'ENTA',  # 数据源名称
        'driver': 'ODBC Driver 17 for SQL Server',
        'server': '192.168.1.56\\new',
        'database': 'ENTA',
        'username': 'sa',
        'password': 'dongli~!sql2000'
    },
    # 可以添加更多数据源配置
    {
        'name': 'B2BPlatform',
        'driver': 'ODBC Driver 17 for SQL Server',
        'server': '192.168.1.234',
        'database': 'B2BPlatform',
        'username': 'sa',
        'password': 'b2bdongli()##'
    },
    {
        'name': 'SSDB',
        'driver': 'ODBC Driver 17 for SQL Server',
        'server': '192.168.1.244\\SQL2005',
        'database': 'SSDB',
        'username': 'sa',
        'password': 'ioeterm2005'
    },
    {
        'name': 'dlfreightrate',
        'driver': 'ODBC Driver 17 for SQL Server',
        'server': '192.168.1.242',
        'database': 'dlfreightrate',
        'username': 'sa',
        'password': 'fare2010{}!~'
    }
]

CLICKHOUSE_CONFIG = {
    'host': '192.168.1.7',
    'port': 9000,
    'database': 'ENTA',
    'user': 'default',
    'password': ''
}

# ODBC Driver 17 for SQL Server 到 ClickHouse 的类型映射
SQLSERVER_TO_CLICKHOUSE_TYPE_MAP = {
    'bit': 'UInt8',
    'tinyint': 'UInt8',
    'smallint': 'Int16',
    'int': 'Int32',
    'bigint': 'Int64',
    'decimal': 'Decimal',
    'numeric': 'Decimal',
    'float': 'Float64',
    'real': 'Float32',
    'money': 'Decimal(18,4)',
    'smallmoney': 'Decimal(10,4)',
    'char': 'String',
    'varchar': 'String',
    'text': 'String',
    'nchar': 'String',
    'nvarchar': 'String',
    'ntext': 'String',
    'date': 'Date',
    'datetime': 'DateTime',
    'datetime2': 'DateTime64',
    'smalldatetime': 'DateTime',
    'time': 'String',
    'binary': 'String',
    'varbinary': 'String',
    'image': 'String',
    'uniqueidentifier': 'UUID',
    'xml': 'String'
}


def get_sqlserver_connection(source_name=None):
    """
    获取ODBC Driver 17 for SQL Server连接
    :param source_name: 数据源名称，如果为None则使用第一个配置
    :return: 数据库连接
    """
    config = next((cfg for cfg in SQLSERVER_CONFIGS if cfg['name'] == source_name), SQLSERVER_CONFIGS[0])
    conn_str = (
        f"DRIVER={{{config['driver']}}};"
        f"SERVER={config['server']};"
        f"DATABASE={config['database']};"
        f"UID={config['username']};"
        f"PWD={config['password']};"
        f"Connection Timeout=30;"
        f"Encrypt=no;"
        f"TrustServerCertificate=yes;"
    )
    # return pyodbc.connect(conn_str)
    try:
        logging.info(f"尝试连接 SQL Server 2008 数据源: {source_name}")
        logging.info(f"连接字符串: {conn_str.replace(config['password'], '***')}")
        return pyodbc.connect(conn_str)
    except Exception as e:
        logging.error(f"连接数据源 {source_name} 失败: {str(e)}")
        raise e


def get_clickhouse_connection():
    return Client(
        host=CLICKHOUSE_CONFIG['host'],
        port=CLICKHOUSE_CONFIG['port'],
        database=CLICKHOUSE_CONFIG['database'],
        user=CLICKHOUSE_CONFIG['user'],
        password=CLICKHOUSE_CONFIG['password']
    )


def get_last_sync_time(table_name):
    try:
        with open(f'last_sync_{table_name}.txt', 'r') as f:
            return datetime.fromisoformat(f.read().strip())
    except FileNotFoundError:
        return datetime(2023, 1, 1)  # 如果文件不存在，默认从 2023-10-01 开始


def save_last_sync_time(table_name, sync_time):
    with open(f'last_sync_{table_name}.txt', 'w') as f:
        f.write(sync_time.isoformat())


def get_table_schema(sql_cursor, table_name):
    schema_query = """
    SELECT 
        c.name AS column_name,
        t.name AS data_type,
        c.max_length,
        c.precision,
        c.scale,
        c.is_nullable,
        CASE WHEN pk.column_id IS NOT NULL THEN 1 ELSE 0 END AS is_primary_key
    FROM sys.columns c
    INNER JOIN sys.types t ON c.user_type_id = t.user_type_id
    LEFT JOIN (
        SELECT i.object_id, ic.column_id
        FROM sys.indexes i
        INNER JOIN sys.index_columns ic ON i.object_id = ic.object_id AND i.index_id = ic.index_id
        WHERE i.is_primary_key = 1
    ) pk ON c.object_id = pk.object_id AND c.column_id = pk.column_id
    WHERE c.object_id = OBJECT_ID(?)
    ORDER BY c.column_id
    """
    sql_cursor.execute(schema_query, (table_name,))
    return sql_cursor.fetchall()


def get_clickhouse_type(sql_type, max_length, precision, scale):
    base_type = sql_type.lower()

    if base_type in ['decimal', 'numeric']:
        precision = precision or 38
        scale = scale or 0
        return f'Decimal({precision}, {scale})'

    if base_type in ['varchar', 'nvarchar', 'char', 'nchar']:
        return 'String'

    if base_type == 'datetime2':
        return 'DateTime64(3)'

    return SQLSERVER_TO_CLICKHOUSE_TYPE_MAP.get(base_type, 'String')


def create_clickhouse_table(ch_client, table_name, schema, primary_key_columns=None):
    columns = []
    schema_primary_keys = []

    for col in schema:
        column_name = col.column_name
        ch_type = get_clickhouse_type(col.data_type, col.max_length, col.precision, col.scale)
        nullable = 'Nullable(' + ch_type + ')' if col.is_nullable else ch_type
        columns.append(f"`{column_name}` {nullable}")

        if col.is_primary_key:
            schema_primary_keys.append(column_name)

    # 使用指定的主键或从 schema 中获取的主键
    primary_keys = primary_key_columns or schema_primary_keys or [schema[0].column_name]

    create_query = f"""
    CREATE TABLE IF NOT EXISTS {table_name} (
        {','.join(columns)}
    ) ENGINE = ReplacingMergeTree()
    ORDER BY ({', '.join(f'`{pk}`' for pk in primary_keys)})
    """

    try:
        ch_client.execute(create_query)
        logging.info(f"表 {table_name} 创建成功")
    except Exception as e:
        logging.error(f"创建表 {table_name} 失败: {str(e)}")
        raise


def convert_row_values(row):
    return [
        ('' if value is None and isinstance(value, str) else
         0 if value is None and isinstance(value, (int, float)) else
         datetime(1970, 1, 1) if value is None and isinstance(value, datetime) else
         value)
        for value in row
    ]


def format_value_for_sql(value):
    if isinstance(value, (int, float)):
        return str(value)
    elif isinstance(value, datetime):
        return f"'{value.isoformat()}'"
    else:
        return f"'{str(value)}'"


def sync_table(table_name, source_name=None, batch_size=50000):
    try:
        sql_conn = get_sqlserver_connection(source_name)
        ch_client = get_clickhouse_connection()

        sql_cursor = sql_conn.cursor()
        schema = get_table_schema(sql_cursor, table_name)

        # 获取主键列
        primary_key_columns = [col.column_name for col in schema if col.is_primary_key]
        if not primary_key_columns:
            logging.warning(f"表 {table_name} 没有主键，将使用第一列作为主键")
            primary_key_columns = [schema[0].column_name]

        create_clickhouse_table(ch_client, table_name, schema, primary_key_columns)

        last_sync_time = get_last_sync_time(table_name)
        current_sync_time = datetime.now()

        sql_cursor.execute(f"SELECT TOP 1 * FROM {table_name}")
        columns = [column[0] for column in sql_cursor.description]

        # 检查更新时间字段
        update_field = None
        for col in columns:
            if col.lower() in ['updated_at', 'update_time', 'modify_time', 'TransferDate']:
                update_field = col
                break

        if not update_field:
            logging.warning(f"表 {table_name} 没有更新时间字段，将进行全量同步")
            sql_cursor.execute(f"SELECT COUNT(*) FROM {table_name}")
            total_records = sql_cursor.fetchone()[0]

            current_row = 0
            while current_row < total_records:
                query = f"""
                    WITH numbered_rows AS (
                        SELECT ROW_NUMBER() OVER (ORDER BY {', '.join(primary_key_columns)}) AS row_num, *
                        FROM {table_name}
                    )
                    SELECT {','.join([f'[{col}]' for col in columns])}
                    FROM numbered_rows
                    WHERE row_num > {current_row} AND row_num <= {current_row + batch_size}
                """

                sql_cursor.execute(query)
                batch_data = sql_cursor.fetchall()

                if not batch_data:
                    break

                rows = [convert_row_values(row) for row in batch_data]

                # 获取主键值并删除重复数据
                primary_key_indexes = [columns.index(pk) for pk in primary_key_columns]
                primary_keys = []
                for row in rows:
                    key_values = tuple(row[idx] for idx in primary_key_indexes)
                    primary_keys.append(key_values)

                if primary_keys:
                    if len(primary_key_columns) == 1:
                        delete_query = f"ALTER TABLE {table_name} DELETE WHERE {primary_key_columns[0]} IN {tuple(pk[0] for pk in primary_keys)}"
                    else:
                        conditions = []
                        for pk in primary_keys:
                            condition = f"({', '.join(format_value_for_sql(v) for v in pk)})"
                            conditions.append(condition)
                        delete_query = f"ALTER TABLE {table_name} DELETE WHERE ({', '.join(primary_key_columns)}) IN ({', '.join(conditions)})"

                    ch_client.execute(delete_query)

                insert_query = f"INSERT INTO {table_name} ({','.join(columns)}) VALUES"
                ch_client.execute(insert_query, rows)

                current_row += batch_size
                logging.info(f"已同步 {min(current_row, total_records)}/{total_records} 条记录")

            return

        # 增量同步
        count_query = f"SELECT COUNT(*) FROM {table_name} WHERE {update_field} >= ?"
        sql_cursor.execute(count_query, (last_sync_time,))
        total_records = sql_cursor.fetchone()[0]

        logging.info(f"开始增量同步表 {table_name}, 上次同步时间: {last_sync_time}, 需要同步的记录数: {total_records}")

        current_row = 0
        while current_row < total_records:
            query = f"""
                WITH numbered_rows AS (
                    SELECT ROW_NUMBER() OVER (ORDER BY {update_field}) AS row_num, *
                    FROM {table_name}
                    WHERE {update_field} >= ?
                )
                SELECT {','.join([f'[{col}]' for col in columns])}
                FROM numbered_rows
                WHERE row_num > {current_row} AND row_num <= {current_row + batch_size}
            """

            sql_cursor.execute(query, (last_sync_time,))
            batch_data = sql_cursor.fetchall()

            if not batch_data:
                break

            rows = [convert_row_values(row) for row in batch_data]

            # 获取主键值并删除重复数据
            primary_key_indexes = [columns.index(pk) for pk in primary_key_columns]
            primary_keys = []
            for row in rows:
                key_values = tuple(row[idx] for idx in primary_key_indexes)
                primary_keys.append(key_values)

            if primary_keys:
                if len(primary_key_columns) == 1:
                    delete_query = f"ALTER TABLE {table_name} DELETE WHERE {primary_key_columns[0]} IN {tuple(pk[0] for pk in primary_keys)}"
                else:
                    conditions = []
                    for pk in primary_keys:
                        condition = f"({', '.join(format_value_for_sql(v) for v in pk)})"
                        conditions.append(condition)
                    delete_query = f"ALTER TABLE {table_name} DELETE WHERE ({', '.join(primary_key_columns)}) IN ({', '.join(conditions)})"

                ch_client.execute(delete_query)

            insert_query = f"INSERT INTO {table_name} ({','.join(columns)}) VALUES"
            ch_client.execute(insert_query, rows)

            current_row += batch_size
            logging.info(f"已同步 {min(current_row, total_records)}/{total_records} 条记录")

        save_last_sync_time(table_name, current_sync_time)
        logging.info(f"表 {table_name} 同步完成")

    except Exception as e:
        logging.error(f"同步表 {table_name} 时发生错误: {str(e)}")
        raise
    finally:
        sql_conn.close()


def sync_from_query(query_name, sql_query, target_table, source_name=None, primary_key_columns=None, batch_size=50000):
    try:
        sql_conn = get_sqlserver_connection(source_name)
        ch_client = get_clickhouse_connection()
        sql_cursor = sql_conn.cursor()

        last_sync_time = get_last_sync_time(f"query_{query_name}")
        current_sync_time = datetime.now()

        sql_cursor.execute(f"SELECT TOP 1 * FROM ({sql_query}) AS t")
        columns = [column[0] for column in sql_cursor.description]

        # 如果没有指定主键，使用第一列
        if not primary_key_columns:
            primary_key_columns = [columns[0]]
            logging.warning(f"查询 {query_name} 没有指定主键，将使用第一列 {primary_key_columns[0]} 作为主键")

        # 对于 CustomerService 和 CustomerCompany，先删除表
        if target_table in ['CustomerService', 'CustomerCompany','AirWayPreCode','AIRWAYCLASS']:
            try:
                ch_client.execute(f"DROP TABLE IF EXISTS {target_table}")
                logging.info(f"已删除表 {target_table}")
            except Exception as e:
                logging.error(f"删除表 {target_table} 失败: {str(e)}")
                raise

        # 创建ClickHouse表
        create_query = f"""
        CREATE TABLE IF NOT EXISTS {target_table} (
            {','.join([f"`{col}` String" for col in columns])}
        ) ENGINE = ReplacingMergeTree()
        ORDER BY ({', '.join(f'`{pk}`' for pk in primary_key_columns)})
        """
        ch_client.execute(create_query)

        count_query = f"SELECT COUNT(*) FROM ({sql_query}) AS t"
        sql_cursor.execute(count_query)
        total_records = sql_cursor.fetchone()[0]

        logging.info(f"开始同步查询 {query_name} 到表 {target_table}, 总记录数: {total_records}")

        current_row = 0
        while current_row < total_records:
            batch_query = f"""
                WITH numbered_rows AS (
                    SELECT ROW_NUMBER() OVER (ORDER BY {', '.join(primary_key_columns)}) AS row_num, *
                    FROM ({sql_query}) AS t
                )
                SELECT {','.join([f'[{col}]' for col in columns])}
                FROM numbered_rows
                WHERE row_num > {current_row} AND row_num <= {current_row + batch_size}
            """
            print(batch_query)
            sql_cursor.execute(batch_query)
            batch_data = sql_cursor.fetchall()

            if not batch_data:
                break

            # rows = [convert_row_values(row) for row in batch_data]
            # 转换 None 为 ""
            rows = [[str(value) if value is not None else "" for value in row] for row in batch_data]

            # 获取主键值并删除重复数据
            primary_key_indexes = [columns.index(pk) for pk in primary_key_columns]
            primary_keys = []
            for row in rows:
                key_values = tuple(row[idx] for idx in primary_key_indexes)
                primary_keys.append(key_values)

            if primary_keys:
                if len(primary_key_columns) == 1:
                    delete_query = f"ALTER TABLE {target_table} DELETE WHERE {primary_key_columns[0]} IN {tuple(pk[0] for pk in primary_keys)}"
                else:
                    conditions = []
                    for pk in primary_keys:
                        condition = f"({', '.join(format_value_for_sql(v) for v in pk)})"
                        conditions.append(condition)
                    delete_query = f"ALTER TABLE {target_table} DELETE WHERE ({', '.join(primary_key_columns)}) IN ({', '.join(conditions)})"

                ch_client.execute(delete_query)

            insert_query = f"INSERT INTO {target_table} ({','.join(columns)}) VALUES"
            print(insert_query)
            print(rows)
            ch_client.execute(insert_query, rows)


            current_row += batch_size
            logging.info(f"已同步 {min(current_row, total_records)}/{total_records} 条记录")

        save_last_sync_time(f"query_{query_name}", current_sync_time)
        logging.info(f"查询 {query_name} 同步完成")

    except Exception as e:
        logging.error(f"同步查询 {query_name} 时发生错误: {str(e)}")
        raise
    finally:
        sql_conn.close()

def  sendwxmessage(messagetxt):
    url = "https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key=8e2c8435-abdd-4341-883f-ddd703f375f3"   #这里就是群机器人的Webhook地址
    headers = {"Content-Type":"application/json"}                   #http数据头，类型为json
    data = {
            "msgtype": "text",
            "text": {
                "content": messagetxt,                           #让群机器人发送的消息内容。
                "mentioned_list":["@all"]                        # @全体成员
            }
        }
    r = requests.post(url,headers=headers,json=data)                # 利用requests库发送post请求



def main():
    # 检查命令行参数
    if len(sys.argv) > 1:
        try:
            sync_date = datetime.strptime(sys.argv[1], '%Y-%m-%d')
            formatted_date = sync_date.strftime('%Y-%m-%d')
        except ValueError:
            logging.error("日期格式错误，请使用 YYYY-MM-DD 格式，例如: 2025-03-27")
            return
    else:
        sync_date = datetime.now() - timedelta(days=1)
        formatted_date = sync_date.strftime('%Y-%m-%d')

    start_time = time.time()
    logging.info(f"开始同步 {formatted_date} 的数据")

    # 定义同步配置
    sync_configs = [
        {
            'name': f'CLICKHOUSE_VIEWI_{formatted_date}',
            'query': f"""
                SELECT * FROM CLICKHOUSE_VIEWI
                WHERE TransferDate = '{formatted_date}'
            """,
            'target_table': 'CLICKHOUSE_VIEWI',
            'primary_key_columns': ['BookPID'],
            'source_name': 'ENTA'  # 指定数据源
        },
        {
            'name': f'CLICKHOUSE_VIEWD_{formatted_date}',
            'query': f"""
                SELECT * FROM CLICKHOUSE_VIEWD
                WHERE TransferDate = '{formatted_date}'
            """,
            'target_table': 'CLICKHOUSE_VIEWD',
            'primary_key_columns': ['BookPID'],
            'source_name': 'ENTA'  # 指定数据源
        },
        {
            'name': f'CustomerService_{formatted_date}',
            'query': f"""
            SELECT * FROM CustomerService      """,
            'target_table': 'CustomerService',
            'primary_key_columns': ['Id'],
            'source_name': 'B2BPlatform'  # 指定数据源
        },
        {
            'name': f'CustomerCompany_{formatted_date}',
            'query': f"""
             SELECT * FROM CustomerCompany          """,
            'target_table': 'CustomerCompany',
            'primary_key_columns': ['CompanyId'],
            'source_name': 'ENTA'  # 指定数据源
        },
        {
            'name': f'AIRWAYCLASS_{formatted_date}',
            'query': f"""
            SELECT * FROM AIRWAYCLASS          """,
            'target_table': 'AIRWAYCLASS',
            'primary_key_columns': ['AIRWAY','CLASSTYPE'],
            'source_name': 'SSDB'  # 指定数据源
        },
        {
            'name': f'AirWayPreCode_{formatted_date}',
            'query': f"""
           SELECT * FROM AirWayPreCode          """,
            'target_table': 'AirWayPreCode',
            'primary_key_columns': ['Id'],
            'source_name': 'ENTA'  # 指定数据源
        },
        {
            'name': f'CountryCityAirportState_{formatted_date}',
            'query': f"""
           SELECT * FROM CountryCityAirportState  """,
            'target_table': 'CountryCityAirportState',
            'primary_key_columns': ['ID'],
            'source_name': 'dlfreightrate'  # 指定数据源
        },
        {
            'name': f'SALEON_{formatted_date}',
            'query': f"""
               SELECT * FROM SALEON  """,
            'target_table': 'SALEON',
            'primary_key_columns': ['SALEON'],
            'source_name': 'ENTA'  # 指定数据源
        },
        {
            'name': f'CompanyThirdPart_{formatted_date}',
            'query': f"""
                   SELECT * FROM CompanyThirdPart  """,
            'target_table': 'CompanyThirdPart',
            'primary_key_columns': ['ID'],
            'source_name': 'ENTA'  # 指定数据源
        }



    ]

    # 执行所有同步任务
    for config in sync_configs:
        sync_from_query(
            query_name=config['name'],
            sql_query=config['query'],
            target_table=config['target_table'],
            source_name=config['source_name'],
            primary_key_columns=config.get('primary_key_columns')
        )
        logging.info(f"完成 {config['name']} 的数据同步")

    end_time = time.time()
    logging.info(f"所有同步任务完成，总耗时: {end_time - start_time:.2f} 秒")

    sendwxmessage('CLICKHOUSE已同步')


if __name__ == "__main__":
    main()

    # SELECT
    # SUM(toDecimal32(OUTPRICE, 2))
    # FROM
    # ENTA.CLICKHOUSE_VIEWI
    # WHERE
    # toDate(parseDateTimeBestEffortOrNull(TransferDate)) >= '2025-06-01'
    # AND
    # toDate(parseDateTimeBestEffortOrNull(TransferDate)) <= '2025-06-22'

    # SELECT
    # SUM(OUTPRICE)
    # FROM
    # CLICKHOUSE_VIEWI
    # WHERE
    # TransferDate >= '2025-06-01'
    # AND
    # TransferDate <= '2025-06-22'
