class LanguageCoMailer < ActionMailer::Base
  default from: "unnawut@unnawut.in.th"

  def new_translators_email(language, language_co_email, new_translators)
  	@language = language
  	@language_co_email = language_co_email
    @new_translators = new_translators

    mail(:to => language_co_email, :subject => "New TED Translators")
  end

end
