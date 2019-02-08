# Copyright (C) 2015-2018  Kouhei Sutou <kou@clear-code.com>
#
# This library is free software: you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with this library.  If not, see <http://www.gnu.org/licenses/>.

require "time"

require "groonga-query-log"

module Fluent
  class GroongaQueryLogFilter < Filter
    Plugin.register_filter("groonga_query_log", self)

    config_param :raw_data_column_name,     :string, :default => "message"
    config_param :slow_operation_threshold, :float,  :default => 0.1
    config_param :slow_response_threshold,  :float,  :default => 0.2
    config_param :flatten,                  :bool,   :default => false
    config_param :flatten_separator,        :string, :default => nil
    config_param :timezone,                 :enum,
                                            :list => [:utc, :localtime],
                                            :default => :utc
    config_param :time_format,              :string, :default => "iso8601"

    def configure(conf)
      super

      options = {
        :slow_operation_threshold => @slow_operation_threshold,
        :slow_response_threshold => @slow_response_threshold,
        :timezone => @timezone,
        :time_format => @time_format,
      }
      @parser = GroongaQueryLog::Parser.new(options)
    end

    def filter_stream(tag, event_stream)
      statistics_event_stream = MultiEventStream.new
      event_stream.each do |time, record|
        raw_data = record[@raw_data_column_name]
        next if raw_data.nil?
        @parser.parse(raw_data) do |statistic|
          statistic_record = create_record(statistic)
          statistics_event_stream.add(time, statistic_record)
        end
      end
      statistics_event_stream
    end

    private
    def create_record(statistic)
      record = statistic.to_hash
      record["start_time"] = format_time(statistic.start_time)
      record["last_time"]  = format_time(statistic.last_time)
      if @flatten
        flatten_record!(record)
      end
      record
    end

    def format_time(time)
      time.utc if @timezone == :utc
      time.strftime(resolve_time_format)
    end

    def resolve_time_format
      case @time_format
      when "iso8601"
        format  = "%Y-%m-%dT%H:%M:%S.%6N"
        if @timezone == :utc
          format << "Z"
        else
          format << "%:z"
        end
      when "sql"
        format  = "%Y-%m-%d %H:%M:%S.%6N"
      # We can add more shotcuts here: when "..."
      else
        @time_format
      end
    end

    def flatten_record!(record)
      record.keys.each do |key|
        value = record[key]
        case value
        when Hash
          flatten_record_value_hash!(record, key, value)
        when Array
          flatten_record_value_array!(record, key, value)
        end
      end
    end

    def flatten_record_value!(record, base_key, value)
      case value
      when Hash
        flatten_record_value_hash!(record, base_key, value)
      when Array
        flatten_record_value_array!(record, base_key, value)
      else
        record[base_key] = value
      end
    end

    def flatten_record_value_hash!(record, base_key, hash)
      record.delete(base_key)
      hash.each do |key, value|
        if @flatten_separator
          flat_key = "#{base_key}#{@flatten_separator}#{key}"
        else
          flat_key = "#{base_key}.#{key}"
        end
        flatten_record_value!(record, flat_key, value)
      end
    end

    def flatten_record_value_array!(record, base_key, array)
      record.delete(base_key)
      array.each_with_index do |value, i|
        if @flatten_separator
          flat_key = "#{base_key}#{@flatten_separator}#{i}"
        else
          flat_key = "#{base_key}[#{i}]"
        end
        flatten_record_value!(record, flat_key, value)
      end
    end
  end
end
