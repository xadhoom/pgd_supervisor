defmodule PgdSupervisor.ClusteredTest do
  @moduledoc false
  use ExUnit.Case, async: false

  import AssertAsync

  @supervisor TestApp.DistributedSupervisor

  alias PgdSupervisor.Test.Support.Worker

  setup do
    on_exit(fn ->
      # TODO investigate a better way to remove LocalCluster flakiness
      :timer.sleep(1000)
    end)

    :ok
  end

  test "starts child on a single node in the cluster" do
    [node1, node2] = start_nodes(:test_app, "foo", 2)

    child_spec = Worker.child_spec(:init_args)

    # start_child(node1, child_spec)
    {:ok, pid} = start_child(node2, child_spec)

    assert_async do
      assert %{
               ^node1 => [],
               ^node2 => [{:undefined, ^pid, :worker, [Worker]}]
             } = local_children([node1, node2])
    end
  end

  test "starts children on a different nodes in the cluster" do
    [node1, node2] = start_nodes(:test_app, "foo", 2)

    child_spec_1 = Worker.child_spec(:init_args_1)
    child_spec_2 = Worker.child_spec(:init_args_2)

    {:ok, pid1} = start_child(node1, child_spec_1)
    {:ok, pid2} = start_child(node2, child_spec_2)

    assert_async do
      assert %{
               ^node1 => [{:undefined, ^pid2, :worker, [Worker]}],
               ^node2 => [{:undefined, ^pid1, :worker, [Worker]}]
             } = local_children([node1, node2])
    end
  end

  test "distributes children between nodes when topology changes" do
    [node1, node2] = start_nodes(:test_app, "foo", 2)

    child_spec_1 = Worker.child_spec(10)
    child_spec_2 = Worker.child_spec(20)
    child_spec_3 = Worker.child_spec(30)

    {:ok, pid1} = start_child(node1, child_spec_1)
    {:ok, pid2} = start_child(node1, child_spec_2)
    {:ok, pid3} = start_child(node1, child_spec_3)

    assert_async do
      assert %{
               ^node1 => [{:undefined, ^pid1, :worker, [Worker]}],
               ^node2 => [
                 {:undefined, ^pid2, :worker, [Worker]},
                 {:undefined, ^pid3, :worker, [Worker]}
               ]
             } = local_children([node1, node2])
    end

    # now start another node and a process should migrate to it
    [node3] = start_nodes(:test_app, "bar", 1)

    assert_async do
      assert %{
               ^node1 => [{:undefined, ^pid1, :worker, [Worker]}],
               ^node2 => [{:undefined, ^pid3, :worker, [Worker]}],
               ^node3 => [{:undefined, ^pid2, :worker, [Worker]}]
             } = local_children([node1, node2, node3])
    end
  end

  defp start_child(node, child_spec) do
    :rpc.call(node, PgdSupervisor, :start_child, [@supervisor, child_spec])
  end

  defp local_children(nodes) do
    for node <- nodes, into: %{} do
      local_children = :rpc.call(node, PgdSupervisor, :which_children, [@supervisor])

      {node, Enum.sort(local_children)}
    end
  end

  defp start_nodes(app, prefix, n) do
    LocalCluster.start_nodes(prefix, n,
      applications: [app],
      files: ["test/support/pgd_supervisor/worker.ex"]
    )
  end
end
