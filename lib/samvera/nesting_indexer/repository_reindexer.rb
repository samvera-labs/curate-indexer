require 'samvera/nesting_indexer/exceptions'
require 'forwardable'
module Samvera
  module NestingIndexer
    # Responsible for reindexing the entire repository
    # @api private
    # @note There is cycle detection logic for walking the graph prior to attempting relationship re-indexing
    class RepositoryReindexer
      # @api private
      #
      # A convenience method to reindex all documents.
      #
      # @note This could crush your system as it will loop through ALL the documents
      #
      # @see #initialize
      # @return Samvera::NestingIndexer::RepositoryReindexer
      def self.call(*args)
        new(*args).call
      end

      # @param id_reindexer [#call] Samvera::NestingIndexer.method(:reindex_relationships) Responsible for reindexing a single object
      # @param maximum_nesting_depth [Integer] detect cycles in the graph
      # @param configuration [#adapter, #logger] The :adapter conforms to the Samvera::NestingIndexer::Adapters::AbstractAdapter interface
      #                                          and the :logger conforms to Logger
      def initialize(maximum_nesting_depth:, id_reindexer:, configuration:, extent:)
        @maximum_nesting_depth = maximum_nesting_depth.to_i
        @id_reindexer = id_reindexer
        @configuration = configuration
        @extent = extent
        @processed_ids = []
      end

      # @todo Would it make sense to leverage an each_preservation_id instead?
      def call
        adapter.each_perservation_document_id_and_parent_ids do |id, parent_ids|
          recursive_reindex(id: id, parent_ids: parent_ids, time_to_live: maximum_nesting_depth)
        end
      end

      private

      attr_reader :maximum_nesting_depth, :processed_ids, :id_reindexer, :configuration, :extent

      extend Forwardable
      def_delegator :configuration, :adapter
      def_delegator :configuration, :logger
      def_delegator :configuration, :stop_on_failure

      # When we find a document, reindex it if it doesn't have a parent. If it has a parent, reindex the parent first.
      #
      # Given that we are attempting to reindex the parents before we reindex a document, we can't rely on
      # the reindex maximum_nesting_depth but instead must have a separate time to live.
      #
      # The reindexing process assumes that an object's parents have been indexed; Thus we need to
      # walk up the parent graph to reindex the parents before we start on the child.
      def recursive_reindex(id:, parent_ids:, time_to_live:)
        return true if processed_ids.include?(id)
        raise Exceptions::ExceededMaximumNestingDepthError, id: id if time_to_live <= 0
        parent_ids.each do |parent_id|
          grand_parent_ids = adapter.find_preservation_parent_ids_for(id: parent_id)
          recursive_reindex(id: parent_id, parent_ids: grand_parent_ids, time_to_live: maximum_nesting_depth - 1)
        end
        reindex_an_id(id)
      end

      def reindex_an_id(id)
        id_reindexer.call(id: id, extent: extent)
        processed_ids << id
      rescue StandardError => e
        logger.error("Failed: #{id}")
        logger.error(e)
        raise Exceptions::ReindexingError.new(id, e) if stop_on_failure
      end
    end
  end
end
Samvera::NestingIndexer.private_constant :RepositoryReindexer
