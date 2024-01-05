defmodule BlueWeb.MaterialsLive do
  alias Blue.Blueprint
  alias Blue.Building
  alias Blue.Element
  alias Blue.Original
  require Logger
  use BlueWeb, :live_view

  def render(assigns) do
    ~H"""
    <div><%= @counter %></div>
    <h1><%= @blueprint["friendlyname"] %></h1>
    <div class="flex gap-2">
      <div>
        <%= for mat <- @materials do %>
          <.material_picker build_mat={mat} replacements={@replacements} />
        <% end %>
      </div>
      <pre>
      <%= inspect(@replacements, pretty: true) %>
    </pre>
    </div>
    """
  end

  defp material_picker(assigns) do
    ~H"""
    <div class="border border-blue-200 m-4 p-2">
      <h2><%= @build_mat.building_name %></h2>

      <%= for hash <- @build_mat.selected_elements do %>
        <% chosen = get_replacement(@replacements, @build_mat.buildingdef, @build_mat.selected_elements, hash) %>

        <div class={["flex gap-2 p-2 items-center", changed_mat_class(chosen != hash)]}>
          <span>Replace</span>
          <span><%= Element.find!(hash).name %></span>
          <span>with</span>
          <form
            phx-change="select_replacement"
            phx-value-replaced_hash={hash}
            phx-value-original_elements={Jason.encode!(@build_mat.selected_elements)}
            phx-value-buildingdef={@build_mat.buildingdef}
          >
            <select name="replacement_id" class="p-1 text-sm border border-gray-300">
              <%= for element <- Element.list_all() do %>
                <option value={element.id} selected={chosen == element.hash}>
                  <%= element.name %>
                </option>
              <% end %>
            </select>
          </form>
        </div>
      <% end %>
    </div>
    """
  end

  defp changed_mat_class(true), do: "bg-yellow-100"
  defp changed_mat_class(_), do: nil

  def mount(_params, _session, socket) do
    {:ok, blueprint} = Original.by_name("terrasieve")
    materials = prepare_mats(blueprint)

    replacements = %{
      {"Door", [-1_736_594_426], -1_736_594_426} => 1_608_833_498
    }

    if connected?(socket), do: send_tick()

    {:ok,
     assign(socket,
       counter: 0,
       blueprint: blueprint,
       materials: materials,
       replacements: replacements
     )}
  end

  def handle_event("select_replacement", params, socket) do
    case select_replacement(socket.assigns.replacements, params) do
      {:ok, replacements} ->
        socket = socket |> assign(replacements: replacements) |> put_flash(:info, "Ok")
        {:noreply, socket}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Invalid replacement")}
    end
  end

  defp select_replacement(replacements, params) do
    with %{
           "buildingdef" => buildingdef,
           "original_elements" => selected_elements_json,
           "replaced_hash" => replaced_hash_str,
           "replacement_id" => replacement_id
         } <- params,
         {:ok, selected_elements_hashs} <- Jason.decode(selected_elements_json),
         true <- Enum.all?(selected_elements_hashs, &is_integer/1),
         true <- Enum.all?(selected_elements_hashs, &match?({:ok, _}, Element.find(&1))),
         {:ok, %{hash: replacement_hash}} <- Element.find(replacement_id),
         {:ok, _} <- Building.by_id(buildingdef),
         {replaced_hash, ""} <- Integer.parse(replaced_hash_str),
         {:ok, _} <- Building.by_id(buildingdef) do
      binding() |> IO.inspect(label: ~S/binding()/)
      {:ok, put_replacement(replacements, buildingdef, selected_elements_hashs, replaced_hash, replacement_hash)}
    else
      other ->
        Logger.error("Invalid replacement params #{inspect(other)}, params: #{inspect(params)}")
        {:error, :invalid_params}
    end
  end

  def handle_info(:tick, socket) do
    send_tick()
    socket = update(socket, :counter, &(&1 + 1))
    {:noreply, socket}
  end

  defp send_tick do
    Process.send_after(self(), :tick, 5000)
  end

  defp prepare_mats(blueprint) do
    Blueprint.distinct_materials(blueprint)
    |> Enum.map(fn %{"buildingdef" => bid, "selected_elements" => hashs} ->
      %{
        building_name: Building.name_of!(bid),
        buildingdef: bid,
        selected_elements: hashs
      }
    end)
  end

  defp get_replacement(replacements, buildingdef, selected_elements, element_hash) do
    key = {buildingdef, selected_elements, element_hash}

    case Map.fetch(replacements, key) do
      {:ok, replacement} -> replacement
      :error -> element_hash
    end
  end

  defp put_replacement(replacements, buildingdef, selected_elements, element_hash, replace_by) do
    key = {buildingdef, selected_elements, element_hash}
    Map.put(replacements, key, replace_by)
  end

end
