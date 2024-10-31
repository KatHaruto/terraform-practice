FROM fluent/fluentd:v1.17-1

USER root
RUN apk add --update --no-cache tzdata && \
    cp /usr/share/zoneinfo/Asia/Tokyo /etc/localtime && \
    echo Asia/Tokyo > /etc/timezone && \
    apk del tzdata

RUN gem install fluent-plugin-s3 --no-document

USER fluent

ARG S3_BUCKET_NAME
ARG AWS_REGION

ENV S3_BUCKET_NAME=$S3_BUCKET_NAME
ENV AWS_REGION=$AWS_REGION
COPY fluent.conf /fluentd/etc/my_fluent.conf

EXPOSE 24224