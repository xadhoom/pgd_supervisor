:ok = LocalCluster.start()

Application.ensure_all_started(:syn)

ExUnit.start()
