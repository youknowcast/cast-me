class SettingsController < ApplicationController
  before_action :authenticate_user!

  def show
    @family = current_user.family
  end

  def update_avatar
    if params[:avatar].present?
      current_user.update!(avatar: params[:avatar].read)
      redirect_to settings_path, notice: 'アバターを更新しました'
    else
      redirect_to settings_path, alert: 'ファイルを選択してください'
    end
  end
end
