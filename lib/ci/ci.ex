defprotocol CI do
  def get_build_status(repository_details)
end

defimpl CI, for: CircleCI do
  def get_build_status(repository_details) do
    headers = [{"Accept", "application/json"}, {"Content-type", "application/json"}]
    response = HTTPoison.get(repository_details.repo_url, headers)

    build_res =
      case response do
        {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
          body
          |> Poison.decode!()
          |> List.first()
          |> Map.fetch!("status")

        {:ok, %HTTPoison.Response{status_code: 404}} ->
          IO.puts("Not found :(")
          1

        {:error, %HTTPoison.Error{reason: reason}} ->
          IO.inspect(reason)
          1
      end

    IO.puts("Build Result: ")
    IO.inspect(build_res)

    result =
      if build_res != "failed" do
        :passing
      else
        :failing
      end
  end
end

defimpl CI, for: TravisCI do
  def get_build_status(repository_details) do
    # URL
    # 
    IO.puts("Getting build status...")
    response = HTTPoison.get(repository_details.repo_url)
    # IO.inspect(response)

    build_res =
      case response do
        {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
          body
          |> Poison.decode!()
          |> List.first()
          |> Map.fetch!("result")

        {:ok, %HTTPoison.Response{status_code: 404}} ->
          IO.puts("Not found :(")
          1

        {:error, %HTTPoison.Error{reason: reason}} ->
          IO.inspect(reason)
          1
      end

    # IO.inspect(build_res)

    # Not idiomatic, but too lazy to find the right way now.
    result =
      if build_res == 0 do
        :passing
      else
        :failing
      end

    result
  end
end
