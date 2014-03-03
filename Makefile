.PHONY: post all preview deploy

all: preview

preview:
	bundle exec rake preview

post:
	./scripts/new-post.sh

deploy:
	bundle exec rake generate && bundle exec rake deploy
