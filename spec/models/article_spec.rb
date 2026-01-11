require 'rails_helper'

RSpec.describe Article, type: :model do
  describe '#tag_list=' do
    it 'creates tags from comma-separated string' do
      article = build(:article)
      article.tag_list = 'foo, bar'
      article.save!
      expect(article.tags.map(&:name)).to contain_exactly('foo', 'bar')
    end

    it 'reuses existing tags' do
      Tag.create(name: 'existing')
      article = build(:article)
      article.tag_list = 'existing, new'
      article.save!
      expect(article.tags.map(&:name)).to contain_exactly('existing', 'new')
      expect(Tag.count).to eq(2)
    end
  end

  describe '.by_priority' do
    it 'orders pinned articles first' do
      # Create users explicitly if needed or rely on factory association
      pinned_article = create(:article, pinned: true, updated_at: 1.hour.ago)
      new_unpinned = create(:article, pinned: false, updated_at: 1.minute.ago)
      old_unpinned = create(:article, pinned: false, updated_at: 1.day.ago)

      expect(described_class.by_priority).to eq([pinned_article, new_unpinned, old_unpinned])
    end
  end
end
