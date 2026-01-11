class ArticlesController < ApplicationController
  before_action :set_article, only: %i[show edit update destroy]

  def index
    @articles = Article.by_priority
  end

  def show
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.update('side-panel', partial: 'articles/show_panel', locals: { article: @article })
      end
      format.html
    end
  end

  def new
    @article = Article.new
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.update('side-panel', partial: 'articles/new_panel', locals: { article: @article })
      end
      format.html
    end
  end

  def edit
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.update('side-panel', partial: 'articles/edit_panel', locals: { article: @article })
      end
      format.html
    end
  end

  def create
    @article = Article.new(article_params)
    @article.user = current_user

    if @article.save
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.update('articles-list', partial: 'articles/list', locals: { articles: Article.by_priority }),
            turbo_stream.append('side-panel', "<div data-controller='side-panel-closer'></div>".html_safe)
          ]
        end
        format.html { redirect_to articles_path, notice: 'Article was successfully created.' }
      end
    else
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.update('side-panel', partial: 'articles/new_panel', locals: { article: @article }), status: :unprocessable_entity
        end
        format.html { render :new, status: :unprocessable_entity }
      end
    end
  end

  def update
    if @article.update(article_params)
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.update('articles-list', partial: 'articles/list', locals: { articles: Article.by_priority }),
            turbo_stream.append('side-panel', "<div data-controller='side-panel-closer'></div>".html_safe)
          ]
        end
        format.html { redirect_to articles_path, notice: 'Article was successfully updated.' }
      end
    else
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.update('side-panel', partial: 'articles/edit_panel', locals: { article: @article }), status: :unprocessable_entity
        end
        format.html { render :edit, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @article.destroy
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.update('articles-list', partial: 'articles/list', locals: { articles: Article.by_priority }),
          turbo_stream.append('side-panel', "<div data-controller='side-panel-closer'></div>".html_safe)
        ]
      end
      format.html { redirect_to articles_path, notice: 'Article was successfully destroyed.' }
    end
  end

  private

  def set_article
    @article = Article.find(params[:id])
  end

  def article_params
    params.require(:article).permit(:title, :description, :pinned, :tag_list)
  end
end
