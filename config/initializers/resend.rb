# Resend sends the prospect recap email in production (delivery_method :resend,
# registered by the resend gem's railtie). The API key comes from the environment;
# in development (letter_opener) and test (:test) no key is needed, so this is a
# no-op there.
Resend.api_key = ENV["RESEND_API_KEY"] if ENV["RESEND_API_KEY"].present?
