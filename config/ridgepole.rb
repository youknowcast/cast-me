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
    super(from, to, from_indices, table_name, table_options, table_delta)

    if Ridgepole::Rails.options[:skip_column_options].include?(:after) && table_delta[:definition]
      [:add, :change].each do |action|
         if (delta = table_delta[:definition][action])
           delta.each do |_, attrs|
             if attrs[:options]
               attrs[:options].delete(:after)
             end
           end
         end
      end
    end
  end
end

class Ridgepole::Diff
  prepend RidgepoleDiffPatch
end
