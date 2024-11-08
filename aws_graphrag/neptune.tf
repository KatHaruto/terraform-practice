resource "aws_neptune_cluster" "this" {
  cluster_identifier                  = "graphrag-cluster-demo"
  engine                              = "neptune"
  engine_version = "1.3.4.0"
  backup_retention_period             = 1
  storage_type = "standard"
  preferred_backup_window             = "07:00-09:00"
  skip_final_snapshot                 = true
  iam_database_authentication_enabled = true
  apply_immediately                   = true
}

resource "aws_neptune_cluster_instance" "this" {
    cluster_identifier = aws_neptune_cluster.this.id
    instance_class = "db.t4g.medium"
    apply_immediately = true
    engine = "neptune"
}