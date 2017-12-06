# Include this module to get access to the GOVUK Content Schema examples in the
# tests.
#
# By default, the govuk-content-schemas repository is expected to be located
# at ../govuk-content-schemas. This can be overridden with the
# GOVUK_CONTENT_SCHEMAS_PATH environment variable, for example:
#
#   $ GOVUK_CONTENT_SCHEMAS_PATH=/some/dir/govuk-content-schemas bundle exec rake
#
require 'gds_api/test_helpers/content_store'

GovukContentSchemaTestHelpers.configure do |config|
  config.schema_type = 'frontend'
  config.project_root = Rails.root
end

module GovukContentSchemaExamples
  extend ActiveSupport::Concern

  included do
    include GdsApi::TestHelpers::ContentStore

    # Returns a hash representing an email_alert_signup content item from govuk-content-schemas
    def govuk_content_schema_example(name, format = 'email_alert_signup')
      string = GovukContentSchemaTestHelpers::Examples.new.get(format, name)
      JSON.parse(string)
    end
  end
end
