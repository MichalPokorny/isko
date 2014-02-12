require 'pathname'

module Isko
	class Cache
		def initialize(base_path = "~/.isko-cache")
			@base_path = Pathname.new(base_path).expand_path
		end

		private
		attr_reader :base_path

		public
		def file_path(subpath)
			File.join(base_path, subpath)
		end

		def contains?(subpath)
			File.exist? file_path(subpath)
		end

		def load_yaml(subpath)
			raise "No such cache key: #{subpath}" unless contains?(subpath)
			YAML.load_file file_path(subpath)
		end

		def touch(subpath = nil)
			FileUtils.mkdir_p(subpath ? file_path(subpath) : path)
		end

		def save_yaml(subpath, data)
			touch(subpath)
			File.open(file_path(subpath), "w") do |f|
				YAML.dump(data, f)
			end
		end
	end
end
