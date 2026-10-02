defmodule SymphonyElixir.DispatchRevalidationTest do
  use SymphonyElixir.TestSupport

  defmodule TrackerClient do
    def fetch_issues_by_states(states) do
      Agent.get(Application.fetch_env!(:symphony_elixir, :dispatch_revalidation_agent), fn data ->
        {:ok, Enum.filter(data.candidates, &(&1.state in states))}
      end)
    end

    def fetch_issues_by_ids(ids) do
      Agent.get_and_update(Application.fetch_env!(:symphony_elixir, :dispatch_revalidation_agent), fn data ->
        {issues, remaining} = List.pop_at(data.responses, 0)
        {{:ok, Enum.filter(issues || data.issues, &(&1.id in ids))}, %{data | responses: remaining}}
      end)
    end
  end

  setup do
    previous_client = Application.get_env(:symphony_elixir, :linear_client_module)
    Application.put_env(:symphony_elixir, :linear_client_module, TrackerClient)

    {:ok, agent} = start_supervised({Agent, fn -> %{candidates: [], issues: [], responses: []} end})
    Application.put_env(:symphony_elixir, :dispatch_revalidation_agent, agent)

    on_exit(fn ->
      if previous_client do
        Application.put_env(:symphony_elixir, :linear_client_module, previous_client)
      else
        Application.delete_env(:symphony_elixir, :linear_client_module)
      end

      Application.delete_env(:symphony_elixir, :dispatch_revalidation_agent)
    end)

    write_workflow_file!(Workflow.workflow_file_path(),
      poll_interval_ms: 300_000,
      max_concurrent_agents: 3,
      max_concurrent_agents_by_state: %{"In Progress" => 1}
    )

    # A failed regression must never start a real agent or model process.
    task_supervisor = start_supervised!({Task.Supervisor, max_children: 0})

    orchestrator =
      start_supervised!({Orchestrator, name: Module.concat(__MODULE__, :Scheduler), task_supervisor: task_supervisor})

    await_initial_poll(orchestrator, System.monotonic_time(:millisecond) + 1_000)

    existing = issue("existing", "In Progress")
    stale = issue("candidate", "Todo")
    refreshed = %{stale | state: "In Progress"}

    :sys.replace_state(orchestrator, fn state ->
      %{
        state
        | running: %{existing.id => running_entry(existing)},
          claimed: MapSet.new([existing.id]),
          tick_token: make_ref(),
          next_poll_due_at_ms: System.monotonic_time(:millisecond) + 300_000
      }
    end)

    {:ok, agent: agent, orchestrator: orchestrator, existing: existing, stale: stale, refreshed: refreshed}
  end

  test "poll rechecks capacity for the refreshed issue state", context do
    %{agent: agent, orchestrator: orchestrator, existing: existing, stale: stale, refreshed: refreshed} = context

    Agent.update(agent, fn data -> %{data | candidates: [stale], issues: [existing, refreshed]} end)
    send(orchestrator, :run_poll_cycle)
    snapshot = GenServer.call(orchestrator, :snapshot)

    assert [%{issue_id: "existing"}] = snapshot.running
    assert snapshot.retrying == []
  end

  test "retry keeps its claim and backs off when the refreshed state is full", context do
    %{agent: agent, orchestrator: orchestrator, existing: existing, stale: stale, refreshed: refreshed} = context
    token = make_ref()
    workspace_path = Path.join(System.tmp_dir!(), "claimed-candidate-workspace")
    issue_url = "https://example.test/issues/candidate"

    Agent.update(agent, fn data -> %{data | issues: [existing, refreshed], responses: [[stale], [refreshed]]} end)

    :sys.replace_state(orchestrator, fn state ->
      %{
        state
        | claimed: MapSet.put(state.claimed, stale.id),
          retry_attempts: %{
            stale.id => %{
              attempt: 1,
              retry_token: token,
              identifier: stale.identifier,
              worker_host: "offline-worker",
              workspace_path: workspace_path,
              issue_url: issue_url
            }
          }
      }
    end)

    send(orchestrator, {:retry_issue, stale.id, token})
    snapshot = GenServer.call(orchestrator, :snapshot)

    assert [%{issue_id: "existing"}] = snapshot.running

    assert [
             %{
               issue_id: "candidate",
               attempt: 2,
               error: "no available orchestrator slots",
               worker_host: "offline-worker",
               workspace_path: ^workspace_path,
               issue_url: ^issue_url
             }
           ] = snapshot.retrying

    assert MapSet.member?(:sys.get_state(orchestrator).claimed, stale.id)
  end

  test "revalidation finds the requested identity instead of trusting response order" do
    wanted = issue("wanted", "Todo")
    unrelated = issue("unrelated", "Todo")
    fetcher = fn ["wanted"] -> {:ok, [unrelated, wanted]} end

    assert {:ok, ^wanted} = Orchestrator.revalidate_issue_for_dispatch_for_test(wanted, fetcher)
  end

  test "revalidation treats unrelated identities as a missing issue" do
    wanted = issue("wanted", "Todo")
    unrelated = issue("unrelated", "Todo")
    fetcher = fn ["wanted"] -> {:ok, [unrelated]} end

    assert {:skip, :missing} = Orchestrator.revalidate_issue_for_dispatch_for_test(wanted, fetcher)
  end

  defp issue(id, state) do
    %Issue{id: id, identifier: "TEST-#{id}", title: id, state: state, dispatchable: true}
  end

  defp await_initial_poll(orchestrator, deadline) do
    snapshot = GenServer.call(orchestrator, :snapshot)

    if snapshot.polling.checking? or snapshot.polling.next_poll_in_ms in [nil, 0] do
      assert System.monotonic_time(:millisecond) < deadline
      Process.sleep(5)
      await_initial_poll(orchestrator, deadline)
    end
  end

  defp running_entry(issue) do
    %{
      issue: issue,
      identifier: issue.identifier,
      pid: self(),
      ref: make_ref(),
      session_id: nil,
      codex_app_server_pid: nil,
      codex_input_tokens: 0,
      codex_output_tokens: 0,
      codex_total_tokens: 0,
      last_codex_timestamp: nil,
      last_codex_message: nil,
      last_codex_event: nil,
      started_at: DateTime.utc_now()
    }
  end
end
