import json
import boto3
import time
from botocore.client import ClientError
from datetime import datetime
import os

rds = boto3.client('rds')
s3 = boto3.resource('s3')
S3_BUCKET_NAME=os.environ["S3_BUCKET"] 
RDS_INSTANCE_ID=os.environ["RDS_INSTANCE_ID"]
IAM_ROLE_ARN=os.environ["SNAPSHOT_IAM_ROLE"]
KMS_KEY_ID=os.environ["KMS_KEY_ID"]


# create_snapshot()を呼び出せば、[prefix-YYYY-mm-dd-HH-MM]というスナップショットの作成が始まるように定義    
def create_snapshot(prefix, instanceid):
    newsnapshotid = "-".join([prefix, datetime.now().strftime("%Y-%m-%d-%H-%M")])
    rds.create_db_snapshot(
        DBSnapshotIdentifier=newsnapshotid,
        DBInstanceIdentifier=instanceid
    )
    
# check_snapshot_created()を呼び出すと、RDSのStatusが「available」になるまで待機する関数
# lambda_handler()にて、create_snapshot()と同時に呼び出すことで、スナップショットを作成可能な状態まで待ってスナップショット作成の処理が走るように定義している。
def check_snapshot_created(prefix, instanceid):
    snapshots = rds.describe_db_snapshots(DBInstanceIdentifier=instanceid)['DBSnapshots']
    # RDSのStatusが「available」でなければ、２０秒間待機して、check_snapshot_createdをもう一度呼び出すということを繰り返す。
    for snapshot in snapshots:
        if snapshot['Status'] != "available":
            time.sleep(20)
            check_snapshot_created(prefix, instanceid)
            
def export_snapshot(prefix, instanceid):
    # rdsのスナップショットの情報を`snapshots`に入れる
    snapshots = rds.describe_db_snapshots(DBInstanceIdentifier=instanceid, SnapshotType='manual')['DBSnapshots']
    # snapshotが新しい順にソートして、`snapshots`に入れる
    snapshots = sorted(snapshots, key=lambda x: x['SnapshotCreateTime'], reverse=True)
    # 一番新しいスナップショットを`snapshot`に入れる
    snapshot = snapshots[0]
    newsnapshotid = "-".join([prefix, datetime.now().strftime("%Y-%m-%d-%H-%M")])

    # 一番新しいスナップショットをS3にエクスポートする
    response = rds.start_export_task(
        ExportTaskIdentifier=newsnapshotid,
        SourceArn=snapshot['DBSnapshotArn'],
        S3BucketName=S3_BUCKET_NAME,
        S3Prefix=RDS_INSTANCE_ID,
        IamRoleArn=IAM_ROLE_ARN,
        KmsKeyId=KMS_KEY_ID,
        )
    return(response)
    
            
def lambda_handler(event, context):
    bucket = s3.Bucket(S3_BUCKET_NAME)
    snapshot_prefix = 'snapshot'
    instance = RDS_INSTANCE_ID

    # スナップショットを作成
    create_snapshot(snapshot_prefix, instance)
    # スナップショットが作成可能な状態になるまで待機
    check_snapshot_created(snapshot_prefix, instance)
    
    # s3のオブジェクトを削除
    bucket.objects.filter(Prefix=RDS_INSTANCE_ID).delete()
    export_snapshot(snapshot_prefix, instance)