class AnniversaryService
  Anniversary = Struct.new(:name, :type, :user, keyword_init: true)

  def self.anniversaries_on(date, users)
    anniversaries = []

    users.each do |user|
      if user.birth.present? && user.birth.month == date.month && user.birth.day == date.day
        anniversaries << Anniversary.new(
          name: "#{user.display_name}さんの誕生日",
          type: :birthday,
          user: user
        )
      end
    end

    anniversaries
  end
end
