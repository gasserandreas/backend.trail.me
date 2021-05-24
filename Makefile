.PHONY: all dist

dist:
	cd api-gateway/calc/elevation/lambda/dist && zip -r ../dist.zip ./