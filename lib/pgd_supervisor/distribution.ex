defmodule PgdSupervisor.Distribution do
  @moduledoc """
  Module to store and retrieve PgdSupervisor's distribution information
  """

  @type scope_t() :: atom()

  @type group_t() :: any()

  @spec start_link(scope_t()) :: {:ok, pid()} | {:error, reason :: term()}
  def start_link(scope) do
    :pg.start_link(scope)
  end

  @spec start_link_and_join(scope_t()) :: {:ok, pid()} | {:error, reason :: term()}
  def start_link_and_join(scope) do
    case start_link(scope) do
      {:ok, pid} ->
        :pg.join(scope, member_group(), self())
        {:ok, pid}

      {:error, {:already_started, pid}} ->
        :pg.join(scope, member_group(), self())
        {:ok, pid}

      err ->
        err
    end
  end

  @spec node_ring(scope_t()) :: HashRing.t()
  def node_ring(scope) do
    groups = :pg.which_groups(scope)

    # build a consistent hash ring of existing nodes to distribute
    # child processes among them
    for {:member, node} <- groups, reduce: HashRing.new() do
      acc -> HashRing.add_node(acc, node)
    end
  end

  @spec node_for_resource(scope :: scope_t(), id :: any()) :: Node.t()
  def node_for_resource(scope, id) do
    scope
    |> node_ring()
    |> HashRing.key_to_node(id)
  end

  defp member_group do
    {:member, Node.self()}
  end
end
