defmodule SymphonyElixir.ClaudeACPTest do
  use SymphonyElixir.TestSupport

  alias SymphonyElixir.Claude.ACP

  test "claude acp wrapper starts a session, runs a turn, and stops cleanly" do
    test_root =
      Path.join(
        System.tmp_dir!(),
        "symphony-elixir-claude-acp-wrapper-#{System.unique_integer([:positive])}"
      )

    try do
      workspace_root = Path.join(test_root, "workspaces")
      workspace = Path.join(workspace_root, "MT-CLAUDE-1")
      codex_binary = Path.join(test_root, "fake-codex")
      File.mkdir_p!(workspace)

      File.write!(codex_binary, """
      #!/bin/sh
      count=0
      while IFS= read -r _line; do
        count=$((count + 1))

        case "$count" in
          1)
            printf '%s\\n' '{"id":1,"result":{}}'
            ;;
          2)
            printf '%s\\n' '{"id":2,"result":{"thread":{"id":"thread-claude-wrapper"}}}'
            ;;
          3)
            printf '%s\\n' '{"id":3,"result":{"turn":{"id":"turn-claude-wrapper"}}}'
            ;;
          4)
            printf '%s\\n' '{"method":"turn/completed"}'
            ;;
          *)
            ;;
        esac
      done
      """)

      File.chmod!(codex_binary, 0o755)

      write_workflow_file!(Workflow.workflow_file_path(),
        workspace_root: workspace_root,
        codex_command: "#{codex_binary} app-server"
      )

      issue = %Issue{
        id: "issue-claude-wrapper",
        identifier: "MT-CLAUDE-1",
        title: "Claude ACP wrapper",
        description: "Exercise wrapper calls",
        state: "In Progress",
        url: "https://example.org/issues/MT-CLAUDE-1",
        labels: ["agent:claude"]
      }

      assert {:ok, session} = ACP.start_session(workspace)
      assert {:ok, turn} = ACP.run_turn(session, "Validate Claude ACP wrapper", issue)
      assert turn[:session_id] == "thread-claude-wrapper-turn-claude-wrapper"
      assert :ok = ACP.stop_session(session)
    after
      File.rm_rf(test_root)
    end
  end
end
