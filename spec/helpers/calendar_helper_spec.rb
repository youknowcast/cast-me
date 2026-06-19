require 'rails_helper'

RSpec.describe CalendarHelper, type: :helper do
  describe '#day_has_unfinished_tasks?' do
    let(:user) { create(:user) }
    let(:date) { Time.zone.today }

    it 'returns true when the user has an unfinished task on the date' do
      create(:task, user: user, family: user.family, date: date, completed: false)

      expect(helper.day_has_unfinished_tasks?(date, user)).to be true
    end

    it 'returns false when tasks on the date are completed' do
      create(:task, user: user, family: user.family, date: date, completed: true)

      expect(helper.day_has_unfinished_tasks?(date, user)).to be false
    end

    it 'ignores unfinished tasks on other dates' do
      create(:task, user: user, family: user.family, date: date + 1.day, completed: false)

      expect(helper.day_has_unfinished_tasks?(date, user)).to be false
    end
  end

  describe '#anniversaries_on' do
    it 'delegates to AnniversaryService' do
      date = Time.zone.today
      users = create_list(:user, 2)
      anniversaries = [{ user: users.first, years: 10 }]
      allow(AnniversaryService).to receive(:anniversaries_on).with(date, users).and_return(anniversaries)

      expect(helper.anniversaries_on(date, users)).to eq(anniversaries)
    end
  end
end
