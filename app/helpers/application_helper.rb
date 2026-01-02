module ApplicationHelper
  include MobileUiHelper

  # ============================================
  # アイコン定義
  # ============================================

  def plan_icon
    'fas fa-calendar-alt'
  end

  def task_icon
    'fas fa-tasks'
  end

  # ユーザーアバターまたはデフォルトの人アイコンを表示
  # @param user [User] ユーザー
  # @param size_class [String] Tailwind CSS のサイズクラス (e.g., 'w-8 h-8')
  # @param icon_class [String] Font Awesome アイコンのクラス (e.g., 'text-3xl')
  def user_avatar_tag(user, size_class: 'w-8 h-8', icon_class: 'text-3xl')
    if user&.avatar.present?
      content_tag(:img, nil,
                  src: user.avatar_data_url,
                  alt: user.display_name,
                  class: "#{size_class} rounded-full object-cover")
    else
      content_tag(:i, nil, class: "fas fa-user #{icon_class}")
    end
  end

  # ============================================
  # テキスト処理
  # ============================================

  # プレーンテキスト中のURLをリンクに変換する
  # スキーム付きURL（http://, https://）のみをリンク化
  # @param text [String] 変換対象のテキスト
  # @return [ActiveSupport::SafeBuffer] HTML安全な文字列
  def linkify_urls(text)
    return ''.html_safe if text.blank?

    # URLの正規表現（スキーム必須）
    # https://example.com, http://example.com/path?query=value など
    url_regex = %r{
      https?://\S+           # スキーム＋任意の非空白文字
    }x

    # テキストをエスケープしてからURL部分をリンクに変換
    escaped_text = ERB::Util.html_escape(text)

    # URLをリンクタグに変換
    linked_text = escaped_text.gsub(url_regex) do |url|
      # 末尾の句読点を除外
      trailing = ''
      while url =~ /[.,;:!?)\]]+\z/
        trailing = ::Regexp.last_match(0) + trailing
        url = url[0...-::Regexp.last_match(0).length]
      end

      # マッチしたURLをリンクに変換
      "<a href=\"#{ERB::Util.html_escape(url)}\" target=\"_blank\" rel=\"noopener noreferrer\">#{ERB::Util.html_escape(url)}</a>#{trailing}"
    end

    # 改行をHTMLの<br>タグに変換
    linked_text.gsub!("\n", '<br>')

    linked_text.html_safe
  end

  # ============================================
  # ビジネスロジック
  # ============================================

  def day_has_unfinished_tasks?(date, user)
    return false if date >= Time.zone.today

    user.tasks.for_date(date).pending.exists?
  end

  # ============================================
  # アプリケーション固有のUIコンポーネント
  # ============================================

  # 定型タスク選択 UI (上位3件 + その他ボタン)
  def regular_task_selector(user, all_regular_tasks)
    top_tasks = RegularTask.top_used_for_user(user, limit: 3)
    id = "regular_task_modal_#{SecureRandom.hex(4)}"

    content_tag(:div, class: 'space-y-2') do
      # 上位3件のクイック選択ボタン
      if top_tasks.any?
        concat(
          content_tag(:div, class: 'flex flex-wrap gap-2') do
            top_tasks.each do |rt|
              concat(
                content_tag(:button, rt.title,
                            type: 'button',
                            class: 'btn btn-sm btn-outline btn-primary',
                            data: {
                              action: 'regular-task#quickSelect',
                              regular_task_title: rt.title
                            })
              )
            end
            # その他ボタン (4件以上ある場合)
            if all_regular_tasks.size > 3
              concat(
                content_tag(:button, 'その他...',
                            type: 'button',
                            class: 'btn btn-sm btn-ghost',
                            data: { action: 'regular-task#openSelect' })
              )
            end
          end
        )
      elsif all_regular_tasks.any?
        # 上位がない場合でも定型タスクがあれば選択可能
        concat(
          content_tag(:button, '定型タスクを選択...',
                      type: 'button',
                      class: 'btn btn-sm btn-ghost',
                      data: { action: 'regular-task#openSelect' })
        )
      end

      # 全定型タスクの選択モーダル
      if all_regular_tasks.any?
        concat(
          action_sheet_modal(id: id, title: '定型タスクを選択', controller: 'regular-task',
                             target: 'selectModal', close_action: 'closeSelect') do
            content_tag(:ul, class: 'menu w-full p-0', data: { 'regular-task-target': 'selectList' }) do
              all_regular_tasks.each do |rt|
                concat(
                  content_tag(:li) do
                    content_tag(:button, type: 'button',
                                         class: %w[py-4 px-6 active:bg-primary active:text-primary-content
                                                   flex justify-between items-center w-full].join(' '),
                                         data: {
                                           action: 'regular-task#selectFromList',
                                           'regular-task-title': rt.title
                                         }) do
                      content_tag(:span, rt.title)
                    end
                  end
                )
              end
            end
          end
        )
      end
    end
  end
end
