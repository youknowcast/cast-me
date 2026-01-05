class SettingsController < ApplicationController
  before_action :authenticate_user!

  AVATAR_SIZE = 128 # アバターの最大サイズ（ピクセル）
  private_constant :AVATAR_SIZE

  HourOption = Struct.new(:value, :label)
  private_constant :HourOption

  def show
    @family = current_user.family
    @notification_setting = current_user.notification_setting || current_user.build_notification_setting
    @hour_options = (0..23).map { |h| HourOption.new(h, "#{h}:00") }
  end

  def update
    if current_user.update(user_params)
      redirect_to settings_path, notice: '設定を更新しました'
    else
      @family = current_user.family
      render :show, status: :unprocessable_entity
    end
  end

  def update_avatar
    if params[:avatar].present?
      resized_avatar = resize_avatar(params[:avatar])
      current_user.update!(avatar: resized_avatar)
      redirect_to settings_path, notice: 'アバターを更新しました'
    else
      redirect_to settings_path, alert: 'ファイルを選択してください'
    end
  rescue StandardError => e
    Rails.logger.error "Avatar update failed: #{e.message}"
    redirect_to settings_path, alert: "アバターの更新に失敗しました: #{e.message}"
  end

  def update_notifications
    @notification_setting = current_user.notification_setting || current_user.build_notification_setting
    if @notification_setting.update(notification_setting_params)
      redirect_to settings_path, notice: '通知設定を更新しました'
    else
      @family = current_user.family
      @hour_options = (0..23).map { |h| HourOption.new(h, "#{h}:00") }
      render :show, status: :unprocessable_entity
    end
  end

  private

  def resize_avatar(uploaded_file)
    tempfile = uploaded_file.tempfile
    output_path = "#{tempfile.path}_resized.png"

    # sips (macOS) または ImageMagick を使用してリサイズ
    if system('which sips > /dev/null 2>&1')
      # macOS: sips を使用
      system(
        'sips',
        '-z', AVATAR_SIZE.to_s, AVATAR_SIZE.to_s,
        '-s', 'format', 'png',
        tempfile.path,
        '--out', output_path
      )
    elsif system('which convert > /dev/null 2>&1')
      # ImageMagick: convert を使用
      system(
        'convert',
        tempfile.path,
        '-resize', "#{AVATAR_SIZE}x#{AVATAR_SIZE}^",
        '-gravity', 'center',
        '-extent', "#{AVATAR_SIZE}x#{AVATAR_SIZE}",
        output_path
      )
    else
      # フォールバック: リサイズなしで読み込み
      Rails.logger.warn 'No image processing tool available, saving without resize'
      return uploaded_file.read
    end

    # リサイズした画像を読み込み
    File.binread(output_path)
  ensure
    File.delete(output_path) if output_path && File.exist?(output_path)
  end

  def user_params
    params.require(:user).permit(:birth)
  end

  def notification_setting_params
    params.require(:user_notification_setting).permit(
      :family_calendar_reminder_enabled, :family_calendar_reminder_hour,
      :family_task_progress_reminder_enabled, :family_task_progress_reminder_hour
    )
  end
end
