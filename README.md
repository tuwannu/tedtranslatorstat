# TED Translator Statistics Project #

Project by [Unnawut Leepaisalsuwanna](http://www.unnawut.in.th "Unnawut Leepaisalsuwanna") aimed to provide TED OTP Language Coordinator a better view of activities by OTP members.

## Current Features ##

1. Scrape TED Translator statistics from TED.com on daily basis (currently only Thai, Swedish, Dutch translators to avoid overloading TED.com)
    1. \# of completed tasks (translations + reviews) across time.
    1. \# of new translators in the past 2 weeks.
    1. \# of active translators (translators that completed a task) in the past 2 weeks.
    1. \# of newly completed tasks in the past 2 weeks.
    1. Total translators so far.
    1. Total completed tasks so far.

2. Scrape last translators joined. Send email to LCs when a new translator joined for each LC's responsible language. Enabled per request.

## Suggest new features ##

Please e-mail me at "unnawut [at] unnawut.in.th"

## Installation ##

Please setup the following environment variables in your development environment. These variables are used by config/database.yml

1. TEDTRANSLATORSTAT_DB_NAME
2. TEDTRANSLATORSTAT_DB_USERNAME
3. TEDTRANSLATORSTAT_DB_PASSWORD
4. TEDTRANSLATORSTAT_FROM_EMAIL
5. TEDTRANSLATORSTAT_SMTP_SERVER
6. TEDTRANSLATORSTAT_SMTP_DOMAIN
7. TEDTRANSLATORSTAT_SMTP_USERNAME
8. TEDTRANSLATORSTAT_SMTP_PASSWORD