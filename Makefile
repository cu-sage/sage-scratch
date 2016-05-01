docker:
    docker build -t scratch-editor:$(BUILD_NUMBER) .

deploy:
    -docker stop sage-editor
    -docker rm sage-editor
    docker run -p 8085:80 --name sage-editor --net sagenetwork -d sage-editor:$(DEPLOY_TAG)