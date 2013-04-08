class LanguageCoMailer < ActionMailer::Base
  default from: "unnawut@unnawut.in.th"

  def new_translators_email(code, language, emails, new_translators)
  	@code = code
  	@language = language
  	@emails = emails
    @new_translators = new_translators

    mail(:to => emails, :subject => "New #{language} TED Translators")
  end

end
