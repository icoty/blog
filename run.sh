#!/in/bash

ps -ef | grep "4000" | head -n 2 | awk '{print $2}' | xargs kill -9
hexo clean
hexo generate
#hexo deploy
#hexo server

nohup hexo server &
