:ok = LocalCluster.start()

Application.ensure_all_started(:syn)
Application.ensure_all_started(:libring)

ExUnit.start(capture_log: true)
