.PHONY: all dist

dist:
	cd api-gateway/post/src && zip -r ../post.zip ./