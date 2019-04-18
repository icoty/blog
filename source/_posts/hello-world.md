---
title: Linux下Docker快速部署LAMP
tags: [LAMP, Docker, Linux, MVC]
categories: [IDE]
---
若你的mac或Linux环境上未安装Docker，请移步[Docker安装](http://www.runoob.com/docker/ubuntu-docker-install.html)，确认安装成功之后再进行下文内容。

## Quick Start

### 获取基础镜像

``` bash
$ docker pull tutum/lamp  # 从Docker Hub上的tutum用户的仓库获取lamp镜像
$ docker images  # 列出所有的镜像，会发现多一条记录：tutum/lamp
```
本文用的镜像源[tutum/lamp](https://hub.docker.com/r/tutum/lamp)，目前Docker 官方维护了一个公共仓库 Docker Hub，其中已经包括了数量超过 15,000 的镜像，开发者可以注册自己的账号，并自定义自己的镜像进行存储，需要的时候可以直接拿来用，同时也能够分享，有点类似于Github。如想注册可移步 [Docker Hub](https://hub.docker.com)。

### 自定义你的镜像

在一个空的目录下新建Dockerfile文件名，填入如下4行内容。
``` bash
FROM tutum/lamp:latest  # 表示在镜像tutum/lamp:latest之上自定义你的镜像
RUN rm -fr /app  # 后面会把你的php项目映射到容器的/app/目录下
EXPOSE 80 3306   # 暴露80 3306端口
CMD ["/run.sh"]   # 当容器启动后会自动执行容器内部的/run.sh脚本
```
在Dockerfile的同级目录执行如下命令，该命令会去执行Dockerfile脚本，并构建新的镜像username/my-lamp-app，其中my-lamp-app为自定义的镜像名字，命名成你的即可。如果注册了docker hub，一般将username换层你的用户名，如未注册，可以随便取。我执行的是：“docker build -t icoty1/lamp .”
``` bash
$ docker build -t username/my-lamp-app .
```

### 基于你的镜像运行一个容器

``` bash
$ docker run -d -v /home/icoty/app/:/app/ -p 80:80 -p 3306:3306 username/my-lamp-app
```
1. -v /home/icoty/app/:/app/ 表示将/home/icoty/app/目录映射到容器内部的/app/目录，其中/home/icoty/app/为我的php项目存放位置，需要换成你的。
2. -p 80:80 表示将本机的80端口映射到容器内部的80端口，在容器外面是无法直接访问容器内部端口的，映射后才可以，这样当本机80端口收到数据后会自动转发给容器内部的80端口，不过在容器内部是可以直接访问其他远程主机的，这点保证了容器的封闭性和安全性。
3. username/my-lamp-app 为前面自定义的镜像名称。

### 权限修改

``` bash
$ docker ps -a   # 查看上一步运行的容器，找到username/my-lamp-app对应的CONTAINER ID
$ docker exec -it ID /bin/bash   # 根据容器ID进入容器，其中ID为前一句找到的CONTAINER ID
$ chown -R www-data:www-data /app/   # 将php项目目录权限修改为运行apache的用户组，否则会因为权限不够，web页面打不开
```

### 访问测试

``` bash
http://ip/public/index.php
```
注意：/app/目录下的各个子目录下如果存在.htaccess 文件，会导致web页面无法访问对应子目录，只需将.htaccess重命名为.htaccess.bak即可解决。