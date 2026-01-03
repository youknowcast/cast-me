# MobileUiHelper
#
# モバイル向けUIコンポーネントの汎用ヘルパー
# ActionSheet、日付/時刻ピッカー、セレクターなどを提供
#
# 使用方法:
#   include MobileUiHelper (通常はApplicationHelperでincludeされている)
#
module MobileUiHelper
  # ============================================
  # ActionSheet コンポーネント
  # ============================================

  # ActionSheet モーダル構造
  #
  # @param id [String] モーダルのID
  # @param title [String] モーダルのタイトル
  # @param controller [String] Stimulusコントローラー名
  # @param target [String] Stimulusターゲット名 (デフォルト: 'modal')
  # @param close_action [String] 閉じるボタンのアクション (デフォルト: 'close')
  # @param cancel_text [String] キャンセルボタンのテキスト
  # @yield モーダル内のコンテンツ
  #
  # 使用例:
  #   action_sheet_modal(id: "my_modal", title: "選択", controller: "my-controller") do
  #     content_tag(:ul, class: "menu") { ... }
  #   end
  #
  #   # カスタムターゲット名を使用する場合:
  #   action_sheet_modal(id: "my_modal", title: "選択", controller: "regular-task",
  #                      target: "selectModal", close_action: "closeSelect") do
  #     ...
  #   end
  #
  def action_sheet_modal(id:, title:, controller:, target: 'modal', close_action: 'close', cancel_text: 'キャンセル', &block)
    content_tag(:dialog, id: id, class: 'modal modal-bottom sm:modal-middle',
                         data: { "#{controller}-target": target }) do
      content_tag(:div, class: 'modal-box p-0 max-h-[70vh] flex flex-col') do
        # Header
        concat(
          content_tag(:div, class: 'p-4 border-b sticky top-0 bg-base-100 z-10') do
            content_tag(:h3, title, class: 'text-lg font-bold text-center')
          end
        )
        # Content
        concat(
          content_tag(:div, class: 'overflow-y-auto') do
            capture(&block)
          end
        )
        # Footer
        concat(
          content_tag(:div, class: 'p-4 border-t mt-auto') do
            content_tag(:button, cancel_text, type: 'button', class: 'btn btn-ghost w-full',
                                              data: { action: "#{controller}##{close_action}" })
          end
        )
      end
    end
  end

  # ActionSheet リストアイテム
  #
  # @param value [String, Integer] アイテムの値
  # @param text [String] 表示テキスト
  # @param controller [String] Stimulusコントローラー名
  #
  def action_sheet_item(value:, text:, controller:)
    content_tag(:li) do
      content_tag(:button, type: 'button',
                           class: %w[py-4 px-6 active:bg-primary active:text-primary-content
                                     flex justify-between items-center].join(' '),
                           data: { action: "#{controller}#select",
                                   "#{controller}-value-param": value,
                                   "#{controller}-text-param": text }) do
        concat content_tag(:span, text)
        concat content_tag(:i, '', class: 'fas fa-check opacity-0',
                                   data: { "#{controller}-target": 'optionCheck', value: value })
      end
    end
  end

  # ============================================
  # 日付/時刻 ピッカー
  # ============================================

  # 日付選択フィールド (モバイル対応)
  #
  # @param form [FormBuilder] Railsフォームビルダー
  # @param method [Symbol] フィールド名
  # @param options [Hash] オプション
  #
  def mobile_date_field(form, method, _options = {})
    value = form.object.send(method) || Time.zone.today
    id = "mobile_date_#{method}_#{form.object.object_id}"

    content_tag(:div, data: { controller: 'datepicker-connector' }) do
      concat form.hidden_field(method, id: id, data: { datepicker_connector_target: 'input' })
      concat(
        content_tag(:button, type: 'button', class: 'btn btn-outline w-full justify-between font-normal',
                             data: { action: 'datepicker-connector#open' }) do
          concat content_tag(:span, value.strftime('%Y/%m/%d'), data: { datepicker_connector_target: 'triggerText' })
          concat content_tag(:i, '', class: 'fas fa-calendar-alt text-gray-400')
        end
      )
    end
  end

  # 時刻選択フィールド (モバイル対応)
  #
  # @param form [FormBuilder] Railsフォームビルダー
  # @param method [Symbol] フィールド名
  # @param options [Hash] オプション
  #   - :input_data [Hash] inputタグに追加するdata属性
  #   - :display_data [Hash] 表示spanに追加するdata属性
  #   - :wrapper_data [Hash] wrapper divに追加するdata属性
  #
  def mobile_time_field(form, method, options = {})
    raw_value = form.object.send(method)
    value = case raw_value
            when ->(v) { v.respond_to?(:strftime) } then raw_value.strftime('%H:%M')
            when String then raw_value.presence || ''
            else ''
            end
    id = "mobile_time_#{method}_#{form.object.object_id}"

    input_data = { timepicker_connector_target: 'input' }.merge(options[:input_data] || {})
    display_data = { timepicker_connector_target: 'triggerText' }.merge(options[:display_data] || {})
    wrapper_data = { controller: 'timepicker-connector' }.merge(options[:wrapper_data] || {})

    content_tag(:div, data: wrapper_data) do
      concat form.hidden_field(method, id: id, data: input_data, value: value)
      concat(
        content_tag(:button, type: 'button', class: 'btn btn-outline w-full justify-between font-normal',
                             data: { action: 'timepicker-connector#open' }) do
          display_value = value.presence || '--:--'
          concat content_tag(:span, display_value, data: display_data)
          concat content_tag(:i, '', class: 'fas fa-clock text-gray-400')
        end
      )
    end
  end

  # ============================================
  # セレクター
  # ============================================

  # コレクション選択 (フォーム用, モバイル対応)
  #
  # @param form [FormBuilder] Railsフォームビルダー
  # @param method [Symbol] フィールド名
  # @param collection [Array] 選択肢のコレクション
  # @param value_method [Symbol] 値を取得するメソッド
  # @param text_method [Symbol] テキストを取得するメソッド
  # @param options [Hash] オプション (label, prompt, include_blank, blank_value, blank_text)
  # @param html_options [Hash] HTMLオプション
  #
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
  #
  # @param name [String] フィールド名
  # @param value [String, Integer] 現在の値
  # @param collection [Array] 選択肢のコレクション
  # @param value_method [Symbol] 値を取得するメソッド
  # @param text_method [Symbol] テキストを取得するメソッド
  # @param options [Hash] オプション
  # @param html_options [Hash] HTMLオプション
  #
  def mobile_selector(name, value, collection, value_method, text_method, options = {}, html_options = {}, &)
    mobile_selector_internal(name, value, collection, value_method, text_method, options, html_options, &)
  end

  private

  def mobile_selector_internal(name, value, collection, value_method, text_method, options, html_options, &block)
    selected_item = collection.find { |i| i.send(value_method).to_s == value.to_s }
    label_text = selected_item ? selected_item.send(text_method) : (options[:prompt] || '選択してください')
    id = "mobile_selector_#{name}_#{SecureRandom.hex(4)}"

    base_data = { controller: 'mobile-selector', 'mobile-selector-id-value': id }
    provided_data = options[:wrapper_data] || {}
    if provided_data[:controller].present?
      base_data[:controller] = "#{base_data[:controller]} #{provided_data[:controller]}"
    end
    wrapper_data = base_data.merge(provided_data.except(:controller))

    content_tag(:div, data: wrapper_data) do
      concat hidden_field_tag(name, value, id: id,
                                           data: { 'mobile-selector-target': 'input' }.merge(html_options[:data] || {}))

      trigger_content = if block_given?
                          capture(&block)
                        else
                          content_tag(:button, type: 'button',
                                               class: 'btn btn-outline w-full justify-between font-normal',
                                               data: { action: 'mobile-selector#open' }) do
                            concat content_tag(:span, label_text, data: { 'mobile-selector-target': 'triggerText' })
                            concat content_tag(:i, '', class: 'fas fa-chevron-down text-gray-400')
                          end
                        end
      concat(trigger_content)
      concat(
        action_sheet_modal(id: "modal_#{id}", title: options[:label] || '選択してください', controller: 'mobile-selector') do
          content_tag(:ul, class: 'menu w-full p-0') do
            if options[:include_blank]
              concat(action_sheet_item(
                       value: options[:blank_value] || 'all',
                       text: options[:blank_text] || '全員',
                       controller: 'mobile-selector'
                     ))
            end
            collection.each do |item|
              concat(action_sheet_item(
                       value: item.send(value_method),
                       text: item.send(text_method),
                       controller: 'mobile-selector'
                     ))
            end
          end
        end
      )
    end
  end
end
