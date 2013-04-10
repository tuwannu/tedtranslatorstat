class LanguageCoMailer < ActionMailer::Base
  default from: ENV['TEDTRANSLATORSTAT_FROM_EMAIL']

  def new_translators_email(code, language, emails, new_translators)
  	@code = code
  	@language = language
  	@emails = emails
    @new_translators = new_translators

    mail(:to => emails, :subject => "New #{language} TED Translators")
  end

end
