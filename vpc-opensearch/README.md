### ※ opensearch dashboard (旧 kibana)へのアクセス

session manager を使ったポートフォワーディングを行って踏み台経由でアクセス

```sh
aws ssm start-session \
--profile <profile_name> \
--target <bastion-instance-id>  \
--document-name AWS-StartPortForwardingSessionToRemoteHost \
--parameters  '{"host":["<opensearch-endpoint>"],"portNumber":["443"],"localPortNumber":["10443"]}'
```

ブラウザを開いて以下 URL へアクセス  
<https://localhost:10443/_dashboards/app/home>  
(※ Chrome で警告が出る場合、chrome://flags から`Allow invalid certificates for resources loaded from localhost.`
を有効にする)
