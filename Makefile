git:
	git submodule init
	git submodule update

s:
	hugo server

# 部署由 GitHub Actions 自动完成（push master 即触发），这里只需推送
deploy:
	git push origin master
commit:
	git add --all . && git commit -am "Update" && git push origin master
