# Set default values for all feature flags
Admin::FeatureFlags.defaults[:maintenance_message] = ''

# Make sure each has an item in the database
Admin::FeatureFlags.save_to_db
