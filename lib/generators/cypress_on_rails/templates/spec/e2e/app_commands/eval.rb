# Intentional: executes test-only commands forwarded from Cypress/Playwright.
# The middleware that invokes this template is mounted only in test/development.
Kernel.eval(command_options) unless command_options.nil? # rubocop:disable Security/Eval
