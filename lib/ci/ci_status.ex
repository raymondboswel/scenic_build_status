defmodule CIStatus do
  defstruct status: :failing,
            last_build_timestamp: "",
            last_committer: "",
            last_build_duration: 0,
            project_definition: nil
end
