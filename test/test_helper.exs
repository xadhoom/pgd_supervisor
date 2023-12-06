:ok = LocalCluster.start()

Application.ensure_all_started(:pgd_supervisor)

ExUnit.start()
