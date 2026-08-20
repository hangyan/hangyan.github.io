# 涯余的博客

Hugo 博客，主题为 [even](https://github.com/olOwOlo/hugo-theme-even)（以 git submodule 方式引入）。

## 本地开发

1. 初始化主题子模块（首次克隆后执行一次）：

   ```bash
   git submodule update --init
   ```

2. 安装 Hugo（需要 Extended 版）。版本与 `.github/workflows/pages.yml` 中的 `HUGO_VERSION` 保持一致（当前 0.139.0）。

3. 启动本地预览：

   ```bash
   hugo server
   ```

   新增文章放在 `content/post/`，以 `yyyy-mm-dd-标题.md` 命名，记得在 front matter 里写 `date` 和 `tags`。

## 部署

推送到 `master` 分支即可，GitHub Actions（`.github/workflows/pages.yml`）会自动构建并发布到 GitHub Pages。
