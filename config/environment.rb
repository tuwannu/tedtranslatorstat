# Load the rails application
require File.expand_path('../application', __FILE__)

# Initialize the rails application
RailsApp::Application.initialize!

# Disable auto TLS for e-mails
ActionMailer::Base.smtp_settings[:enable_starttls_auto] = false