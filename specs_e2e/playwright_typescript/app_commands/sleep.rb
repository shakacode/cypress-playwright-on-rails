# Answers after a delay, so the specs can check the helpers' request timeouts.
seconds = command_options.fetch('seconds').to_f
sleep(seconds)
"slept #{seconds}"
