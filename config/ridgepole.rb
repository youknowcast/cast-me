require 'ridgepole/diff'

module Ridgepole
  module Rails
    class << self
      def options
        @options ||= { skip_column_options: [] }
      end
    end
  end
end

Ridgepole::Rails.options[:skip_column_options] = [:after]

# Ridgepole がカラム追加時に付与する :after オプションを無効化するためのパッチ
# Ridgepole は SQLite を正式にはサポートしておらず、:after オプションが付くことでエラーが発生する場合があるため
# 参照: https://ledsun.hatenablog.com/entry/2025/11/15/171036
module RidgepoleDiffPatch
  def scan_definition_change(from, to, from_indices, table_name, table_options, table_delta)
    super

    return unless Ridgepole::Rails.options[:skip_column_options].include?(:after) && table_delta[:definition]

    %i[add change].each do |action|
      next unless (delta = table_delta[:definition][action])

      delta.each_value do |attrs|
        attrs[:options]&.delete(:after)
      end
    end
  end
end

module Ridgepole
  class Diff
    prepend RidgepoleDiffPatch
  end
end
