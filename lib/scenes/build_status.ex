defmodule ScenicExampleApp.Scene.BuildStatus do
  @moduledoc """
  Scene showing the build status of a predefined project
  """

  use Scenic.Scene
  alias Scenic.Graph
  alias Scenic.ViewPort
  import Scenic.Primitives
  import Scenic.Components

  alias ScenicExampleApp.Component.Nav
  alias ScenicExampleApp.Component.Notes

  @body_offset 60

  @notes """
    \"Components\" shows the basic components available in Scenic.
    Messages sent by the component are displayed live.
    The crash button raises an error, demonstrating how recovery works.
  """

  @event_str "Event received: "

  # ============================================================================

  def init(_, opts) do
    # Get the viewport width
    {:ok, %ViewPort.Status{size: {width, _}}} =
      opts[:viewport]
      |> ViewPort.info()

    graph =
      Graph.build(font: :roboto, font_size: 24, theme: :light)
      |> group(
        fn g ->
          g
          |> text("Build Status", font_size: 32, translate: {width / 2 - 60, 20}, fill: :black)
          |> group(fn g ->
            g
            |> text("Amnesia api:", translate: {15, 60}, id: :event, fill: :black)
            # this button will cause the scene to crash.
            |> circle(10, fill: :yellow, t: {480, 55}, id: :amnesia_status_led)
            |> text("Last build: #{DateTime.to_string(DateTime.utc_now())}",
              translate: {510, 60},
              id: :event,
              fill: :black
            )
          end)
          |> group(
            fn g ->
              g
              |> text("Ignite:", translate: {15, 60}, id: :ignite_header, fill: :black)
              # this button will cause the scene to crash.
              |> circle(10, fill: :yellow, t: {480, 55}, id: :ignite_status_led)
              |> text("Last build: #{DateTime.to_string(DateTime.utc_now())}",
                translate: {510, 60},
                id: :event,
                fill: :black
              )
            end,
            translate: {0, 30}
          )

          # sample components
        end,
        translate: {0, @body_offset + 20}
      )

      # Nav and Notes are added last so that they draw on top
      |> Nav.add_to_graph(__MODULE__)
      |> Notes.add_to_graph(@notes)

    push_graph(graph)
    schedule_build_status_check()
    {:ok, graph}
  end

  defp schedule_build_status_check() do
    # In 20 seconds
    Process.send_after(self(), :check_build_status, 10 * 1000)
  end

  def handle_info(:check_build_status, state) do
    # Do the desired work here
    # Reschedule once more
    IO.puts("Doing work")
    # IO.inspect(state)

    amnesia_api_status = get_amnesia_status()
    Scenic.Scene.send_event(self, {:amnesia_status, amnesia_api_status})

    ignite_status = get_ignite_status()
    Scenic.Scene.send_event(self, {:ignite_status, ignite_status})

    IO.inspect(ignite_status)
    IO.inspect(amnesia_api_status)

    IO.puts("Sent event")
    schedule_build_status_check()
    {:noreply, state}
  end

  def get_amnesia_status() do
    CI.get_build_status(%TravisCI{
      repo_url: "https://api.travis-ci.org/repos/raymondboswel/amnesia_api/builds"
    })
  end

  def get_ignite_status() do
    CI.get_build_status(%CircleCI{
      repo_url: ""
    })
  end

  # force the scene to crash
  def filter_event({:click, :btn_crash}, _, _graph) do
    raise "The crash button was pressed. Crashing now..."
    # No need to return anything. Already crashed.
  end

  def filter_event({:amnesia_status, status}, _, graph) do
    led_color =
      if status == :passing do
        :green
      else
        :red
      end

    graph =
      graph
      |> Graph.modify(:amnesia_status_led, &circle(&1, 10, fill: led_color))
      |> push_graph()

    {:stop, graph}
  end

  def filter_event({:amnesia_status, status}, _, graph) do
    led_color = status_to_color(status)

    graph =
      graph
      |> Graph.modify(:amnesia_status_led, &circle(&1, 10, fill: led_color))
      |> push_graph()

    {:stop, graph}
  end

  def filter_event({:ignite_status, status}, _, graph) do
    led_color = status_to_color(status)

    graph =
      graph
      |> Graph.modify(:ignite_status_led, &circle(&1, 10, fill: led_color))
      |> push_graph()

    {:stop, graph}
  end

  def status_to_color(status) do
    if status == :passing do
      :green
    else
      :red
    end
  end

  # display the received message
  def filter_event(event, _, graph) do
    IO.inspect("Filter event: #{event}")

    graph =
      graph
      |> Graph.modify(:event, &text(&1, @event_str <> inspect(event)))
      |> push_graph()

    {:continue, event, graph}
  end
end
