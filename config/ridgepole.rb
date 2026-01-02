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
