.PHONY: post all preview

all: preview

preview:
	bundle exec rake preview

post:
	./scripts/new-post.sh
