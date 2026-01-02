module ApplicationHelper
  def plan_icon
    "fas fa-calendar-alt"
  end

  def task_icon
    "fas fa-tasks"
  end

  def day_has_unfinished_tasks?(date, user)
    return false if date >= Date.today
    user.tasks.for_date(date).pending.exists?
  end

  # 日付選択フィールド (モバイル対応)
  def mobile_date_field(form, method, options = {})
    value = form.object.send(method) || Date.today
    id = "mobile_date_#{method}_#{form.object.object_id}"

    content_tag(:div, data: { controller: "datepicker-connector" }) do
      concat form.hidden_field(method, id: id, data: { datepicker_connector_target: "input" })
      concat(
        content_tag(:button, type: "button", class: "btn btn-outline w-full justify-between font-normal", data: { action: "datepicker-connector#open" }) do
          concat content_tag(:span, value.strftime("%Y/%m/%d"), data: { datepicker_connector_target: "triggerText" })
          concat content_tag(:i, "", class: "fas fa-calendar-alt text-gray-400")
        end
      )
    end
  end

  # 時刻選択フィールド (モバイル対応)
  def mobile_time_field(form, method, options = {})
    raw_value = form.object.send(method)
    # Handle Time, DateTime, or String values
    if raw_value.respond_to?(:strftime)
      value = raw_value.strftime("%H:%M")
    elsif raw_value.is_a?(String) && raw_value.present?
      value = raw_value
    else
      value = ""
    end
    id = "mobile_time_#{method}_#{form.object.object_id}"

    content_tag(:div, data: { controller: "timepicker-connector" }) do
      concat form.hidden_field(method, id: id, data: { timepicker_connector_target: "input" }, value: value)
      concat(
        content_tag(:button, type: "button", class: "btn btn-outline w-full justify-between font-normal", data: { action: "timepicker-connector#open" }) do
          display_value = value.present? ? value : "--:--"
          concat content_tag(:span, display_value, data: { timepicker_connector_target: "triggerText" })
          concat content_tag(:i, "", class: "fas fa-clock text-gray-400")
        end
      )
    end
  end

  # コレクション選択 (フォーム用, モバイル対応)
  def mobile_collection_select(form, method, collection, value_method, text_method, options = {}, html_options = {})
    mobile_selector_internal(
      "#{form.object_name}[#{method}]",
      form.object.send(method),
      collection,
      value_method,
      text_method,
      options,
      html_options
    )
  end

  # セレクター (非フォーム用, モバイル対応)
  def mobile_selector(name, value, collection, value_method, text_method, options = {}, html_options = {})
    mobile_selector_internal(name, value, collection, value_method, text_method, options, html_options)
  end

  # 定型タスク選択 UI (上位3件 + その他ボタン)
  def regular_task_selector(user, all_regular_tasks)
    top_tasks = RegularTask.top_used_for_user(user, limit: 3)
    id = "regular_task_modal_#{SecureRandom.hex(4)}"

    content_tag(:div, class: "space-y-2") do
      # 上位3件のクイック選択ボタン
      if top_tasks.any?
        concat(
          content_tag(:div, class: "flex flex-wrap gap-2") do
            top_tasks.each do |rt|
              concat(
                content_tag(:button, rt.title,
                  type: "button",
                  class: "btn btn-sm btn-outline btn-primary",
                  data: {
                    action: "regular-task#quickSelect",
                    regular_task_title: rt.title
                  }
                )
              )
            end
            # その他ボタン (4件以上ある場合)
            if all_regular_tasks.size > 3
              concat(
                content_tag(:button, "その他...",
                  type: "button",
                  class: "btn btn-sm btn-ghost",
                  data: { action: "regular-task#openSelect" }
                )
              )
            end
          end
        )
      elsif all_regular_tasks.any?
        # 上位がない場合でも定型タスクがあれば選択可能
        concat(
          content_tag(:button, "定型タスクを選択...",
            type: "button",
            class: "btn btn-sm btn-ghost",
            data: { action: "regular-task#openSelect" }
          )
        )
      end

      # 全定型タスクの選択モーダル
      if all_regular_tasks.any?
        concat(
          action_sheet_modal(id: id, title: "定型タスクを選択", controller: "regular-task") do
            content_tag(:ul, class: "menu w-full p-0", data: { "regular-task-target": "selectList" }) do
              all_regular_tasks.each do |rt|
                concat(
                  content_tag(:li) do
                    content_tag(:button, type: "button",
                                class: "py-4 px-6 active:bg-primary active:text-primary-content flex justify-between items-center w-full",
                                data: {
                                  action: "regular-task#selectFromList",
                                  "regular-task-title": rt.title
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

  private

  # 内部: セレクター共通実装
  def mobile_selector_internal(name, value, collection, value_method, text_method, options, html_options)
    selected_item = collection.find { |i| i.send(value_method).to_s == value.to_s }
    label_text = selected_item ? selected_item.send(text_method) : (options[:prompt] || "選択してください")
    id = "mobile_selector_#{name}_#{SecureRandom.hex(4)}"

    content_tag(:div, data: { controller: "mobile-selector", "mobile-selector-id-value": id }) do
      concat hidden_field_tag(name, value, id: id, data: { "mobile-selector-target": "input" }.merge(html_options[:data] || {}))
      concat(
        content_tag(:button, type: "button", class: "btn btn-outline w-full justify-between font-normal", data: { action: "mobile-selector#open" }) do
          concat content_tag(:span, label_text, data: { "mobile-selector-target": "triggerText" })
          concat content_tag(:i, "", class: "fas fa-chevron-down text-gray-400")
        end
      )
      concat(
        action_sheet_modal(id: "modal_#{id}", title: options[:label] || "選択してください", controller: "mobile-selector") do
          content_tag(:ul, class: "menu w-full p-0") do
            if options[:include_blank]
              concat(action_sheet_item(
                value: options[:blank_value] || "all",
                text: options[:blank_text] || "全員",
                controller: "mobile-selector"
              ))
            end
            collection.each do |item|
              concat(action_sheet_item(
                value: item.send(value_method),
                text: item.send(text_method),
                controller: "mobile-selector"
              ))
            end
          end
        end
      )
    end
  end

  # ActionSheet モーダル構造 (Rubyヘルパー版)
  def action_sheet_modal(id:, title:, controller:, cancel_text: "キャンセル", &block)
    content_tag(:dialog, id: id, class: "modal modal-bottom sm:modal-middle", data: { "#{controller}-target": "modal" }) do
      content_tag(:div, class: "modal-box p-0 max-h-[70vh] flex flex-col") do
        # Header
        concat(
          content_tag(:div, class: "p-4 border-b sticky top-0 bg-base-100 z-10") do
            content_tag(:h3, title, class: "text-lg font-bold text-center")
          end
        )
        # Content
        concat(
          content_tag(:div, class: "overflow-y-auto") do
            capture(&block)
          end
        )
        # Footer
        concat(
          content_tag(:div, class: "p-4 border-t mt-auto") do
            content_tag(:button, cancel_text, type: "button", class: "btn btn-ghost w-full", data: { action: "#{controller}#close" })
          end
        )
      end
    end
  end

  # ActionSheet リストアイテム
  def action_sheet_item(value:, text:, controller:)
    content_tag(:li) do
      content_tag(:button, type: "button",
                  class: "py-4 px-6 active:bg-primary active:text-primary-content flex justify-between items-center",
                  data: { action: "#{controller}#select",
                         "#{controller}-value-param": value,
                         "#{controller}-text-param": text }) do
        concat content_tag(:span, text)
        concat content_tag(:i, "", class: "fas fa-check opacity-0", data: { "#{controller}-target": "optionCheck", value: value })
      end
    end
  end
end
