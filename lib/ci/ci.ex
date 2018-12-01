defprotocol CI do
  def get_build_status(repository_details)
end

defimpl CI, for: CircleCI do
  def get_build_status(project_definition) do
    access_token = Application.get_env(:scenic_example_app, :ci_config).circle_ci_access_token

    url =
      "https://circleci.com/api/v1.1/project/github/Fastcomm/#{project_definition.repo_name}/tree/master?circle-token=#{
        access_token
      }&limit=1"

    headers = [{"Accept", "application/json"}, {"Content-type", "application/json"}]
    response = HTTPoison.get(url, headers)

    build_details =
      case response do
        {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
          body
          |> Poison.decode!()
          |> List.first()

        {:ok, %HTTPoison.Response{status_code: 404}} ->
          IO.puts("Not found :(")
          1

        {:error, %HTTPoison.Error{reason: reason}} ->
          IO.inspect(reason)
          1
      end

    IO.puts("Build Result: ")
    IO.inspect(build_details)

    ci_status = %CIStatus{
      status: CIResultParser.parse_build_status(build_details),
      last_build_timestamp: build_details |> Map.fetch!("committer_date"),
      last_committer:
        build_details
        |> Map.fetch!("all_commit_details")
        |> List.first()
        |> Map.fetch!("author_name"),
      last_build_duration:
        ((build_details |> Map.fetch!("build_time_millis")) / 1000) |> Float.to_string()
    }

    ci_status
  end
end

defimpl CI, for: TravisCI do
  def get_build_status(project_definition) do
    url = "https://api.travis-ci.org/repos/raymondboswel/#{project_definition.repo_name}/builds"
    response = HTTPoison.get(url)

    build_res =
      case response do
        {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
          body
          |> Poison.decode!()
          |> List.first()

        {:ok, %HTTPoison.Response{status_code: 404}} ->
          IO.puts("Not found :(")
          1

        {:error, %HTTPoison.Error{reason: reason}} ->
          IO.inspect(reason)
          1
      end

    IO.inspect(build_res)

    status =
      if build_res |> Map.fetch!("result") == 0 do
        :passing
      else
        :failing
      end

    # Not idiomatic, but too lazy to find the right way now.
    ci_status = %CIStatus{
      status: status,
      last_build_timestamp: build_res |> Map.fetch!("started_at"),
      last_committer: "",
      last_build_duration: build_res |> Map.fetch!("duration") |> Integer.to_string()
    }

    ci_status
  end
end
