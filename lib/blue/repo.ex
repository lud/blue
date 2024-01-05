defmodule Blue.Repo do
  use Ecto.Repo,
    otp_app: :blue,
    adapter: Ecto.Adapters.SQLite3
end
