class Hiera
  module Backend
    class ComplianceMap
      def initialize
        @@compliance_map_backend_enabled = true
      end

      def lookup(key, scope, order_override, resolution_type, context)
        return nil unless @@compliance_map_backend_enabled

        answer = nil

        # We really just want to use the existing backends to find our
        # compliance data. To prevent endless recursion, we need to set a
        # variable so that we can appropriately tell Hiera to keep looking down
        # the stack.

        @@compliance_map_backend_enabled = false
        compliance_map = Backend.lookup('compliance_map', scope, order_override, :hash, context)

        if compliance_map
          answer = 

        end
      end
    end
  end
end
