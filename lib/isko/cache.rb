require 'pathname'

module Isko
	class Cache
		def initialize(base_path = "~/.isko-cache")
			@base_path = Pathname.new(base_path).expand_path
		end

		public
		def file_path(subpath)
			File.join(@base_path, subpath)
		end

		def contains?(subpath)
			File.exist? file_path(subpath)
		end

		def load_yaml(subpath)
			raise "No such cache key: #{subpath}" unless contains?(subpath)
			YAML.load_file file_path(subpath)
		end

		def touch(subpath = nil)
			touch_path = subpath ? File.dirname(file_path(subpath)) : path
			FileUtils.mkdir_p(touch_path)
		end

		def save_yaml(subpath, data)
			touch(subpath)
			File.open(file_path(subpath), "w") do |f|
				YAML.dump(data, f)
			end
		end
	end
end
