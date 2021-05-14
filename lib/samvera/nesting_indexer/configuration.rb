require 'samvera/nesting_indexer/adapters/abstract_adapter'
require 'samvera/nesting_indexer/exceptions'
require 'logger'

module Samvera
  module NestingIndexer
    # @api public
    # Responsible for the configuration of the Samvera::NestingIndexer
    class Configuration
      DEFAULT_MAXIMUM_NESTING_DEPTH = 15

      def initialize(maximum_nesting_depth: DEFAULT_MAXIMUM_NESTING_DEPTH, logger: default_logger)
        self.maximum_nesting_depth = maximum_nesting_depth
        self.logger = logger
        self.stop_on_failure = true
      end

      attr_reader :maximum_nesting_depth, :logger, :stop_on_failure

      attr_writer :logger, :stop_on_failure

      def maximum_nesting_depth=(input)
        @maximum_nesting_depth = input.to_i
      end

      def solr_field_name_for_storing_parent_ids=(input)
        @solr_field_name_for_storing_parent_ids = input.to_s
      end

      def solr_field_name_for_storing_parent_ids
        @solr_field_name_for_storing_parent_ids || raise(Exceptions::SolrKeyConfigurationError.new(name: __method__, config: self))
      end

      def solr_field_name_for_storing_ancestors=(input)
        @solr_field_name_for_storing_ancestors = input.to_s
      end

      def solr_field_name_for_storing_ancestors
        @solr_field_name_for_storing_ancestors || raise(Exceptions::SolrKeyConfigurationError.new(name: __method__, config: self))
      end

      def solr_field_name_for_storing_pathnames=(input)
        @solr_field_name_for_storing_pathnames = input.to_s
      end

      def solr_field_name_for_storing_pathnames
        @solr_field_name_for_storing_pathnames || raise(Exceptions::SolrKeyConfigurationError.new(name: __method__, config: self))
      end

      def solr_field_name_for_deepest_nested_depth=(input)
        @solr_field_name_for_deepest_nested_depth = input.to_s
      end

      def solr_field_name_for_deepest_nested_depth
        @solr_field_name_for_deepest_nested_depth || raise(Exceptions::SolrKeyConfigurationError.new(name: __method__, config: self))
      end

      # @api public
      # @return Samvera::NestingIndexer::Adapters::AbstractAdapter
      def adapter
        @adapter || default_adapter
      end

      # @raise AdapterConfigurationError if the given adapter does not implement the correct interface
      def adapter=(object)
        object_methods = object.methods
        adapter_methods = Adapters::AbstractAdapter.methods(false)
        # Making sure that the adapter methods are all available in the object_methods
        raise Exceptions::AdapterConfigurationError.new(object, adapter_methods) unless adapter_methods & object_methods == adapter_methods
        @adapter = object
      end

      private

      IN_MEMORY_ADAPTER_WARNING_MESSAGE =
        "WARNING: You are using the default Samvera::NestingIndexer::Adapters::InMemoryAdapter for the Samvera::NestingIndexer.adapter.".freeze

      def default_adapter
        $stdout.puts IN_MEMORY_ADAPTER_WARNING_MESSAGE unless defined?(SUPPRESS_MEMORY_ADAPTER_WARNING)
        require 'samvera/nesting_indexer/adapters/in_memory_adapter'
        Adapters::InMemoryAdapter
      end

      def default_logger
        if defined?(Rails.logger)
          Rails.logger
        else
          Logger.new($stdout)
        end
      end
    end
  end
end
Samvera::NestingIndexer.private_constant :Configuration
