require 'rom/commands'

module ROM
  module Memory
    # Memory adapter commands namespace
    #
    # @api public
    module Commands
      # In-memory create command
      #
      # @api public
      class Create < ROM::Commands::Create
        adapter :memory

        # @see ROM::Commands::Create#execute
        def execute(tuples)
          Array([tuples]).flatten.map do |tuple|
            attributes = input[tuple]
            validator.call(attributes)
            relation.insert(attributes.to_h)
            attributes
          end.to_a
        end
      end

      # In-memory update command
      #
      # @api public
      class Update < ROM::Commands::Update
        adapter :memory

        # @see ROM::Commands::Update#execute
        def execute(params)
          attributes = input[params]
          validator.call(attributes)
          relation.map { |tuple| tuple.update(attributes.to_h) }
        end
      end

      # In-memory delete command
      #
      # @api public
      class Delete < ROM::Commands::Delete
        adapter :memory

        # @see ROM::Commands::Delete#execute
        def execute
          relation.to_a.map do |tuple|
            source.delete(tuple)
            tuple
          end
        end
      end
    end
  end
end
