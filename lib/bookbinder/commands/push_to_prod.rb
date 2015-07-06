require_relative '../deploy/distributor'
require_relative 'naming'

module Bookbinder
  class PushToProdValidator
    MissingRequiredKeyError = Class.new(RuntimeError)
  end

  module Commands
    class PushToProd
      include Commands::Naming
      CONFIG_REQUIRED_KEYS = %w(cred_repo)

      def initialize(streams, logger, configuration_fetcher, app_dir)
        @streams = streams
        @logger = logger
        @configuration_fetcher = configuration_fetcher
        @app_dir = app_dir
      end

      def usage
        ["push_to_prod [build_#]",
         "Push latest or <build_#> from your S3 bucket to the production host specified in credentials.yml"]
      end

      def run(arguments)
        streams[:warn].puts "Warning: You are pushing to production."
        validate
        Deploy::Distributor.build(@logger, options(arguments)).distribute
        0
      end

      private

      attr_reader :app_dir, :configuration_fetcher, :streams

      def options(arguments)
        {
          app_dir: app_dir,
          build_number: arguments[0],

          aws_credentials: credentials[:aws],
          cf_credentials: credentials[:cloud_foundry],

          book_repo: config.book_repo,
        }
      end

      def credentials
        configuration_fetcher.fetch_credentials('production')
      end

      def config
        @config ||= configuration_fetcher.fetch_config
      end

      def validate
        missing_keys = []
        CONFIG_REQUIRED_KEYS.map do |required_key|
          unless config.has_option?(required_key)
            missing_keys.push(required_key)
          end
        end

        if missing_keys.length > 0
          raise PushToProdValidator::MissingRequiredKeyError.new "Your config.yml is missing required key(s). The require keys for this commands are " + missing_keys.join(", ")
        end
      end

    end
  end
end
