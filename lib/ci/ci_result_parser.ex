defmodule CIResultParser do
  def parse_build_status(build_details) do
    if build_details |> Map.fetch!("status") != "failed" do
      :passing
    else
      :failing
    end
  end
end
