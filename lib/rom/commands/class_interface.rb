module ROM
  # Base command class with factory class-level interface and setup-related logic
  #
  # @private
  class Command
    module ClassInterface
      # Return adapter specific sub-class based on the adapter identifier
      #
      # This is a syntax sugar to make things consistent
      #
      # @example
      #   ROM::Commands::Create[:memory]
      #   # => ROM::Memory::Commands::Create
      #
      # @param [Symbol] adapter identifier
      #
      # @return [Class]
      #
      # @api public
      def [](adapter)
        adapter_namespace(adapter).const_get(Inflector.demodulize(name))
      end

      # Return namespaces that contains command subclasses of a specific adapter
      #
      # @param [Symbol] adapter identifier
      #
      # @return [Module]
      #
      # @api private
      def adapter_namespace(adapter)
        ROM.adapters.fetch(adapter).const_get(:Commands)
      rescue KeyError
        raise AdapterNotPresentError.new(adapter, :relation)
      end

      # Build a command class for a specific relation with options
      #
      # @example
      #   class CreateUser < ROM::Commands::Create[:memory]
      #   end
      #
      #   command = CreateUser.build(rom.relations[:users])
      #
      # @param [Relation] relation
      # @param [Hash] options
      #
      # @return [Command]
      #
      # @api public
      def build(relation, options = EMPTY_HASH)
        new(relation, self.options.merge(options))
      end

      # Use a configured plugin in this relation
      #
      # @example
      #   class CreateUser < ROM::Commands::Create[:memory]
      #     use :pagintion
      #
      #     per_page 30
      #   end
      #
      # @param [Symbol] plugin
      # @param [Hash] options
      # @option options [Symbol] :adapter (:default) first adapter to check for plugin
      #
      # @api public
      def use(plugin, _options = EMPTY_HASH)
        ROM.plugin_registry.commands.fetch(plugin, adapter).apply_to(self)
      end

      # Build command registry hash for provided relations
      #
      # @param [RelationRegistry] relations registry
      # @param [Hash] gateways
      # @param [Array] descendants a list of command subclasses
      #
      # @return [Hash]
      #
      # @api private
      def registry(relations, gateways, descendants)
        descendants.each_with_object({}) do |klass, h|
          rel_name = klass.relation

          next unless rel_name

          relation = relations[rel_name]
          name = klass.register_as || klass.default_name

          gateway = gateways[relation.class.gateway]
          gateway.extend_command_class(klass, relation.dataset)

          klass.send(:include, relation_methods_mod(relation.class))

          (h[rel_name] ||= {})[name] = klass.build(relation)
        end
      end

      # @api private
      def relation_methods_mod(relation_class)
        mod = Module.new

        relation_class.view_methods.each do |meth|
          mod.module_eval <<-RUBY
          def #{meth}(*args)
            response = relation.public_send(:#{meth}, *args)

            if response.is_a?(relation.class)
              new(response)
            else
              response
            end
          end
          RUBY
        end

        mod
      end

      # Return default name of the command class based on its name
      #
      # During setup phase this is used by defalut as `register_as` option
      #
      # @return [Symbol]
      #
      # @api private
      def default_name
        Inflector.underscore(Inflector.demodulize(name)).to_sym
      end

      # Return default options based on class macros
      #
      # @return [Hash]
      #
      # @api private
      def options
        { input: input, validator: validator, result: result }
      end
    end
  end
end
