docker:
	docker build -t scratch-editor:$(BUILD_NUMBER) .

deploy:
	-docker stop scratch-editor
	-docker rm scratch-editor
	docker run -p 8085:80 --name scratch-editor --net sagenetwork -d scratch-editor:$(DEPLOY_TAG)