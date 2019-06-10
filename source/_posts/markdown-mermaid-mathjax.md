---
title: Hexo引入Mermaid流程图和MathJax数学公式
date: 2019-05-23 00:30:10
tags: [Mermaid,MathJax,MarkDown]
categories:
  - [Hexo]
copyright: true
mathjax: true
---

近来用Markdown写文章，越来越不喜欢插入图片了，一切能用语法解决的问题坚决不放图，原因有二：

1. 如果把流程图和数学公式都以图片方式放到文章内，当部署到Github上后，访问博客时图片加载实在太慢，有时一篇文章需要画10来个流程图，那你就得截图10来多次，还得给这些图片想一个合适的名字，同时插入图片的时候还要注意图片的插入位置和顺序；

2. 如果你要把文章发布到其他博客平台，如CSDN、博客园，在每一个平台上你都要插入10来多次图片，作为程序员，这种笨拙又耗时的方法，我实在不能忍。

于是愤而搜索，[Mermaid语法](https://github.com/knsv/mermaid)可实现流程图功能，[MathJax语法](https://math.meta.stackexchange.com/questions/5020/mathjax-basic-tutorial-and-quick-reference/5044%20MathJax%20basic%20tutorial%20and%20quick%20reference)可实现数学公式和特殊符号的功能，只需要遵循其语法规则即可，这也不由得让我想起：“苏乞儿打完降龙十八掌前17掌之后幡然领悟出第18掌的奥妙时说的那句话：我实在是太聪明了！”。下面都以next主题为例，我的主题是<https://github.com/theme-next/hexo-theme-next>

## Mermaid

1. 如果你用的主题和我的主题仓库是同一个，你只需修改blog/themes/next/_config.yml内mermaid模块enable为true，其他的啥也不用做。

```bash
$cd blog/  # 走到博客根目录
$yarn add hexo-filter-mermaid-diagrams  # 安装mermaid插件

# Mermaid tag
mermaid:
  enable: true
  # Available themes: default | dark | forest | neutral
  theme: forest
  cdn: //cdn.jsdelivr.net/npm/mermaid@8/dist/mermaid.min.js
  #cdn: //cdnjs.cloudflare.com/ajax/libs/mermaid/8.0.0/mermaid.min.js
```
2. 如果你的不是next主题或者你的next主题是github上旧版本仓库，你首先需要查看themes/next/_config.yml内是否有mermaid模块，如果有，按照前面的方法1，执行完方法1后，如果不奏效，不要改回去，接着下面的内容继续配置。如果没有mermaid模块，仍然着接下面内容继续配置。

- 编辑博客根目录下的blog/_config.yml，在最后添加如下内容：
```bash
# mermaid chart
mermaid: ## mermaid url https://github.com/knsv/mermaid
  enable: true  # default true
  version: "7.1.2" # default v7.1.2
  options:  # find more api options from https://github.com/knsv/mermaid/blob/master/src/mermaidAPI.js
    #startOnload: true  // default true
```
- 编辑blog/themes/next/layout/_partials/footer.swig，在最后添加如下内容：
```bash
{% if theme.mermaid.enable %}
  <script src='https://unpkg.com/mermaid@{{ theme.mermaid.version }}/dist/mermaid.min.js'></script>
  <script>
    if (window.mermaid) {
      mermaid.initialize({{ JSON.stringify(theme.mermaid.options) }});
    }
  </script>
{% endif %}
```
如果你的主题下没有footer.swig文件，你需要在你的主题目录下搜索文件名为after-footer.ejs和after_footer.pug的文件，根据文件名的不同在其最后添加不同的内容，这点在github上的 [hexo-filter-mermaid-diagrams](https://github.com/webappdevelp/hexo-filter-mermaid-diagrams) 教程已经明确交代了。
```bash
# 若是after_footer.pug，在最后添加内容
if theme.mermaid.enable == true
  script(type='text/javascript', id='maid-script' mermaidoptioins=theme.mermaid.options src='https://unpkg.com/mermaid@'+ theme.mermaid.version + '/dist/mermaid.min.js' + '?v=' + theme.version)
  script.
    if (window.mermaid) {
      var options = JSON.parse(document.getElementById('maid-script').getAttribute('mermaidoptioins'));
      mermaid.initialize(options);
    }

# 若是after-footer.ejs，在最后添加
<% if (theme.mermaid.enable) { %>
  <script src='https://unpkg.com/mermaid@<%= theme.mermaid.version %>/dist/mermaid.min.js'></script>
  <script>
    if (window.mermaid) {
      mermaid.initialize({theme: 'forest'});
    }
  </script>
<% } %>
```
- 最后，赶紧部署到github上观看效果吧，如果不奏效的话，把blog/_config.yml中的external_link设置为false和设置为true都试下，这点在github教程上也已经交代了，因为我的next版本不涉及这个问题，请君多试。
```bash
!!!Notice: if you want to use 'Class diagram', please edit your '_config.yml' file, set external_link: false. - hexo bug.
```
3. 前两步做完后，如果都不奏效，这里还有一招绝杀技，那就是打开blog/public目录下你写的文章的index.html。
- 搜索“mermaid”，所有的流程图都应该是括在一个标签类的，如果你的流程图没有class = “mermaid”，那就是第一步安装的hexo-filter-mermaid-diagrams插件没有解析成功，可能是hexo，node，yarn版本问题所致。
```bash
# 流程图解析为：<pre class="mermaid">流程图</pre>
<pre class="mermaid">graph LR
A[Bob<br>输入明文P] -->|P|B["Bob的私钥PRbob<br>加密算法(如RSA)<br>C=E(PRbob,P)"];
B -->|传输数字签名C|C["Alice的公钥环{PUbob,……}<br>解密算法(如RSA)<br>P=D(PUbob,C)"];
C -->|P|D["Alice<br>输出明文P"];</pre>
```
- 若流程图确实解析成功了，但是web仍然不显示流程图，说明js文件引入失败，继续在index.html中搜索“mermaid.min.js”，正常情况下需要有如下内容，如果没有，在文件最后的"body"之前添加上，之后再部署观看效果，到此理论上应该可以了，如果还是不行，仔细检查下有没有遗漏步骤，考验你解bug的时候到了。
```bash
  <script src="https://unpkg.com/mermaid@7.1.2/dist/mermaid.min.js"></script>
  <script>
    if (window.mermaid) {
      mermaid.initialize({theme: 'forest'});
    }
  </script>
```


## MathJax
我的主题只需修改blog/themes/next/_config.yml内math模块enable为true即可，不需要安装任何插件，修改之后，在文章的Front Matter栏添加"mathjax: true"才能解析，其他主题也可以试下该方法可行否，都大同小异。
```bash
# Math Equations Render Support
math:
  enable: true		 # 这里改为true

  # Default (true) will load mathjax / katex script on demand.
  # That is it only render those page which has `mathjax: true` in Front Matter.
  # If you set it to false, it will load mathjax / katex srcipt EVERY PAGE.
  per_page: true

  engine: mathjax
  #engine: katex

  # hexo-rendering-pandoc (or hexo-renderer-kramed) needed to full MathJax support.
  mathjax:
    cdn: //cdn.jsdelivr.net/npm/mathjax@2/MathJax.js?config=TeX-AMS-MML_HTMLorMML
    #cdn: //cdnjs.cloudflare.com/ajax/libs/mathjax/2.7.5/MathJax.js?config=TeX-MML-AM_CHTML

    # See: https://mhchem.github.io/MathJax-mhchem/
    #mhchem: //cdn.jsdelivr.net/npm/mathjax-mhchem@3
    #mhchem: //cdnjs.cloudflare.com/ajax/libs/mathjax-mhchem/3.3.0

  # hexo-renderer-markdown-it-plus (or hexo-renderer-markdown-it with markdown-it-katex plugin) needed to full Katex support.
  katex:
    cdn: //cdn.jsdelivr.net/npm/katex@0/dist/katex.min.css
    #cdn: //cdnjs.cloudflare.com/ajax/libs/KaTeX/0.7.1/katex.min.css

    copy_tex:
      # See: https://github.com/KaTeX/KaTeX/tree/master/contrib/copy-tex
      enable: false
      copy_tex_js: //cdn.jsdelivr.net/npm/katex@0/dist/contrib/copy-tex.min.js
      copy_tex_css: //cdn.jsdelivr.net/npm/katex@0/dist/contrib/copy-tex.min.css
```

```bash
# 文章引入方式
---
title: 常用加密算法的应用
date: 2019-05-20 13:58:36
tags: [对称加密算法,非对称加密算法/公钥算法,Hash函数/散列函数/摘要函数,消息认证,流密码,数字签名/指纹/消息摘要]
categories:
  - [密码学与信息安全]
copyright: true
mathjax: true	  # 添加这行，文章才会解析
---
```

## 参考文献

[MathJax语法规则](https://math.meta.stackexchange.com/questions/5020/mathjax-basic-tutorial-and-quick-reference/5044%20MathJax%20basic%20tutorial%20and%20quick%20reference)
[Mermaid语法规则](https://www.jianshu.com/p/7ddbb7dc8fec)
[Mermaid官方教程](https://mermaidjs.github.io/demos.html)
[Mermaid Github仓库](https://github.com/webappdevelp/hexo-filter-mermaid-diagrams)
[MathJax Github仓库](https://github.com/mathjax/MathJax)

