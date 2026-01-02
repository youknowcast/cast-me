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
          action_sheet_modal(id: id, title: '定型タスクを選択', controller: 'regular-task') do
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
