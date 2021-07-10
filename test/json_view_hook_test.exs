defmodule JsonViewHookTest do
  use ExUnit.Case

  use JsonView,
    after_render: &censor_email/1,
    fields: [:id],
    custom_fields: [{:has_email, fn data -> not is_nil(data[:email]) end}]

  @data %{
    id: 1001,
    name: "John Doe",
    age: 20,
    email: "test@gmail.com",
    address: %{
      ward: "Ben Nghe",
      district: "1",
      city: "HCM"
    }
  }

  test "render default field" do
    assert %{
             id: 1001
           } = render_json(@data, [], [], [])
  end

  test "render default custom field" do
    assert %{
             has_email: true
           } = render_json(@data, [], [], [])
  end

  test "override custom field" do
    assert %{
             has_email: "YES"
           } = render_json(@data, [], [:has_email], [])
  end

  test "hook censor email should return nil if email nil" do
    assert %{
             email: nil
           } = render_json(%{email: nil}, [:email], [], [])
  end

  test "hook censor email should success" do
    assert %{
             email: "xxx@example.com"
           } = render_json(@data, [:email], [], [])
  end

  def render_field(:has_email, data) do
    (is_nil(data.email) && "NO") || "YES"
  end

  def censor_email(data) do
    case Map.fetch(data, :email) do
      {:ok, email} when not is_nil(email) ->
        censored_email = "xxx@example.com"
        Map.put(data, :email, censored_email)

      _ ->
        data
    end
  end
end
