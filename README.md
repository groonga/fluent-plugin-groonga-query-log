# README

## Name

fluent-plugin-groonga-query-log

## Description

Fluent-plugin-groonga-query-log is a Fluentd filter plugin to parse
[Groonga](http://groonga.org/)'s
[query log](http://groonga.org/docs/reference/log.html#query-log) with
Fluentd.

You can detect slow query in real time by using this plugin.

Here is a sample configuration that stores slow queries to Groonga:

    <source>
      @type tail
      path /var/log/groonga/query.log
      pos_file /var/log/fluentd/groonga-query-log.pos
      tag groonga.query
      format none
    </source>

    <filter groonga.query>
      @type groonga_query_log
    </filter>

    <filter groonga.query>
      @type grep
      regexp1 slow \Atrue\z
    </filter>

    <filter groonga.query>
      @type record_transformer
      enable_ruby true
      renew_record true
      keep_keys elapsed
      <record>
        log ${JSON.generate(to_h)}
      </record>
    </filter>

    <match groonga.query>
      @type groonga
      store_table SlowQueries

      protocol http
      host 127.0.0.1

      buffer_type file
      buffer_path /var/lib/fluentd/groonga.buffer
      flush_interval 1
    </match>

You need to prepare your environment to use the configuration.

Create the following directories:

    % sudo mkdir -p /var/log/fluentd
    % sudo mkdir -p /var/lib/fluentd

User who runs Fluentd must have write permission of the
directories. Set suitable permission to the directories:

    % sudo chown -R fluentd-user:fluentd-user /var/log/fluentd
    % sudo chown -R fluentd-user:fluentd-user /var/lib/fluentd

Run Groonga that stores slow queries on `127.0.0.1`:

    % groonga --protocol http -s DB_PATH

Run `fluentd` with the configuration:

    % fluentd --config groonga-slow-queries.conf

Now, slow queries are stored `SlowQueries` table in Groonga:

    % curl 'localhost:10041/d/select?table=SlowQueries&output_pretty=yes'
    [
      [
        0,
        1453454123.58033,
        8.70227813720703e-05
      ],
      [
        [
          [
            66
          ],
          [
            [
              "_id",
              "UInt32"
            ],
            [
              "elapsed",
              "Float"
            ],
            [
              "log",
              "Text"
            ]
          ],
          [
            1,
            0.265,
            "{\"start_time\":...}"
          ],
          [
            2,
            0.303,
            "{\"start_time\":...}"
          ],
          ...
        ]
      ]
    ]

Each query log is stored as one record. Record has the following two
columns:

  * `elapsed`: The elapsed time to execute the query.

  * `log`: The query details as JSON. It includes executed command,
    elapsed time for each condition and so on.

## Install

    % gem install fluent-plugin-groonga-query-log

## Usage

You can use `groonga-query-log` filter for parsing raw Groonga's query
log text.

Here is an example raw Groonga's query log text:

    2015-08-12 15:50:40.130990|0x7fb07d113da0|>/d/select?table=Entries&match_columns=name&query=xml
    2015-08-12 15:50:40.296165|0x7fb07d113da0|:000000165177838 filter(10)
    2015-08-12 15:50:40.296172|0x7fb07d113da0|:000000165184723 select(10)
    2015-08-12 15:50:41.228129|0x7fb07d113da0|:000001097153433 output(10)
    2015-08-12 15:50:41.228317|0x7fb07d113da0|<000001097334986 rc=0

`groonga-query-log` filter emits the following record by parsing the
above raw Groonga's query log text:

    {
      "start_time": "2015-08-12T06:50:40.130990Z",
      "last_time": "2015-08-12T06:50:41.228324Z",
      "elapsed": 1.0973349860000001,
      "return_code": 0,
      "slow": true,
      "command": {
        "raw": "/d/select?table=Entries&match_columns=name&query=xml",
        "name": "select",
        "parameters": [
          {
            "key": "table",
            "value": "Entries"
          },
          {
            "key": "match_columns",
            "value": "name"
          },
          {
            "key": "query",
            "value": "xml"
          }
        ]
      },
      "operations": [
        {
          "context": "query: xml",
          "name": "filter",
          "relative_elapsed": 0.165177838,
          "slow": true
        },
        {
          "context": null,
          "name": "select",
          "relative_elapsed": 6.884999999999999e-06,
          "slow": false
        },
        {
          "context": null,
          "name": "output",
          "relative_elapsed": 0.93196871,
          "slow": true
        }
      ]
    }

Here are parameters of this filter:

  * `raw_data_column_name`: It specifies column name that stores raw
    Groonga's query log text.
    * Default: `message`

  * `slow_operation_threshold`: It specifies threshold to treat an
    operation is slow. If one or more operations in a query spend more
    than the threshold, the query is slow query.
    * Default: `0.1`

  * `slow_response_threshold`: It specifies threshold to treat a
    request is slow. If a request for a query spends more than the
    threshold, the query is slow query.
    * Default: `0.2`

  * `flatten`: It specifies whether parsed query log is mapped to a
    flat object or a nested object. A float object will be useful to
    store the parsed log to non document oriented database such as
    RDBMS.

    Here is a sample record of parsed query log:

        {
          ...,
          "command": {
            "raw": "/d/select?table=Entries&match_columns=name&query=xml",
            "name": "select",
            "parameters": [
              {
                "key": "table",
                "value": "Entries"
              },
              {
                "key": "match_columns",
                "value": "name"
              },
              {
                "key": "query",
                "value": "xml"
              }
            ]
          },
          ...
        }

    Here is the flatten record of the above record:

        {
          ...,
          "command.raw": "/d/select?table=Entries&match_columns=name&query=xml",
          "command.name": "select",
          "command.parameters[0].key": "table",
          "command.parameters[0].value": "Entries",
          "command.parameters[1].key": "match_columns",
          "command.parameters[1].value": "name",
          "command.parameters[0].key": "query",
          "command.parameters[0].value": "xml",
          ...
        }

    * Default: `false` (nested object)

  * `flatten_separator`: It specifies separator that is used when
    `flatten` is `true`. If `flatten` is `true`, nested keys are
    mapped to one flatten key. This separator is used to concatenate
    nested keys.

    `.` is used for nested object by default. For example,

         {
           "a": {
             "b": 1
           }
         }

    is flatten to the following:

         {
           "a.b": 1
         }

    `[...]` is used for element in an array by default. For example,

         {
           "a": [
             1,
             2
           ]
         }

    is flatten to the following:

         {
           "a[0]": 1,
           "a[1]": 2
         }

    If `"_"` is used as the separator,

         {
           "a": [
             1,
             2
           ],
           "b": {
             "c": 3
           }
         }

    is flatten to the following:

         {
           "a_0": 1,
           "a_1": 2,
           "b_c": 3
         }

    * Default: `.` for object and `[...]` for array

## Authors

* Kouhei Sutou `<kou@clear-code.com>`

## License

LGPL 3 or later. See doc/text/lgpl-3.txt for details.

(Kouhei Sutou has a right to change the license including
contributed patches.)

## Mailing list

* English: [groonga-talk](https://lists.sourceforge.net/lists/listinfo/groonga-talk)
* Japanese: [groonga-dev](http://lists.sourceforge.jp/mailman/listinfo/groonga-dev)

## Source

The repository for fluent-plugin-groonga-query-log is on
[GitHub](https://github.com/groonga/fluent-plugin-groonga-query-log/).

## Thanks

* ...
