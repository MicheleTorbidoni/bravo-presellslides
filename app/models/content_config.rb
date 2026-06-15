# Reads the static content configuration that drives the pre-sale sessions.
#
# These files live under content/config/ and are edited by hand (no admin UI for
# the MVP). Nothing here is persisted to the database — see PresaleSession for the
# durable per-call record.
#
# In production the parsed files are memoized for the life of the process. In a
# local/dev environment they are re-read on every call so editing a JSON file is
# picked up without restarting the server.
module ContentConfig
  CONFIG_DIR = Rails.root.join("content", "config")

  class << self
    def segments
      load_config("segments").fetch(:segments)
    end

    def decision_tree
      load_config("decision-tree")
    end

    def criticalities
      load_config("criticalities").fetch(:criticalities)
    end

    def mappings
      load_config("mappings").fetch(:mappings)
    end

    def slides
      load_config("slides").fetch(:criticalities)
    end

    # Clears the in-memory cache. Mainly useful in tests.
    def reload!
      @cache = {}
    end

    private
      def load_config(name)
        return read_config(name) unless Rails.env.production?

        @cache ||= {}
        @cache[name] ||= read_config(name)
      end

      def read_config(name)
        path = CONFIG_DIR.join("#{name}.json")
        JSON.parse(path.read, symbolize_names: true)
      end
  end
end
