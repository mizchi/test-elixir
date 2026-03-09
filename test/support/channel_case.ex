defmodule TestElixirWeb.ChannelCase do
  @moduledoc false

  use ExUnit.CaseTemplate

  using do
    quote do
      import Phoenix.ChannelTest

      @endpoint TestElixirWeb.Endpoint
    end
  end
end
