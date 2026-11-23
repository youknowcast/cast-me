class ReleaseNote
  SOURCE_PATH = Rails.root.join('RELEASE_NOTES.md')
  ENTRY_PATTERN = /\A## (\d{4}-\d{2}-\d{2}) (.+)\z/
  ITEM_PATTERN = /\A- (.+)\z/
  COMMENT_PATTERN = /<!--.*?-->/m

  attr_reader :date, :title, :items

  def initialize(date:, title:)
    @date = date
    @title = title
    @items = []
  end

  def self.all(path = SOURCE_PATH)
    parse(File.read(path))
  end

  def self.parse(markdown)
    entries = []
    strip_comments(markdown).each_line(chomp: true) do |line|
      if (match = line.match(ENTRY_PATTERN))
        entries << new(date: Date.strptime(match[1], '%Y-%m-%d'), title: match[2].strip)
      elsif (match = line.match(ITEM_PATTERN)) && entries.any?
        entries.last.items << match[1].strip
      end
    end
    entries.each_with_index.sort_by { |note, index| [-note.date.jd, index] }.map(&:first)
  end

  def self.strip_comments(markdown)
    markdown.gsub(COMMENT_PATTERN, '')
  end
  private_class_method :strip_comments
end
