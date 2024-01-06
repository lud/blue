defmodule BlueWeb.MaterialsLive do
  alias Blue.Blueprint
  alias Blue.Building
  alias Blue.Element
  require Logger
  use BlueWeb, :live_view

  def render(assigns) do
    ~H"""
    <div class="flex space-x-4">
      <%!-- Left --%>
      <div class="grow">
        <h1 class="text-2xl mb-4"><%= @blueprint["friendlyname"] %></h1>
        <div>
          <%= for mat <- @materials do %>
            <.material_picker build_mat={mat} replacements={@replacements} />
          <% end %>
        </div>
      </div>

      <%!-- Right --%>
      <div class="top-0 w-1/3">
        <div>
          <h2 class="text-xl mb-4">Upload blueprint</h2>
          <form id="upload-form" phx-submit="upload_new" phx-change="validate_upload_new">
            <.live_file_input upload={@uploads.original} />
            <.button class="mt-2" type="submit">Upload</.button>
          </form>
          <%= for entry <- @uploads.original.entries do %>
            <div
              :for={err <- upload_errors(@uploads.original, entry)}
              class="text-red-500"
              class="alert alert-danger"
            >
              <%= upload_error_to_string(err) %>
            </div>
          <% end %>
        </div>
        <div class="sticky top-0 pt-4">
          <h2 class="text-xl mb-4">Download changes</h2>
          <form phx-change="change_name">
            <h3>New name</h3>
            <.input type="text" name="new_name" value={@new_name} phx-debounce={300} />
          </form>

          <div class="mt-2">
            <a
              href={~p(/blueprint-download/#{@download_id})}
              class="block box-border text-center text-white bg-blue-700 hover:bg-blue-800 focus:ring-4 focus:ring-blue-300 font-medium rounded-lg text-sm px-5 py-2.5 focus:outline-none"
              download={filename(@new_name)}
            >
              Download Blueprint<br /><code><%= filename(@new_name) %></code>
            </a>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp filename(new_name) do
    name = new_name |> String.replace(" ", "_") |> String.downcase()
    "#{name}.blueprint"
  end

  defp upload_error_to_string(item) do
    inspect(item)
  end

  @element_options Enum.map(Element.list_all(), fn %{hash: hash, name: name} -> {name, hash} end)

  defp element_options, do: @element_options

  defp material_picker(assigns) do
    ~H"""
    <div class="border border-blue-200 rounded mb-2 p-2">
      <h2><%= @build_mat.building_name %></h2>

      <%= for hash <- @build_mat.selected_elements do %>
        <% chosen_hash =
          get_replacement(@replacements, @build_mat.buildingdef, @build_mat.selected_elements, hash) %>

        <div class={["flex gap-2 p-2 items-center", changed_mat_class(chosen_hash != hash)]}>
          <span>Replace</span>
          <strong><%= Element.find!(hash).name %></strong>
          <span>with</span>
          <form
            phx-change="select_replacement"
            phx-value-replaced_hash={hash}
            phx-value-original_elements={Jason.encode!(@build_mat.selected_elements)}
            phx-value-buildingdef={@build_mat.buildingdef}
          >
            <.input
              type="select"
              name="replacement_hash"
              options={element_options()}
              value={chosen_hash}
            />
          </form>
        </div>
      <% end %>
    </div>
    """
  end

  defp changed_mat_class(true), do: "bg-yellow-100"
  defp changed_mat_class(_), do: nil

  def mount(_params, _session, socket) do
    replacements = %{}
    blueprint = %{"friendlyname" => "Empty blueprint", "buildings" => []}
    materials = prepare_mats(blueprint)
    new_name = blueprint["friendlyname"]

    socket =
      socket
      |> assign(
        blueprint: blueprint,
        materials: materials,
        replacements: replacements,
        new_name: new_name,
        download_id: socket.id
      )
      |> allow_upload(:original, accept: ~w(.blueprint), max_entries: 1)

    if connected?(socket) do
      register_mount(socket, blueprint)
    end

    {:ok, socket}
  end

  defp register_mount(socket, blueprint) do
    {:ok, _} = Registry.register(Blue.ReplacementsRegistry, {socket.id, :blueprint}, blueprint)

    {:ok, _} =
      Registry.register(Blue.ReplacementsRegistry, {socket.id, :changes}, registry_value(socket))
  end

  defp update_registry_blueprint(socket, blueprint) do
    {_, _} =
      Registry.update_value(Blue.ReplacementsRegistry, {socket.id, :blueprint}, fn _ ->
        blueprint
      end)


  end

  defp update_registry_changes(socket) do
    {_new, _old} =
      Registry.update_value(Blue.ReplacementsRegistry, {socket.id, :changes}, fn _ ->
        registry_value(socket)
      end)
  end

  defp registry_value(socket) do
    %{friendlyname: socket.assigns.new_name, materials_replacements: socket.assigns.replacements}
  end

  def handle_event("select_replacement", params, socket) do
    socket |> IO.inspect(label: ~S/socket/)

    case select_replacement(socket.assigns.replacements, params) do
      {:ok, replacements} ->
        socket = assign(socket, replacements: replacements)
        update_registry_changes(socket)
        {:noreply, socket}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Invalid replacement")}
    end
  end

  def handle_event("change_name", %{"new_name" => new_name}, socket) do
    socket = assign(socket, new_name: new_name)
    update_registry_changes(socket)
    {:noreply, socket}
  end

  def handle_event("validate_upload_new", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("upload_new", _params, socket) do
    [blueprint | _] =
      consume_uploaded_entries(socket, :original, fn %{path: path}, _entry ->
        with {:ok, json} <- File.read(path) do
          Jason.decode(json)
        end
      end)

      update_registry_blueprint(socket, blueprint)

    socket = assign(socket,
      materials: prepare_mats(blueprint),
      new_name: blueprint["friendlyname"]
    )

    {:noreply, socket}
  end

  defp select_replacement(replacements, params) do
    with %{
           "buildingdef" => buildingdef,
           "original_elements" => selected_elements_json,
           "replaced_hash" => replaced_hash_str,
           "replacement_hash" => replacement_hash_str
         } <- params,
         {:ok, selected_elements_hashs} <- Jason.decode(selected_elements_json),
         true <- Enum.all?(selected_elements_hashs, &is_integer/1),
         true <- Enum.all?(selected_elements_hashs, &match?({:ok, _}, Element.find(&1))),
         {:ok, _} <- Building.by_id(buildingdef),
         {replacement_hash, ""} <- Integer.parse(replacement_hash_str),
         {replaced_hash, ""} <- Integer.parse(replaced_hash_str),
         {:ok, _} <- Building.by_id(buildingdef) do
      binding() |> IO.inspect(label: ~S/binding()/)

      {:ok,
       put_replacement(
         replacements,
         buildingdef,
         selected_elements_hashs,
         replaced_hash,
         replacement_hash
       )}
    else
      other ->
        Logger.error("Invalid replacement params #{inspect(other)}, params: #{inspect(params)}")
        {:error, :invalid_params}
    end
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
    build_mat_key = {buildingdef, selected_elements}

    with {:ok, build_mat} <- Map.fetch(replacements, build_mat_key),
         {:ok, replacement} <- Map.fetch(build_mat, element_hash) do
      replacement
    else
      :error -> element_hash
    end
  end

  defp put_replacement(replacements, buildingdef, selected_elements, element_hash, replace_by) do
    build_mat_key = {buildingdef, selected_elements}

    Map.update(replacements, build_mat_key, %{element_hash => replace_by}, fn
      build_mat -> Map.put(build_mat, element_hash, replace_by)
    end)
  end
end
