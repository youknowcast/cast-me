class SettingsController < ApplicationController
  before_action :authenticate_user!

  AVATAR_SIZE = 128 # アバターの最大サイズ（ピクセル）
  private_constant :AVATAR_SIZE

  def show
    @family = current_user.family
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
end
