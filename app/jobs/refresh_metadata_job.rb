require 'app/helpers/logging_helper'
require 'app/helpers/library_file_system_helper'
require 'app/helpers/metadata_helper'
require 'app/models/book'

module EBL
  module Jobs
    # A background job that will refresh the metadata of
    # an EBL book entry, using the latest data from the file.
    class RefreshMetadataJob
      include SuckerPunch::Job
      include EBL::Helpers::LoggingHelper
      include EBL::Helpers::LibraryFileSystemHelper
      include EBL::Helpers::MetadataHelper

      def update_metadata
        metadata = extract_metadata_from_epub(book.path)

        book.remove_all_authors
        metadata.authors.each { |a| book.add_author a }

        book.remove_all_dates
        metadata.dates.each { |d| book.add_date d }

        book.remove_all_identifiers
        metadata.identifiers.each { |i| book.add_identifier i }

        book.remove_all_subjects
        metadata.subjects.each { |s| book.add_subject s }
      end

      # @return [Boolena] true if the job should be skipped.
      def should_ignore?
        !ignore_checksum && !checksum_changed?(book)
      end

      # Refresh the metadata stored in the database for the specified book.
      # @param book_id [Integer] the ID of the book to refresh.
      # @param ignore_checksum [Boolean] a flag indicating whether or not
      #   to ignore the checksum of the file
      def perform(book_id, ignore_checksum = false)
        setup_logger 'job:refresh_metadata'
        self.book = EBL::Models::Book.first(id: book_id)
        self.ignore_checksum = ignore_checksum

        if book.nil?
          log_error "Could not find book #{book_id}"
          return
        end

        return if should_ignore?
        update_metadata
        log_green "Refreshed metadata for #{book.title} [#{book.id}]"
      end

      # @return [EBL::Models::Book] the book being refreshed.
      attr_accessor :book

      # @return [Boolean] a flag indicating whether or not to
      #   ignore checksum changes.
      attr_accessor :ignore_checksum
    end
  end
end