aws ecr get-login-password --region $AWS_REGION --profile personal-account | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

docker build -t $CONTAINER_NAME:latest --platform linux/amd64  ./aws/sidecar/

docker tag $CONTAINER_NAME:latest $REPO_URL:latest

docker push $REPO_URL:latest
