FROM golang:1.22 AS build-env

# 作業ディレクトリを設定
WORKDIR /app

# 必要なGoのモジュールをコピー
COPY go.mod .
COPY go.sum .

# 依存関係をダウンロード
RUN go mod download

# ソースコードをコピー
COPY . .

# バイナリをビルド
RUN CGO_ENABLED=0 GOOS=linux go build -o main .

# ランタイムイメージのステージ
FROM gcr.io/distroless/base-debian10

# ビルドされたバイナリをコピー
COPY --from=build-env /app/main /app/main

# ポート8080を公開
EXPOSE 8080

# アプリケーションを実行
CMD ["/app/main"]
