# Copyright (C) 2015  Kouhei Sutou <kou@clear-code.com>
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

require "fluent/test"
require "fluent/plugin/filter_groonga_query_log"

class GroongaQueryLogFilterTest < Test::Unit::TestCase
  setup do
    Fluent::Test.setup
    @now = Time.parse("2015-08-12T08:45:42Z").to_i
    Fluent::Engine.now = @now
  end

  private
  def create_driver(configuration)
    driver = Fluent::Test::FilterTestDriver.new(Fluent::GroongaQueryLogFilter)
    driver.configure(configuration, true)
    driver
  end

  sub_test_case "configure" do
    test "default" do
      driver = create_driver("")
      filter = driver.instance
      assert_equal({
                     :raw_data_column_name     => "message",
                     :slow_operation_threshold => 0.1,
                     :slow_response_threshold  => 0.2,
                     :flatten                  => false,
                     :flatten_separator        => nil,
                   },
                   {
                     :raw_data_column_name     => filter.raw_data_column_name,
                     :slow_operation_threshold => filter.slow_operation_threshold,
                     :slow_response_threshold  => filter.slow_response_threshold,
                     :flatten                  => filter.flatten,
                     :flatten_separator        => filter.flatten_separator,
                   })
    end

    test "raw_data_column_name" do
      driver = create_driver("raw_data_column_name data")
      filter = driver.instance
      assert_equal("data", filter.raw_data_column_name)
    end

    test "slow_operation_threshold" do
      driver = create_driver("slow_operation_threshold 1.1")
      filter = driver.instance
      assert_equal(1.1, filter.slow_operation_threshold)
    end

    test "slow_response_threshold" do
      driver = create_driver("slow_response_threshold 2.5")
      filter = driver.instance
      assert_equal(2.5, filter.slow_response_threshold)
    end

    test "flatten" do
      driver = create_driver("flatten true")
      filter = driver.instance
      assert_equal(true, filter.flatten)
    end

    test "flatten_separator" do
      driver = create_driver("flatten_separator _")
      filter = driver.instance
      assert_equal("_", filter.flatten_separator)
    end
  end

  sub_test_case "filter_stream" do
    def emit(configuration, messages)
      driver = create_driver(configuration)
      driver.run do
        messages.each do |message|
          driver.emit({"message" => message}, @now)
        end
      end
      driver.filtered
    end

    test "partial" do
      messages = [
        "2015-08-12 15:50:40.130990|0x7fb07d113da0|>/d/select?table=Entries&match_columns=name&query=xml",
        "2015-08-12 15:50:40.296165|0x7fb07d113da0|:000000165177838 filter(10)",
        "2015-08-12 15:50:40.296172|0x7fb07d113da0|:000000165184723 select(10)",
        "2015-08-12 15:50:41.228129|0x7fb07d113da0|:000001097153433 output(10)",
      ]
      event_stream = emit("", messages)
      assert_equal([], event_stream.to_a)
    end

    test "one" do
      messages = [
        "2015-08-12 15:50:40.130990|0x7fb07d113da0|>/d/select?table=Entries&match_columns=name&query=xml",
        "2015-08-12 15:50:40.296165|0x7fb07d113da0|:000000165177838 filter(10)",
        "2015-08-12 15:50:40.296172|0x7fb07d113da0|:000000165184723 select(10)",
        "2015-08-12 15:50:41.228129|0x7fb07d113da0|:000001097153433 output(10)",
        "2015-08-12 15:50:41.228317|0x7fb07d113da0|<000001097334986 rc=0",
      ]
      statistic = {
        "start_time"  => "2015-08-12T15:50:40.130990+09:00",
        "last_time"   => "2015-08-12T15:50:41.228324+09:00",
        "elapsed"     => 1.0973349860000001,
        "return_code" => 0,
        "slow"        => true,
        "command" => {
          "raw" => "/d/select?table=Entries&match_columns=name&query=xml",
          "name" => "select",
          "parameters" => [
            {"key" => :table,         "value" => "Entries"},
            {"key" => :match_columns, "value" => "name"},
            {"key" => :query,         "value" => "xml"},
          ],
        },
        "operations" => [
          {
            "context"          => "query: xml",
            "name"             => "filter",
            "relative_elapsed" => 0.165177838,
            "slow"             => true,
          },
          {
            "context"          => nil,
            "name"             => "select",
            "relative_elapsed" => 6.884999999999999e-06,
            "slow"             => false,
          },
          {
            "context"          => nil,
            "name"             => "output",
            "relative_elapsed" => 0.93196871,
            "slow"             => true,
          },
        ],
      }
      event_stream = emit("", messages)
      assert_equal([[@now, statistic]], event_stream.to_a)
    end

    test "flatten" do
      messages = [
        "2015-08-12 15:50:40.130990|0x7fb07d113da0|>/d/select?table=Entries&match_columns=name&query=xml",
        "2015-08-12 15:50:40.296165|0x7fb07d113da0|:000000165177838 filter(10)",
        "2015-08-12 15:50:40.296172|0x7fb07d113da0|:000000165184723 select(10)",
        "2015-08-12 15:50:41.228129|0x7fb07d113da0|:000001097153433 output(10)",
        "2015-08-12 15:50:41.228317|0x7fb07d113da0|<000001097334986 rc=0",
      ]
      statistic = {
        "start_time"                     => "2015-08-12T15:50:40.130990+09:00",
        "last_time"                      => "2015-08-12T15:50:41.228324+09:00",
        "elapsed"                        => 1.0973349860000001,
        "return_code"                    => 0,
        "slow"                           => true,
        "command.raw"                    => "/d/select?table=Entries&match_columns=name&query=xml",
        "command.name"                   => "select",
        "command.parameters[0].key"      => :table,
        "command.parameters[0].value"    => "Entries",
        "command.parameters[1].key"      => :match_columns,
        "command.parameters[1].value"    => "name",
        "command.parameters[2].key"      => :query,
        "command.parameters[2].value"    => "xml",
        "operations[0].context"          => "query: xml",
        "operations[0].name"             => "filter",
        "operations[0].relative_elapsed" => 0.165177838,
        "operations[0].slow"             => true,
        "operations[1].context"          => nil,
        "operations[1].name"             => "select",
        "operations[1].relative_elapsed" => 6.884999999999999e-06,
        "operations[1].slow"             => false,
        "operations[2].context"          => nil,
        "operations[2].name"             => "output",
        "operations[2].relative_elapsed" => 0.93196871,
        "operations[2].slow"             => true,
      }
      event_stream = emit("flatten true", messages)
      assert_equal([[@now, statistic]], event_stream.to_a)
    end

    test "flatten_separator" do
      messages = [
        "2015-08-12 15:50:40.130990|0x7fb07d113da0|>/d/select?table=Entries&match_columns=name&query=xml",
        "2015-08-12 15:50:40.296165|0x7fb07d113da0|:000000165177838 filter(10)",
        "2015-08-12 15:50:40.296172|0x7fb07d113da0|:000000165184723 select(10)",
        "2015-08-12 15:50:41.228129|0x7fb07d113da0|:000001097153433 output(10)",
        "2015-08-12 15:50:41.228317|0x7fb07d113da0|<000001097334986 rc=0",
      ]
      statistic = {
        "start_time"                     => "2015-08-12T15:50:40.130990+09:00",
        "last_time"                      => "2015-08-12T15:50:41.228324+09:00",
        "elapsed"                        => 1.0973349860000001,
        "return_code"                    => 0,
        "slow"                           => true,
        "command_raw"                    => "/d/select?table=Entries&match_columns=name&query=xml",
        "command_name"                   => "select",
        "command_parameters_0_key"      => :table,
        "command_parameters_0_value"    => "Entries",
        "command_parameters_1_key"      => :match_columns,
        "command_parameters_1_value"    => "name",
        "command_parameters_2_key"      => :query,
        "command_parameters_2_value"    => "xml",
        "operations_0_context"          => "query: xml",
        "operations_0_name"             => "filter",
        "operations_0_relative_elapsed" => 0.165177838,
        "operations_0_slow"             => true,
        "operations_1_context"          => nil,
        "operations_1_name"             => "select",
        "operations_1_relative_elapsed" => 6.884999999999999e-06,
        "operations_1_slow"             => false,
        "operations_2_context"          => nil,
        "operations_2_name"             => "output",
        "operations_2_relative_elapsed" => 0.93196871,
        "operations_2_slow"             => true,
      }
      event_stream = emit(<<-CONFIGURATION, messages)
        flatten true
        flatten_separator _
      CONFIGURATION
      assert_equal([[@now, statistic]], event_stream.to_a)
    end

    test "slow_operation_threshold" do
      messages = [
        "2017-07-12 15:00:00.000000|0x7fb07d113da0|>/d/select?table=Entries&match_columns=name&query=xml",
        "2017-07-12 15:00:00.100000|0x7fb07d113da0|:000000010000000 filter(10)",
        "2017-07-12 15:00:00.200000|0x7fb07d113da0|:000000020000000 select(10)",
        "2017-07-12 15:00:00.300000|0x7fb07d113da0|:000000030000000 output(10)",
        "2017-07-12 15:00:00.400000|0x7fb07d113da0|<000000040000000 rc=0",
      ]
      statistics = {
        "start_time" => "2017-07-12T15:00:00.000000+09:00",
        "last_time" => "2017-07-12T15:00:00.040000+09:00",
        "elapsed" => 0.04,
        "return_code" => 0,
        "slow" => false,
        "command" => {
          "name"=>"select",
          "parameters" => [
            {"key" => :table, "value" => "Entries"},
            {"key" => :match_columns, "value" => "name"},
            {"key" => :query, "value" => "xml"}
          ],
          "raw" => "/d/select?table=Entries&match_columns=name&query=xml"},
         "operations" => [
          {"context" => "query: xml",
           "name" => "filter",
           "relative_elapsed" => 0.01,
           "slow" => true
          },
          {
            "context" => nil,
            "name" => "select",
            "relative_elapsed" => 0.01,
            "slow" => true
          },
          {
            "context" => nil,
            "name" => "output",
            "relative_elapsed" => 0.01,
            "slow" => true
          }
        ],
      }
      event_stream = emit("slow_operation_threshold 0.01", messages)
      assert_equal([[@now, statistics]], event_stream.to_a)
    end

    test "slow_response_threshold" do
      messages = [
        "2017-07-12 15:00:00.000000|0x7fb07d113da0|>/d/select?table=Entries&match_columns=name&query=xml",
        "2017-07-12 15:00:00.100000|0x7fb07d113da0|:000000010000000 filter(10)",
        "2017-07-12 15:00:00.200000|0x7fb07d113da0|:000000020000000 select(10)",
        "2017-07-12 15:00:00.300000|0x7fb07d113da0|:000000030000000 output(10)",
        "2017-07-12 15:00:00.400000|0x7fb07d113da0|<000000040000000 rc=0",
      ]
      statistics = {
        "start_time" => "2017-07-12T15:00:00.000000+09:00",
        "last_time" => "2017-07-12T15:00:00.040000+09:00",
        "elapsed" => 0.04,
        "return_code" => 0,
        "slow" => true,
        "command" => {
          "name"=>"select",
          "parameters" => [
            {"key" => :table, "value" => "Entries"},
            {"key" => :match_columns, "value" => "name"},
            {"key" => :query, "value" => "xml"}
          ],
          "raw" => "/d/select?table=Entries&match_columns=name&query=xml"},
         "operations" => [
          {"context" => "query: xml",
           "name" => "filter",
           "relative_elapsed" => 0.01,
           "slow" => false
          },
          {
            "context" => nil,
            "name" => "select",
            "relative_elapsed" => 0.01,
            "slow" => false
          },
          {
            "context" => nil,
            "name" => "output",
            "relative_elapsed" => 0.01,
            "slow" => false
          }
        ],
      }
      event_stream = emit("slow_response_threshold 0.01", messages)
      assert_equal([[@now, statistics]], event_stream.to_a)
    end
  end
end
