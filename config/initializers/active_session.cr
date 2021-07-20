require "../../src/active_session"
require "../../src/clients/login_client"

ActiveSession.set(Amber.settings.secrets["session_key"], Amber.settings.secrets["session_value"])
