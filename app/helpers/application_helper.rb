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

  def mobile_collection_select(form, method, collection, value_method, text_method, options = {}, html_options = {})
    value = form.object.send(method)
    selected_item = collection.find { |i| i.send(value_method).to_s == value.to_s }
    label_text = selected_item ? selected_item.send(text_method) : (options[:prompt] || "選択してください")
    id = "mobile_select_#{method}_#{form.object.object_id}"

    content_tag(:div, data: { controller: "mobile-selector", mobile_selector_id_value: id }) do
      concat form.hidden_field(method, id: id, data: { mobile_selector_target: "input" })
      concat(
        content_tag(:button, type: "button", class: "btn btn-outline w-full justify-between font-normal", data: { action: "mobile-selector#open" }) do
          concat content_tag(:span, label_text, data: { mobile_selector_target: "triggerText" })
          concat content_tag(:i, "", class: "fas fa-chevron-down text-gray-400")
        end
      )
      concat(
        content_tag(:dialog, id: "modal_#{id}", class: "modal modal-bottom sm:modal-middle", data: { mobile_selector_target: "modal" }) do
          content_tag(:div, class: "modal-box p-0 max-h-[70vh] flex flex-col") do
            concat(
              content_tag(:div, class: "p-4 border-b sticky top-0 bg-base-100 z-10") do
                content_tag(:h3, options[:label] || "選択してください", class: "text-lg font-bold text-center")
              end
            )
            concat(
              content_tag(:div, class: "overflow-y-auto") do
                content_tag(:ul, class: "menu w-full p-0") do
                  collection.each do |item|
                    item_value = item.send(value_method)
                    item_text = item.send(text_method)
                    concat(
                      content_tag(:li) do
                        content_tag(:button, type: "button",
                                    class: "py-4 px-6 active:bg-primary active:text-primary-content flex justify-between items-center",
                                    data: { action: "mobile-selector#select",
                                           mobile_selector_value_param: item_value,
                                           mobile_selector_text_param: item_text }) do
                          concat content_tag(:span, item_text)
                          concat content_tag(:i, "", class: "fas fa-check opacity-0", data: { mobile_selector_target: "optionCheck", value: item_value })
                        end
                      end
                    )
                  end
                end
              end
            )
            concat(
              content_tag(:div, class: "p-4 border-t mt-auto") do
                content_tag(:button, "キャンセル", type: "button", class: "btn btn-ghost w-full", data: { action: "mobile-selector#close" })
              end
            )
          end
        end
      )
    end
  end

  def mobile_selector(name, value, collection, value_method, text_method, options = {}, html_options = {})
    selected_item = collection.find { |i| i.send(value_method).to_s == value.to_s }
    label_text = selected_item ? selected_item.send(text_method) : (options[:prompt] || "選択してください")
    id = "mobile_selector_#{name}_#{SecureRandom.hex(4)}"

    content_tag(:div, data: { controller: "mobile-selector", mobile_selector_id_value: id }) do
      concat hidden_field_tag(name, value, id: id, data: { mobile_selector_target: "input" }.merge(html_options[:data] || {}))
      concat(
        content_tag(:button, type: "button", class: "btn btn-outline w-full justify-between font-normal", data: { action: "mobile-selector#open" }) do
          concat content_tag(:span, label_text, data: { mobile_selector_target: "triggerText" })
          concat content_tag(:i, "", class: "fas fa-chevron-down text-gray-400")
        end
      )
      concat(
        content_tag(:dialog, id: "modal_#{id}", class: "modal modal-bottom sm:modal-middle", data: { mobile_selector_target: "modal" }) do
          content_tag(:div, class: "modal-box p-0 max-h-[70vh] flex flex-col") do
            concat(
              content_tag(:div, class: "p-4 border-b sticky top-0 bg-base-100 z-10") do
                content_tag(:h3, options[:label] || "選択してください", class: "text-lg font-bold text-center")
              end
            )
            concat(
              content_tag(:div, class: "overflow-y-auto") do
                content_tag(:ul, class: "menu w-full p-0") do
                  if options[:include_blank]
                    concat(
                      content_tag(:li) do
                        content_tag(:button, type: "button",
                                    class: "py-4 px-6 active:bg-primary active:text-primary-content flex justify-between items-center",
                                    data: { action: "mobile-selector#select",
                                           mobile_selector_value_param: options[:blank_value] || "all",
                                           mobile_selector_text_param: options[:blank_text] || "全員" }) do
                          concat content_tag(:span, options[:blank_text] || "全員")
                          concat content_tag(:i, "", class: "fas fa-check opacity-0", data: { mobile_selector_target: "optionCheck", value: options[:blank_value] || "all" })
                        end
                      end
                    )
                  end
                  collection.each do |item|
                    item_value = item.send(value_method)
                    item_text = item.send(text_method)
                    concat(
                      content_tag(:li) do
                        content_tag(:button, type: "button",
                                    class: "py-4 px-6 active:bg-primary active:text-primary-content flex justify-between items-center",
                                    data: { action: "mobile-selector#select",
                                           mobile_selector_value_param: item_value,
                                           mobile_selector_text_param: item_text }) do
                          concat content_tag(:span, item_text)
                          concat content_tag(:i, "", class: "fas fa-check opacity-0", data: { mobile_selector_target: "optionCheck", value: item_value })
                        end
                      end
                    )
                  end
                end
              end
            )
            concat(
              content_tag(:div, class: "p-4 border-t mt-auto") do
                content_tag(:button, "キャンセル", type: "button", class: "btn btn-ghost w-full", data: { action: "mobile-selector#close" })
              end
            )
          end
        end
      )
    end
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
          content_tag(:dialog, id: id, class: "modal modal-bottom sm:modal-middle", data: { regular_task_target: "selectModal" }) do
            content_tag(:div, class: "modal-box p-0 max-h-[70vh] flex flex-col") do
              concat(
                content_tag(:div, class: "p-4 border-b sticky top-0 bg-base-100 z-10") do
                  content_tag(:h3, "定型タスクを選択", class: "text-lg font-bold text-center")
                end
              )
              concat(
                content_tag(:div, class: "overflow-y-auto", data: { regular_task_target: "selectList" }) do
                  content_tag(:ul, class: "menu w-full p-0") do
                    all_regular_tasks.each do |rt|
                      concat(
                        content_tag(:li) do
                          content_tag(:button, type: "button",
                                      class: "py-4 px-6 active:bg-primary active:text-primary-content flex justify-between items-center",
                                      data: {
                                        action: "regular-task#selectFromList",
                                        regular_task_title: rt.title
                                      }) do
                            content_tag(:span, rt.title)
                          end
                        end
                      )
                    end
                  end
                end
              )
              concat(
                content_tag(:div, class: "p-4 border-t mt-auto") do
                  content_tag(:button, "キャンセル", type: "button", class: "btn btn-ghost w-full", data: { action: "regular-task#closeSelect" })
                end
              )
            end
          end
        )
      end
    end
  end
end
