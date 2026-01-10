# CallHelper
#
# コール機能用のUIコンポーネントヘルパー
# 家族メンバーへのプッシュ通知送信用モーダルを提供
#
module CallHelper
  # ユーザーを呼び出すアイコンボタンとモーダルを表示
  # @param target_user [User] 呼び出し対象のユーザー
  def call_icon_button(target_user)
    modal_id = "call-modal-#{target_user.id}"

    content_tag(:span, class: 'ml-2', data: { controller: 'call', 'call-modal-id-value': modal_id }) do
      concat(
        content_tag(:button, type: 'button', class: 'btn btn-ghost btn-xs btn-circle',
                             data: { action: 'call#openModal' }, title: '呼び出す') do
          content_tag(:i, '', class: 'fas fa-phone text-primary')
        end
      )
      concat(call_modal(target_user, modal_id))
    end
  end

  # コール用モーダルダイアログを生成
  # @param target_user [User] 呼び出し対象のユーザー
  # @param modal_id [String] モーダルのID
  def call_modal(target_user, modal_id)
    content_tag(:dialog, id: modal_id, class: 'modal modal-bottom sm:modal-middle',
                         data: { 'call-target': 'modal' }) do
      content_tag(:div, class: 'modal-box') do
        safe_join([
                    content_tag(:h3, "#{target_user.display_name} を呼び出す", class: 'font-bold text-lg mb-4'),
                    call_modal_form(target_user)
                  ])
      end
    end
  end

  def call_modal_form(target_user)
    form_with url: calls_path, method: :post, data: { action: 'submit->call#submit' } do |f|
      safe_join([
                  f.hidden_field(:user_id, value: target_user.id),
                  content_tag(:div, class: 'form-control mb-4') do
                    safe_join([
                                f.label(:message, 'メッセージ', class: 'label'),
                                f.text_area(:message, value: 'これを見たら連絡して',
                                                      class: 'textarea textarea-bordered', rows: 2)
                              ])
                  end,
                  content_tag(:div, class: 'modal-action') do
                    safe_join([
                                content_tag(:button, 'キャンセル', type: 'button', class: 'btn',
                                                              data: { action: 'call#closeModal' }),
                                f.submit('送信', class: 'btn btn-primary')
                              ])
                  end
                ])
    end
  end
end
