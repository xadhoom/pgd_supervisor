defmodule SynSupervisor.Distribution do
  @moduledoc """
  Module to store and retrieve SynSupervisor's distribution information
  """

  alias SynSupervisor.Distribution.Child

  @type scope_t() :: atom()

  @type group_t() :: any()

  @type child_mapper_t :: (Child.t() -> any())

  @spec start(scope_t()) :: :ok
  def start(scope) do
    :syn.add_node_to_scopes([scope])
  end

  @spec start_and_join(scope_t()) :: :ok
  def start_and_join(scope) do
    start(scope)
    :syn.join(scope, member_group(Node.self()), self())
  end

  @spec child_join(scope_t(), Child.id_t(), Node.t(), pid(), pid(), Child.spec_t()) ::
          :ok | {:error, term()}
  def child_join(scope, id, node, supervisor, child_pid, child_spec) do
    child = %Child{
      id: id,
      node: node,
      pid: child_pid,
      spec: child_spec,
      supervisor_pid: supervisor
    }

    case :syn.join(scope, child_group(child), child_pid) do
      :ok ->
        track_spec(scope, child_spec)
        :ok

      err ->
        err
    end
  end

  @spec find_child(scope_t(), Child.id_t() | pid()) :: {:ok, Child.t()} | {:error, :not_found}
  def find_child(scope, pid) when is_pid(pid) do
    find_child_with_fn(
      scope,
      fn
        %Child{pid: ^pid} = c ->
          {:ok, c}

        _ ->
          false
      end
    )
  end

  def find_child(scope, id) do
    find_child_with_fn(
      scope,
      fn
        %Child{id: ^id} = c ->
          {:ok, c}

        _ ->
          false
      end
    )
  end

  @spec list_children(scope_t()) :: list(Child.t())
  def list_children(scope) do
    child_groups(scope)
    |> Enum.map(fn {:child, %Child{} = c} ->
      c
    end)
  end

  @spec find_spec(scope_t(), Child.id_t()) :: {:ok, Child.spec_t()} | {:error, :not_found}
  def find_spec(scope, child_id) do
    scope
    |> spec_groups()
    |> Enum.find_value(
      {:error, :not_found},
      fn
        {:spec, {^child_id, _, _, _, _, _} = s} ->
          {:ok, s}

        _ ->
          false
      end
    )
  end

  @spec map_children(scope_t(), (Child.t() -> arg)) :: list(arg) when arg: any
  def map_children(scope, child_mapper_fun) do
    scope
    |> child_groups()
    |> Enum.map(fn {:child, child} -> child_mapper_fun.(child) end)
  end

  @spec each_child(scope_t(), (Child.t() -> any())) :: :ok
  def each_child(scope, fun) do
    scope
    |> child_groups()
    |> Enum.each(fn {:child, child} -> fun.(child) end)
  end

  @spec reduce_child(scope_t(), acc, (Child.t(), acc -> acc)) :: acc when acc: any()
  def reduce_child(scope, acc, fun) do
    scope
    |> child_groups()
    |> Enum.reduce(acc, fn {:child, child}, acc -> fun.(child, acc) end)
  end

  @spec reduce_specs(scope_t(), acc, (Child.spec_t(), acc -> acc)) :: acc when acc: any()
  def reduce_specs(scope, acc, fun) do
    scope
    |> spec_groups()
    |> Enum.reduce(acc, fn {:spec, spec}, acc -> fun.(spec, acc) end)
  end

  @spec node_for_child(scope_t(), Child.spec_t()) :: Node.t()
  def node_for_child(scope, child_spec) do
    scope
    |> create_ring()
    |> HashRing.Managed.key_to_node(child_spec)
  end

  @spec member_for_node(scope_t(), Node.t()) :: nil | pid()
  def member_for_node(scope, node) do
    case :syn.members(scope, member_group(node)) do
      [{member, _meta} | _] -> member
      _ -> nil
    end
  end

  @spec member_for_child(scope_t(), Child.spec_t()) :: {Node.t(), nil | pid()}
  def member_for_child(scope, child_spec) do
    node = node_for_child(scope, child_spec)
    {node, member_for_node(scope, node)}
  end

  @spec untrack_spec(scope_t(), Child.spec_t()) :: list(:ok | {:error, term()})
  def untrack_spec(scope, child_spec) do
    scope
    |> :syn.members(spec_group(child_spec))
    |> Enum.map(fn {pid, _meta} -> pid end)
    |> then(&multi_leave(scope, spec_group(child_spec), &1))
  end

  @spec check_members(scope_t()) :: :ok
  def check_members(scope) do
    create_ring(scope, check_members: true)
    :ok
  end

  @spec create_ring(scope_t(), list({:check_members, boolean()})) :: scope_t()
  defp create_ring(scope, opts \\ []) do
    maybe_create_hash_ring(scope)

    nodes =  get_nodes(scope)

    if Keyword.get(opts, :check_members, false) do
      current_nodes = MapSet.new(nodes)

      scope
      |> HashRing.Managed.nodes()
      |> MapSet.new()
      |> MapSet.difference(current_nodes)
      |> Enum.each(&HashRing.Managed.remove_node(scope, &1))
    end

    # build a consistent hash ring of existing nodes to distribute
    # child processes among them
    HashRing.Managed.add_nodes(scope, nodes)
    scope
  end

  @spec maybe_create_hash_ring(scope_t()) :: pid()
  defp maybe_create_hash_ring(scope) do
    case HashRing.Managed.new(scope) do
      {:ok, pid} -> pid
      {:error, {:already_started, pid}} -> pid
    end
  end

  @spec find_child_with_fn(scope_t(), ({:child, Child.t()} -> boolean())) ::
          {:ok, Child.t()} | {:error, :not_found}
  defp find_child_with_fn(scope, fun) do
    scope
    |> child_groups()
    |> Enum.find_value(
      {:error, :not_found},
      fn {:child, c} ->
        if fun.(c) do
          {:ok, c}
        else
          false
        end
      end
    )
  end

  @spec track_spec(scope_t(), Child.spec_t()) :: list(:ok | {:error, term()})
  defp track_spec(scope, child_spec) do
    scope
    |> supervisors()
    |> then(&multi_join(scope, spec_group(child_spec), &1))
  end

  defp multi_join(scope, group, pids) do
    Enum.map(pids, &:syn.join(scope, group, &1))
  end

  defp multi_leave(scope, group, pids) do
    Enum.map(pids, &:syn.leave(scope, group, &1))
  end

  @spec supervisors(scope_t()) :: list(pid())
  defp supervisors(scope) do
    scope
    |> :syn.group_names()
    |> Enum.filter(fn
      {:member, _} -> true
      _ -> false
    end)
    |> Enum.flat_map(&:syn.members(scope, &1))
    |> Enum.map(fn {pid, _meta} -> pid end)
    |> Enum.uniq()
  end

  defp child_groups(scope) do
    scope
    |> :syn.group_names()
    |> Enum.filter(fn
      {:child, _child} -> true
      _ -> false
    end)
  end

  defp spec_groups(scope) do
    scope
    |> :syn.group_names()
    |> Enum.filter(fn
      {:spec, _child_spec} -> true
      _ -> false
    end)
  end

  defp spec_group(child_spec) do
    {:spec, child_spec}
  end

  defp member_group(node) do
    {:member, node}
  end

  defp child_group(%Child{} = c) do
    {:child, c}
  end

  defp get_nodes(scope) do
      members_group_names(scope)
  end

  defp members_group_names(scope) do
    node_param = :_
    case :syn_backbone.get_table_name(:syn_pg_by_name, scope) do
      :undefined ->
        raise "cannot get table name"
      table_by_name ->
        duplicated_groups = :ets.select(table_by_name, [{
          {{{:"$1", :"$2"}, :_}, :_, :_, :_, node_param},
          [{:==, :"$1", :member}],
          [:"$2"]
        }])

        duplicated_groups |> :ordsets.from_list() |> :ordsets.to_list()
    end
  end
end
