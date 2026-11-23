require 'rails_helper'

RSpec.describe ReleaseNote do
  describe '.parse' do
    let(:markdown) do
      <<~MARKDOWN
        # リリースノート

        <!--
        ## 2000-01-01 書式の例
        - コメント内は無視される
        -->

        ## 2026-10-21 週間ダッシュボード
        - 家族の一週間を見られるようになりました
        - メモを編集できます

        ## 2026-09-02 ふりかえり
        - 一日を振り返れます
      MARKDOWN
    end

    it 'sorts entries newest first' do
      expect(described_class.parse(markdown).map(&:date)).to eq([Date.new(2026, 10, 21), Date.new(2026, 9, 2)])
    end

    it 'reads the heading and bullets of each entry' do
      note = described_class.parse(markdown).first

      expect(note.title).to eq('週間ダッシュボード')
      expect(note.items).to eq(%w[家族の一週間を見られるようになりました メモを編集できます])
    end

    it 'ignores entries inside HTML comments' do
      expect(described_class.parse(markdown).map(&:title)).not_to include('書式の例')
    end
  end

  describe '.all' do
    it 'loads the repository release notes newest first' do
      notes = described_class.all

      expect(notes).not_to be_empty
      expect(notes.map(&:date)).to eq(notes.map(&:date).sort.reverse)
    end
  end
end
