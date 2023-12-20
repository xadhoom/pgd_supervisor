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
               ^node1 => [{_, ^pid, :worker, [Worker]}],
               ^node2 => []
             } = local_children([node1, node2])
    end
  end

  test "starts children on a different nodes in the cluster" do
    [node1, node2] = start_nodes(:test_app, "foo", 2)

    child_spec_1 = Worker.child_spec(:init_args_a)
    child_spec_2 = Worker.child_spec(:init_args_b)

    {:ok, pid1} = start_child(node1, child_spec_1)
    {:ok, pid2} = start_child(node2, child_spec_2)

    assert_async do
      assert %{
               ^node1 => [{{Worker, :init_args_a}, ^pid1, :worker, [Worker]}],
               ^node2 => [{{Worker, :init_args_b}, ^pid2, :worker, [Worker]}]
             } = local_children([node1, node2])
    end
  end

  test "distributes children between nodes when topology changes" do
    [node1, node2] = start_nodes(:test_app, "foo", 2)

    child_spec_1 = Worker.child_spec(:a)
    child_spec_2 = Worker.child_spec(:b)
    child_spec_3 = Worker.child_spec(:c)

    {:ok, pid1} = start_child(node1, child_spec_1)
    {:ok, pid2} = start_child(node1, child_spec_2)
    {:ok, pid3} = start_child(node1, child_spec_3)

    assert_async do
      assert %{
               ^node1 => [
                 {{Worker, :a}, ^pid1, :worker, [Worker]},
                 {{Worker, :c}, ^pid3, :worker, [Worker]}
               ],
               ^node2 => [
                 {{Worker, :b}, ^pid2, :worker, [Worker]}
               ]
             } = local_children([node1, node2])
    end

    # now start another node and a process should migrate to it
    [node3] = start_nodes(:test_app, "bar", 1)

    assert_async do
      assert %{
               ^node1 => [{{Worker, :c}, _, :worker, [Worker]}],
               ^node2 => [{{Worker, :b}, _, :worker, [Worker]}],
               ^node3 => [{{Worker, :a}, _, :worker, [Worker]}]
             } = local_children([node1, node2, node3])
    end
  end

  test "restart process on another node when the node it was scheduled on goes down" do
    [node1, node2, node3] = start_nodes(:test_app, "foo", 3)

    child_spec_1 = Worker.child_spec(:a)
    child_spec_2 = Worker.child_spec(:b)
    child_spec_3 = Worker.child_spec(:e)

    {:ok, _pid1} = start_child(node1, child_spec_1)
    {:ok, _pid2} = start_child(node1, child_spec_2)
    {:ok, _pid3} = start_child(node1, child_spec_3)

    assert_async do
      assert %{
               ^node1 => [{{Worker, :a}, _, :worker, [Worker]}],
               ^node2 => [{{Worker, :b}, _, :worker, [Worker]}],
               ^node3 => [{{Worker, :e}, _, :worker, [Worker]}]
             } = local_children([node1, node2, node3])
    end

    stop_nodes([node3])

    assert_async do
      assert %{
               ^node1 => [
                 {{Worker, :a}, _, :worker, [Worker]},
                 {{Worker, :e}, _, :worker, [Worker]}
               ],
               ^node2 => [
                 {{Worker, :b}, _, :worker, [Worker]}
               ]
             } = local_children([node1, node2])
    end
  end

  describe "which_children/1" do
    test "returns children running on the local node" do
      [node1, node2] = start_nodes(:test_app, "foo", 2)

      child_spec_1 = Worker.child_spec(:init_args_a)
      child_spec_2 = Worker.child_spec(:init_args_b)

      {:ok, _pid1} = start_child(node1, child_spec_1)
      {:ok, _pid2} = start_child(node2, child_spec_2)

      assert_async do
        assert [{{Worker, :init_args_a}, _, :worker, [Worker]}] =
                 :rpc.call(node1, PgdSupervisor, :which_children, [@supervisor])
      end

      assert_async do
        assert [{{Worker, :init_args_b}, _, :worker, [Worker]}] =
                 :rpc.call(node2, PgdSupervisor, :which_children, [@supervisor])
      end
    end
  end

  describe "it is not possible to start children with the same id" do
    test "on the same node" do
      [node1, _node2] = start_nodes(:test_app, "foo", 2)
      child_spec_1 = Worker.child_spec(:init_args_a)

      {:ok, _pid1} = start_child(node1, child_spec_1)
      assert {:error, :already_present} = start_child(node1, child_spec_1)
    end

    test "on a different node" do
      [node1, node2] = start_nodes(:test_app, "foo", 2)
      child_spec_1 = Worker.child_spec(:init_args_a)

      {:ok, _pid1} = start_child(node1, child_spec_1)
      assert {:error, :already_present} = start_child(node2, child_spec_1)
    end
  end

  describe "which_children/2" do
    test "returns children running on the node when called with :local" do
      [node1, node2] = start_nodes(:test_app, "foo", 2)

      child_spec_1 = Worker.child_spec(:init_args_a)
      child_spec_2 = Worker.child_spec(:init_args_b)

      {:ok, _pid1} = start_child(node1, child_spec_1)
      {:ok, _pid2} = start_child(node2, child_spec_2)

      assert_async do
        assert [{{Worker, :init_args_a}, _, :worker, [Worker]}] =
                 :rpc.call(node1, PgdSupervisor, :which_children, [@supervisor, :local])
      end

      assert_async do
        assert [{{Worker, :init_args_b}, _, :worker, [Worker]}] =
                 :rpc.call(node2, PgdSupervisor, :which_children, [@supervisor, :local])
      end
    end

    test "returns all children running on the node when called with :global" do
      [node1, node2] = start_nodes(:test_app, "foo", 2)

      child_spec_1 = Worker.child_spec(:init_args_a)
      child_spec_2 = Worker.child_spec(:init_args_b)

      {:ok, pid1} = start_child(node1, child_spec_1)
      {:ok, pid2} = start_child(node2, child_spec_2)

      assert_async do
        assert [
                 {{Worker, :init_args_a}, wpid1, :worker, [Worker]},
                 {{Worker, :init_args_b}, wpid2, :worker, [Worker]}
               ] = :rpc.call(node1, PgdSupervisor, :which_children, [@supervisor, :global])

        assert pid1 in [wpid1, wpid2]
        assert pid2 in [wpid1, wpid2]
      end

      assert_async do
        assert [
                 {{Worker, :init_args_a}, wpid1, :worker, [Worker]},
                 {{Worker, :init_args_b}, wpid2, :worker, [Worker]}
               ] = :rpc.call(node2, PgdSupervisor, :which_children, [@supervisor, :global])

        assert pid1 in [wpid1, wpid2]
        assert pid2 in [wpid1, wpid2]
      end
    end
  end

  describe "count_children/1" do
    test "counts children running on the local node" do
      [node1, node2] = start_nodes(:test_app, "foo", 2)

      child_spec_1 = Worker.child_spec(:init_args_a)
      child_spec_2 = Worker.child_spec(:init_args_b)

      {:ok, _pid1} = start_child(node1, child_spec_1)
      {:ok, _pid2} = start_child(node2, child_spec_2)

      assert_async do
        assert %{active: 1, specs: 1, supervisors: 0, workers: 1} =
                 :rpc.call(node1, PgdSupervisor, :count_children, [@supervisor])
      end

      assert_async do
        assert %{active: 1, specs: 1, supervisors: 0, workers: 1} =
                 :rpc.call(node2, PgdSupervisor, :count_children, [@supervisor])
      end
    end
  end

  describe "count_children/2" do
    test "counts children running on the local node when called with :local" do
      [node1, node2] = start_nodes(:test_app, "foo", 2)

      child_spec_1 = Worker.child_spec(:init_args_a)
      child_spec_2 = Worker.child_spec(:init_args_b)

      {:ok, _pid1} = start_child(node1, child_spec_1)
      {:ok, _pid2} = start_child(node2, child_spec_2)

      assert_async do
        assert %{active: 1, specs: 1, supervisors: 0, workers: 1} =
                 :rpc.call(node1, PgdSupervisor, :count_children, [@supervisor, :local])
      end

      assert_async do
        assert %{active: 1, specs: 1, supervisors: 0, workers: 1} =
                 :rpc.call(node2, PgdSupervisor, :count_children, [@supervisor, :local])
      end
    end

    test "counts children running on all nodes when called with :global" do
      [node1, node2] = start_nodes(:test_app, "foo", 2)

      child_spec_1 = Worker.child_spec(:init_args_1)
      child_spec_2 = Worker.child_spec(:init_args_2)

      {:ok, _pid1} = start_child(node1, child_spec_1)
      {:ok, _pid2} = start_child(node2, child_spec_2)

      assert_async do
        assert %{active: 2, specs: 2, supervisors: 0, workers: 2} =
                 :rpc.call(node1, PgdSupervisor, :count_children, [@supervisor, :global])
      end

      assert_async do
        assert %{active: 2, specs: 2, supervisors: 0, workers: 2} =
                 :rpc.call(node2, PgdSupervisor, :count_children, [@supervisor, :global])
      end
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
      applications: [:syn, :libring, app],
      files: ["test/support/pgd_supervisor/worker.ex"]
    )
  end

  defp stop_nodes(nodes) do
    LocalCluster.stop_nodes(nodes)
  end
end
