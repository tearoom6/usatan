Gem::Specification.new do |spec|
  spec.name          = "lita-usatan"
  spec.version       = "0.1.0"
  spec.authors       = ["tearoom6"]
  spec.email         = ["tomohiro.murota@gmail.com"]
  spec.description   = "Japanese speaking Usatan"
  spec.summary       = "smart bot speaking Japanese"
  spec.homepage      = "http://tearoom6-jp.appspot.com/"
  spec.license       = "Apache License 2.0"
  spec.metadata      = { "lita_plugin_type" => "handler" }

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "lita", ">= 4.6"
  spec.add_runtime_dependency "okura", "0.0.1"

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "pry-byebug"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rack-test"
  spec.add_development_dependency "rspec", ">= 3.0.0"
end
