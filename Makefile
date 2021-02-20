git:
	git submodule init
	git submodule update

s:
	hugo server
deploy:
	bash deploy.sh
commit:
	git add --all . && git commit -am "Update" && git push origin master
