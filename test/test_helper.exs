:ok = LocalCluster.start()

Application.ensure_all_started(:syn)
Application.ensure_all_started(:libring)

require Logger
Logger.configure(level: :warning)

ExUnit.start(capture_log: true)
