module MealsHelper
  # 食べ物選択 UI（よく食べるもの + その他モーダル）。meal-food コントローラと連携。
  def food_selector(family)
    frequent = family.foods.frequently_used
    all_active = family.foods.active.ordered_by_name
    modal_id = "food_modal_#{SecureRandom.hex(4)}"

    content_tag(:div, class: 'space-y-2') do
      if frequent.any?
        concat(
          content_tag(:div, class: 'flex flex-wrap gap-2') do
            frequent.each do |food|
              concat(
                content_tag(:button, food.name, type: 'button',
                                                class: 'btn btn-sm btn-outline btn-primary',
                                                data: { action: 'meal-food#quickSelect',
                                                        'food-name': food.name })
              )
            end
            if all_active.size > frequent.size
              concat(
                content_tag(:button, 'その他...', type: 'button',
                                               class: 'btn btn-sm btn-ghost',
                                               data: { action: 'meal-food#openSelect' })
              )
            end
          end
        )
      end

      if all_active.any?
        concat(
          action_sheet_modal(id: modal_id, title: '食べ物を選択', controller: 'meal-food',
                             target: 'selectModal', close_action: 'closeSelect') do
            content_tag(:ul, class: 'menu w-full p-0') do
              safe_join(
                all_active.map do |food|
                  content_tag(:li) do
                    content_tag(:button, food.name, type: 'button',
                                                    class: 'py-4 px-6 w-full text-left ' \
                                                           'active:bg-primary active:text-primary-content',
                                                    data: { action: 'meal-food#selectFromList',
                                                            'food-name': food.name })
                  end
                end
              )
            end
          end
        )
      end
    end
  end
end
