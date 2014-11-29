# encoding: utf-8

require 'json'
require 'pathname'
require 'rubocop'

RuboCop = Rubocop if defined?(Rubocop) && ! defined?(RuboCop)

module RuboCop
  module Formatter
    # This formatter formats the report data in JSON
    # Makes it consistent with output of other Maximus linters
    class MaximusRuboFormatter < BaseFormatter
      include PathUtil

      attr_reader :output_hash

      def initialize(output)
        super
        @output_hash = {}
      end

      def started(target_files)
      end

      def file_finished(file, offenses)
        unless offenses.empty?
          @output_hash[relative_path(file).to_sym] = {}
          @output_hash[relative_path(file).to_sym] = offenses.map { |o| hash_for_offense(o) }
        end
      end

      def finished(inspected_files)
        output.write @output_hash.to_json
      end

      def hash_for_offense(offense)
        {
          severity: offense.severity.name,
          reason:  offense.message,
          linter: offense.cop_name,
          line: offense.line,
          column: offense.real_column
        }
      end

    end
  end
end