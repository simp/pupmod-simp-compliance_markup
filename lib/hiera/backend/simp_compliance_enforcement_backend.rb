class Hiera
  module Backend
    class Simp_compliance_enforcement_backend
      def initialize
        #
        # Load the shared compliance_mapper codebase
        #
        filename = File.dirname(File.dirname(File.dirname(__FILE__))) + "/puppetx/simp/compliance_mapper.rb"
        self.instance_eval(File.read(filename), filename)

        # Grab the config from hiera
        @config = Config[:compliance_markup]

      end

      def lookup(key, scope, order_override, resolution_type, context)
        # Monkey patch the catalog *object* to add a _compliance_cache accessor
        # We do this to prevent environment poisoning by monkey patching the class,
        # and it still allows us to have a catalog scoped cache.

        methods = scope.catalog.methods
        if (methods.include?(:_compliance_cache))
          @cache = scope.catalog._compliance_cache
        else
          scope.catalog.instance_eval("
           def _compliance_cache=(value)
             @_compliance_cache = value
           end
           def _compliance_cache
             @_compliance_cache
           end")
          scope.catalog._compliance_cache = {}
          @cache = scope.catalog._compliance_cache
        end

        answer = :not_found

        begin
          answer = enforcement(key) do |lookup, default|
            rscope = scope.real
            rscope.call_function('lookup', [lookup, { "default_value" => default }])
          end
        rescue => e
          unless (e.class.to_s == "ArgumentError")
            debug("Threw error #{e.to_s}")
          end
          throw :no_such_key
        end

        if (answer == :not_found)
          throw :no_such_key
        end

        return answer
      end

      #
      # These functions are helpers for enforcement(), that implement
      # the different caching systems on a v3 vs v5 backend
      #
      def debug(message)
        Hiera.debug(message)
      end

      # This cache is explicitly per-catalog
      def cache(key, value)
        @cache[key] = value
      end
      def cached_value(key)
        @cache[key]
      end
      def cache_has_key(key)
        @cache.key?(key)
      end
    end
  end
end

# vim: set expandtab ts=2 sw=2:
