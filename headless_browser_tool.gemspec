# frozen_string_literal: true

require_relative "lib/headless_browser_tool/version"

Gem::Specification.new do |spec|
  spec.name = "headless_browser_tool"
  spec.version = HeadlessBrowserTool::VERSION
  spec.authors = ["Paulo Arruda"]
  spec.email = ["parrudaj@gmail.com"]

  spec.summary = "A headless browser control tool with MCP server"
  spec.description = "Provides an MCP server with tools to control a headless browser using Capybara and Selenium"
  spec.homepage = "https://github.com/parruda/headless-browser-tool"
  spec.required_ruby_version = ">= 3.1.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Runtime dependencies
  spec.add_dependency "capybara"
  spec.add_dependency "fast-mcp"
  spec.add_dependency "json"
  spec.add_dependency "ostruct"
  spec.add_dependency "puma"
  spec.add_dependency "rackup"
  spec.add_dependency "selenium-webdriver"
  spec.add_dependency "sinatra"
  spec.add_dependency "sinatra-contrib"
  spec.add_dependency "thor"
end
