defmodule ProjectDefinition do
  # Exact name of repo
  defstruct repo_name: "",
            # Print name of project
            project_name: "",
            ci_server: :circle_ci
end
