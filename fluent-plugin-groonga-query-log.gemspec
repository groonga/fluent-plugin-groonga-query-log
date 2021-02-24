# -*- mode: ruby -*-
#
# Copyright (C) 2015-2021  Sutou Kouhei <kou@clear-code.com>
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

Gem::Specification.new do |spec|
  spec.name = "fluent-plugin-groonga-query-log"
  spec.version = "1.0.3"
  spec.authors = ["Kouhei Sutou"]
  spec.email = ["kou@clear-code.com"]
  spec.summary = "Fluentd plugin to parse Groonga's query log."
  spec.description = "You can detect slow query in real time by using this plugin."
  spec.homepage = "https://github.com/groonga/fluent-plugin-groonga-query-log"
  spec.license = "LGPLv3"

  spec.files = ["README.md", "Gemfile", "#{spec.name}.gemspec"]
  spec.files += [".yardopts"]
  spec.files += Dir.glob("lib/**/*.rb")
  spec.files += Dir.glob("sample/**/*")
  spec.files += Dir.glob("doc/text/**/*")
  spec.test_files += Dir.glob("test/**/*")
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency("fluentd")
  spec.add_runtime_dependency("groonga-query-log", ">= 1.7.6")

  spec.add_development_dependency("rake")
  spec.add_development_dependency("bundler")
  spec.add_development_dependency("packnga")
  spec.add_development_dependency("test-unit")
end
