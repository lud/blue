defmodule Blue.Element do
  alias NimbleCSV.RFC4180, as: CSV

  defstruct [:id, :name]

  @csv_path Path.join([:code.priv_dir(:blue), "data", "elements.csv"])
  @external_resource @csv_path

  @raw_data @csv_path
            |> File.stream!()
            |> CSV.parse_stream()
            |> Enum.map(fn [name, id] ->
              %{__struct__: __MODULE__, name: name, id: String.to_integer(id)}
            end)

  Enum.each(@raw_data, fn element ->
    %{name: name, id: id} = element

    def by_name(unquote(name)), do: by_id(unquote(id))

    def by_id(unquote(id)) do
      {:ok, unquote(Macro.escape(element))}
    end
  end)
end
