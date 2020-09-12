deploy:
	bash deploy.sh
commit:
	git add --all . && git commit -am "Update" && git push origin master